#!/usr/bin/env bash
# Tests for `materialize.sh status` (read-only overview), `list`, and the
# secretspec contract check.
set -uo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=testlib.sh
. "$ROOT/testlib.sh" || exit 1

# state_of NAME: the STATE column of the last engine run.
state_of() { awk -v n="$1" '$1 == n { print $2 }' "$T/out"; }
# row_of NAME: the whole status line of NAME.
row_of() { grep "^$1 " "$T/out" | head -1; }

# snapshot: every file under the sandbox with its hash, plus vault versions.
snapshot() {
  (cd "$T" && find home state -print 2>/dev/null | sort | while IFS= read -r f; do
    if [[ -f $f && ! -L $f ]]; then printf '%s %s\n' "$f" "$(shasum -a 256 <"$f" | cut -c1-64)"; else echo "$f"; fi
  done)
  local n
  for n in $(awk '{print $1}' <<<"$TL_TABLE"); do printf '%s v%s\n' "$n" "$(vver "$n" 2>/dev/null)"; done
}

test_list_matches_the_test_table() {
  engine list
  assert_rc "list" "$RC" 0
  assert_eq "list prints NAME PATH MODE per secret" "$(cat "$T/out")" "$TL_TABLE"
  local want got
  want=$(awk '{print $1}' <<<"$TL_TABLE" | sort)
  got=$(grep -E '^[A-Z0-9_]+ = ' "$ROOT/../../secretspec.toml" | awk '{print $1}' | grep -vx ATUIN_PASSWORD | sort)
  assert_eq "table names equal secretspec.toml minus ATUIN_PASSWORD" "$want" "$got"
}

test_every_row_state_is_reported() {
  # in-sync
  seed_s SSH_ID_ED25519_PUB $'pub\n'
  lput "$(rel_of SSH_ID_ED25519_PUB)" $'pub\n' 644
  # ahead: vault v2 is the base, local edited
  seed_s NPMRC old
  seed_s NPMRC base
  put_base NPMRC 2 "$(sha_of base)" "$(vct NPMRC 2)"
  lput .npmrc edited
  # behind: vault moved to v2, local still equals the base v1
  seed_s OMP_ENV old
  seed_s OMP_ENV new
  put_base OMP_ENV 1 "$(sha_of old)" "$(vct OMP_ENV 1)"
  lput .omp/.env old
  # missing-local
  seed_s ATUIN_KEY key
  # vault-missing: local only
  lput .config/tofu/backbone-cluster.pass pass
  # unknown: no base, bytes differ
  seed_s SSH_ID_CRYPT vault
  lput .ssh/id_crypt local
  # blocked: a symlink where the file belongs
  seed_s SSH_ID_CRYPT_PUB pub
  mkdir -p "$T_HOME/.ssh"
  printf 'target' >"$T/target"
  ln -s "$T/target" "$T_HOME/.ssh/id_crypt.pub"
  # diverged
  seed_s ATUIN_AI_TOKEN a
  seed_s ATUIN_AI_TOKEN b
  put_base ATUIN_AI_TOKEN 1 "$(sha_of a)" "$(vct ATUIN_AI_TOKEN 1)"
  lput .config/atuin/ai-token c
  # rewound: the base is ahead of the vault
  seed_s SSH_ID_ED25519_OC v1
  put_base SSH_ID_ED25519_OC 3 "$(sha_of v3)" 2026-01-01T00:00:00Z
  lput .ssh/id_ed25519.oc v3
  # stale: local equals a retained version newer than the base
  seed_s SSH_ID_ED25519_OC_PUB x
  seed_s SSH_ID_ED25519_OC_PUB y
  seed_s SSH_ID_ED25519_OC_PUB z
  put_base SSH_ID_ED25519_OC_PUB 1 "$(sha_of x)" "$(vct SSH_ID_ED25519_OC_PUB 1)"
  lput .ssh/id_ed25519.oc.pub y 644

  engine status
  assert_rc "status" "$RC" 0
  assert_eq "in-sync" "$(state_of SSH_ID_ED25519_PUB)" in-sync
  assert_eq "ahead" "$(state_of NPMRC)" ahead
  assert_eq "behind" "$(state_of OMP_ENV)" behind
  assert_eq "missing-local" "$(state_of ATUIN_KEY)" missing-local
  assert_eq "vault-missing" "$(state_of TOFU_BACKBONE_CLUSTER_PASS)" vault-missing
  assert_eq "unknown" "$(state_of SSH_ID_CRYPT)" unknown
  assert_eq "blocked" "$(state_of SSH_ID_CRYPT_PUB)" blocked
  assert_eq "diverged" "$(state_of ATUIN_AI_TOKEN)" diverged
  assert_eq "rewound" "$(state_of SSH_ID_ED25519_OC)" rewound
  assert_eq "stale" "$(state_of SSH_ID_ED25519_OC_PUB)" stale
  assert_eq "every secret has a line" "$(awk '{print $1}' <<<"$TL_TABLE" | while read -r n; do state_of "$n"; done | grep -c .)" 14
}

test_columns_show_versions_times_and_writers() {
  local when='20[0-9]{2}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}' re
  seed_s SSH_ID_ED25519_PUB $'pub\n'
  lput "$(rel_of SSH_ID_ED25519_PUB)" $'pub\n' 644
  printf '{"data":{"value":"x","writer":"mac-one"}}' | ba write -format=json "secret/data/$TL_SECRET_PREFIX/NPMRC" - >/dev/null
  echo NPMRC >>"$TL_TMP/touched"
  lput .npmrc edited
  seed_s OMP_ENV old
  seed_s OMP_ENV new
  put_base OMP_ENV 1 "$(sha_of old)" "$(vct OMP_ENV 1)"
  lput .omp/.env old
  engine status
  re="in-sync +=[ ]v1 +v1 $when [?]"
  [[ $(row_of SSH_ID_ED25519_PUB) =~ $re ]] && ok "in-sync: '= v1', vault v1 with local time and unknown writer" || bad "in-sync row" "$(row_of SSH_ID_ED25519_PUB)"
  re="edited $when +v1 $when mac-one"
  [[ $(row_of NPMRC) =~ $re ]] && ok "edited local, writer shown" || bad "edited row" "$(row_of NPMRC)"
  re="=[ ]v1 +v2 $when [?] +base v1"
  [[ $(row_of OMP_ENV) =~ $re ]] && ok "behind: '= v1', vault v2, base version shown" || bad "behind row" "$(row_of OMP_ENV)"
  re="vault-missing +absent +missing [(]absent[)]"
  [[ $(row_of TOFU_BACKBONE_CLUSTER_PASS) =~ $re ]] && ok "vault-missing row" || bad "vault-missing row" "$(row_of TOFU_BACKBONE_CLUSTER_PASS)"
}

test_footer_counts_and_next_command() {
  seed_s SSH_ID_ED25519_PUB pub
  lput "$(rel_of SSH_ID_ED25519_PUB)" pub 644
  engine status
  assert_has "counts" "$T/out" "14 secrets: 1 in-sync, 13 vault-missing"
  assert_has "next command for vault-missing rows" "$T/out" "next: just secretspec-sync"
  # all in sync -> nothing to do
  local n
  for n in $(awk '{print $1}' <<<"$TL_TABLE"); do
    seed_s "$n" "v-$n"
    lput "$(rel_of "$n")" "v-$n" "$(mode_of "$n")"
  done
  engine status
  assert_has "all in sync" "$T/out" "14 secrets: 14 in-sync"
  assert_has "nothing to do" "$T/out" "next: nothing to do"
  # only pulls -> just home
  rm -f "$T_HOME/.npmrc"
  engine status
  assert_has "pull rows" "$T/out" "13 in-sync, 1 missing-local"
  assert_has "pulls are applied by just home" "$T/out" "next: just home"
}

test_status_writes_nothing() {
  seed_s OMP_ENV old
  seed_s OMP_ENV new
  lput .omp/.env old
  put_legacy OMP_ENV "$(sha_of old)"
  seed_s NPMRC n
  lput .npmrc n
  local before after
  before=$(snapshot)
  engine status
  assert_rc "status" "$RC" 0
  after=$(snapshot)
  assert_eq "no file, hash or vault version changed" "$after" "$before"
  assert_absent "no last-contact record" "$T_STATE/dotfiles/secretspec/last-contact"
  assert_absent "legacy hash was not migrated" "$T_STATE/dotfiles/secretspec/OMP_ENV.base.json"
  assert_eq "the legacy hash still resolves a base: behind" "$(state_of OMP_ENV)" behind
  rm -rf "$T_STATE"
  engine status
  assert_absent "no state directory is created" "$T_STATE/dotfiles"
}

test_vault_down_is_one_call_and_offline_everywhere() {
  [[ $TL_SHIM_OK -eq 1 ]] || {
    skip "bao shim is bypassed under SS_ENGINE"
    return 0
  }
  srv_spawn "$T/dead"
  use_srv "$T/dead"
  kill -9 "$(cat "$T/dead/pid")"
  wait "$(cat "$T/dead/pid")" 2>/dev/null
  lput .npmrc local
  engine status
  assert_rc "status" "$RC" 0
  assert_eq "all 14 offline" "$(grep -c ' offline ' "$T/out")" 14
  assert_eq "circuit breaker: exactly one vault call" "$(wc -l <"$T/bao.log" | tr -d ' ')" 1
  assert_has "says why" "$T/out" "connection refused"
  assert_has "counts" "$T/out" "14 secrets: 14 offline"
}

test_bad_token_is_reported_per_secret() {
  ENGINE_ENV=(VAULT_TOKEN=bogus)
  engine status
  assert_rc "status" "$RC" 0
  assert_eq "all 14 auth-failed" "$(grep -c ' auth-failed ' "$T/out")" 14
  assert_has "next command" "$T/out" "next: just openbao-login"
}

test_status_does_not_print_values() {
  local plant="PLANT-$RANDOM-$RANDOM-value"
  seed_s OMP_ENV "KEY=$plant"
  seed_s OMP_ENV "KEY=$plant-2"
  lput .omp/.env "KEY=$plant-local"
  seed_s NPMRC "$plant"
  lput .npmrc "$plant-x"
  engine status
  assert_rc "status" "$RC" 0
  assert_has "status ran" "$T/out" "OMP_ENV"
  assert_lacks "stdout has no value" "$T/out" "$plant"
  assert_lacks "stderr has no value" "$T/err" "$plant"
  # Positive control: the planted value is in the vault and on disk.
  assert_has "positive control (disk)" "$T_HOME/.npmrc" "$plant"
  assert_has "positive control (vault)" "$(vget NPMRC)" "$plant"
}

# A stand-in for the secretspec CLI. FAKE_OUT is what `get` prints.
fake_secretspec() {
  cat >"$T/secretspec" <<'EOF'
#!/usr/bin/env bash
[[ $* == *" get "* ]] || exit 3
printf '%s' "$FAKE_OUT"
EOF
  chmod +x "$T/secretspec"
}

test_contract_check() {
  fake_secretspec
  seed_s SSH_ID_ED25519_PUB $'ssh-ed25519 AAAA host\n'
  ENGINE_ENV=(SECRETSPEC_BIN="$T/secretspec" FAKE_OUT=$'ssh-ed25519 AAAA host\n')
  sandbox_run "$TL_BASH" "$ROOT/contract-check.sh"
  assert_rc "same value, exact newline" "$RC" 0
  assert_has "reports ok" "$T/out" "contract: ok"
  ENGINE_ENV=(SECRETSPEC_BIN="$T/secretspec" FAKE_OUT=$'ssh-ed25519 AAAA host\n\n')
  sandbox_run "$TL_BASH" "$ROOT/contract-check.sh"
  assert_rc "an old CLI appends a newline" "$RC" 0
  ENGINE_ENV=(SECRETSPEC_BIN="$T/secretspec" FAKE_OUT=$'ssh-ed25519 BBBB host\n')
  sandbox_run "$TL_BASH" "$ROOT/contract-check.sh"
  assert_rc "different value" "$RC" 1
  assert_has "reports drift" "$T/out" "contract: DRIFT"
  ENGINE_ENV=(SECRETSPEC_BIN="$T/none" FAKE_OUT=x)
  sandbox_run "$TL_BASH" "$ROOT/contract-check.sh"
  assert_rc "no secretspec installed" "$RC" 0
  assert_has "says it was skipped" "$T/out" "contract: skipped"
}

# B1: an edit back to an older value is the user's edit, not a stale copy. Row 9
# only counts live versions newer than the base (d_stale's bound).
test_b1_with_a_moving_vault() {
  seed_s NPMRC A
  seed_s NPMRC B
  put_base NPMRC 2 "$(sha_of B)" "$(vct NPMRC 2)"
  lput .npmrc A
  engine status
  assert_rc "status" "$RC" 0
  assert_eq "local equals v1 but the base is v2: ahead, not stale" "$(state_of NPMRC)" ahead
  seed_s NPMRC C
  engine status
  assert_eq "the vault moved on to v3: diverged" "$(state_of NPMRC)" diverged
}

# M1: the vault history was deleted and rebuilt. A retained version number with
# another created_time is another epoch, so the base is not that version.
test_recreated_history_with_a_higher_version() {
  local i
  seed_s NPMRC one
  seed_s NPMRC two
  put_base NPMRC 2 "$(sha_of two)" "$(vct NPMRC 2)"
  lput .npmrc two
  ba kv metadata delete -mount=secret "$TL_SECRET_PREFIX/NPMRC" >/dev/null
  for i in 1 2 3 4; do seed_s NPMRC "new$i"; done
  engine status
  assert_eq "v2 still exists but under another epoch: rewound" "$(state_of NPMRC)" rewound
}

# A metadata call that fails after the read succeeded is not an answer: the
# secret is decided again as offline, and the breaker covers the next ones.
test_a_failing_metadata_call_reads_as_offline() {
  cat >"$T_SHIM/bao" <<SHIM
#!/bin/sh
printf '%s\\n' "\$*" >>"$T/bao.log"
case "\$*" in
  *"kv metadata get"*)
    printf 'Error making API request.\\n\\nURL: GET http://x/v1/secret/metadata/p\\nCode: 503. Errors:\\n\\n* Vault is sealed\\n' >&2
    exit 2
    ;;
esac
exec "$TL_BAO" "\$@"
SHIM
  chmod +x "$T_SHIM/bao"
  seed_s NPMRC A
  seed_s NPMRC B
  seed_s NPMRC C
  put_base NPMRC 1 "$(sha_of A)" "$(vct NPMRC 1)"
  lput .npmrc A # behind, if the failed call were ignored
  seed_s OMP_ENV X
  seed_s OMP_ENV Y
  lput .omp/.env Y
  if [[ $TL_SHIM_OK -eq 0 ]]; then
    skip "bao shim is bypassed under SS_ENGINE"
    return 0
  fi
  engine status
  assert_eq "the failed call decides NPMRC as offline" "$(state_of NPMRC)" offline
  assert_eq "the breaker makes the next secret offline" "$(state_of OMP_ENV)" offline
  assert_has "says why" "$T/out" "sealed"
}

tl_init
tl_run_all
tl_done
