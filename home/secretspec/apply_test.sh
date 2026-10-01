#!/usr/bin/env bash
# Tests for `materialize.sh apply` (Home Manager activation) on the bao engine.
set -uo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=testlib.sh
. "$ROOT/testlib.sh" || exit 1

# shellcheck source=testlib_engine.sh
. "$ROOT/testlib_engine.sh" || exit 1

test_first_run_pulls_everything_byte_exact() {
  local n i=0
  for n in $NAMES; do
    i=$((i + 1))
    case $((i % 3)) in
      0) seed_s "$n" "$n-zero" ;;
      1) seed_s "$n" $'line\n' ;;
      2) seed_s "$n" $'line\n\n' ;;
    esac
  done
  engine apply
  assert_rc "apply" "$RC" 0
  i=0
  for n in $NAMES; do
    i=$((i + 1))
    case $((i % 3)) in
      0) assert_bytes "$n bytes" "$(file_of "$n")" "$n-zero" ;;
      1) assert_bytes "$n bytes" "$(file_of "$n")" $'line\n' ;;
      2) assert_bytes "$n bytes" "$(file_of "$n")" $'line\n\n' ;;
    esac
    assert_eq "$n mode" "$(tl_mode "$(file_of "$n")")" "$(mode_of "$n")"
    assert_eq "$n base version" "$(base_version "$n")" 1
  done
  assert_eq "one pulled line per secret" "$(grep -c '^pulled ' "$T/out")" 14
  assert_has "pulled line format" "$T/out" "pulled OMP_ENV - → v1"
  assert_eq ".ssh mode" "$(tl_mode "$T_HOME/.ssh")" 700
  assert_eq "state dir mode" "$(tl_mode "$T_STATE/$STATE_REL")" 700
  assert_eq "last-contact recorded" "$([[ -s $(state_file last-contact) ]] && echo yes)" yes
  assert_eq "no vault write" "$(vault_writes)" 0
}

test_second_run_changes_nothing() {
  seed_all
  settle
  local before after
  before=$(cd "$T" && find home state -type f -exec shasum -a 256 {} + | sort)
  engine apply
  assert_rc "second apply" "$RC" 0
  after=$(cd "$T" && find home state -type f -exec shasum -a 256 {} + | sort)
  assert_eq "no file changed (last-contact aside)" "$(grep -v last-contact <<<"$after")" "$(grep -v last-contact <<<"$before")"
  assert_eq "nothing printed" "$(cat "$T/out")" ""
  assert_eq "nothing on stderr" "$(cat "$T/err")" ""
}

test_behind_pulls_and_updates_the_base() {
  seed_all
  settle
  seed_s OMP_ENV "new-env"
  engine apply
  assert_rc "apply" "$RC" 0
  assert_bytes "file updated" "$(file_of OMP_ENV)" "new-env"
  assert_has "pulled line" "$T/out" "pulled OMP_ENV v1 → v2"
  assert_eq "base moved" "$(base_version OMP_ENV)" 2
  assert_eq "no leftover temp file" "$(find "$T_HOME" -name '*.sspull.*' | wc -l | tr -d ' ')" 0
  engine apply
  assert_eq "second run is quiet" "$(cat "$T/out")" ""
}

test_in_sync_files_get_their_mode_back() {
  seed_all
  settle
  chmod 644 "$(file_of SSH_ID_ED25519)"
  chmod 600 "$(file_of SSH_ID_ED25519_PUB)"
  engine apply
  assert_eq "private key back to 600" "$(tl_mode "$(file_of SSH_ID_ED25519)")" 600
  assert_eq "public key back to 644" "$(tl_mode "$(file_of SSH_ID_ED25519_PUB)")" 644
}

test_an_empty_local_file_counts_as_absent() {
  seed_all
  settle
  : >"$(file_of NPMRC)"
  engine apply
  assert_bytes "empty file replaced" "$(file_of NPMRC)" "v-NPMRC"
  assert_has "pulled" "$T/out" "pulled NPMRC"
}

test_stale_copy_is_pulled() {
  seed_all
  settle
  seed_s OMP_ENV "v2"
  seed_s OMP_ENV "v3"
  # The user's copy equals v2 (newer than the base v1) but not the latest v3.
  printf '%s' v2 >"$(file_of OMP_ENV)"
  engine apply
  assert_bytes "pulled the latest" "$(file_of OMP_ENV)" "v3"
  assert_has "pulled line" "$T/out" "pulled OMP_ENV v1 → v3"
}

test_local_edit_is_kept_and_the_vault_is_left_alone() {
  seed_all
  settle
  printf '%s' "edited locally" >"$(file_of OMP_ENV)"
  : >"$T/bao.log"
  engine apply
  assert_rc "apply" "$RC" 0
  assert_bytes "local edit kept" "$(file_of OMP_ENV)" "edited locally"
  assert_eq "vault untouched" "$(vver OMP_ENV)" 1
  assert_eq "vault never written" "$(vault_writes)" 0
  assert_has "banner names the secret and its state" "$T/err" "ahead"
  assert_has "banner names OMP_ENV" "$T/err" "OMP_ENV"
  assert_has "banner points at sync" "$T/err" "just secretspec-sync"
}

test_b1_an_edit_back_to_an_older_value_is_not_reverted() {
  seed_all
  seed_s OMP_ENV "B"
  lput .omp/.env "B"
  engine apply
  assert_rc "settle at v2" "$RC" 0
  printf '%s' "v-OMP_ENV" >"$(file_of OMP_ENV)"
  engine apply
  assert_bytes "edit back to v1's bytes survives" "$(file_of OMP_ENV)" "v-OMP_ENV"
  assert_has "reported as ahead" "$T/err" "ahead"
  assert_eq "vault still v2" "$(vver OMP_ENV)" 2
}

test_both_sides_changed_keeps_both() {
  seed_all
  settle
  seed_s NPMRC "vault-side"
  printf '%s' "local-side" >"$(file_of NPMRC)"
  engine apply
  assert_rc "apply" "$RC" 0
  assert_bytes "local kept" "$(file_of NPMRC)" "local-side"
  assert_eq "vault kept" "$(vver NPMRC)" 2
  assert_has "banner" "$T/err" "diverged"
}

test_no_record_and_different_bytes_is_unknown() {
  seed_all
  printf '%s' "different" >"$(file_of NPMRC)"
  engine apply
  assert_rc "apply" "$RC" 0
  assert_bytes "local kept" "$(file_of NPMRC)" "different"
  assert_has "banner" "$T/err" "unknown"
  assert_absent "no base is invented" "$(state_file NPMRC.base.json)"
}

test_rewound_vault_keeps_both() {
  seed_all
  settle
  ba kv metadata delete -mount=secret "$TL_SECRET_PREFIX/NPMRC" >/dev/null
  seed_s NPMRC "recreated"
  engine apply
  assert_rc "apply" "$RC" 0
  assert_bytes "local kept" "$(file_of NPMRC)" "v-NPMRC"
  assert_has "banner" "$T/err" "rewound"
  assert_eq "base kept as it was" "$(base_version NPMRC)" 1
}

test_blocked_destinations_are_never_written_through() {
  seed_all
  rm -f "$(file_of NPMRC)"
  printf '%s' target >"$T/target"
  ln -s "$T/target" "$(file_of NPMRC)"
  rm -f "$(file_of OMP_ENV)"
  mkdir -p "$(file_of OMP_ENV)"
  engine apply
  assert_rc "apply" "$RC" 0
  assert_bytes "symlink target untouched" "$T/target" target
  [[ -L $(file_of NPMRC) ]] && ok "symlink still a symlink" || bad "symlink replaced"
  [[ -d $(file_of OMP_ENV) ]] && ok "directory still a directory" || bad "directory replaced"
  assert_eq "nothing moved into the directory" "$(find "$(file_of OMP_ENV)" -type f | wc -l | tr -d ' ')" 0
  assert_has "banner" "$T/err" "blocked"
}

test_vault_missing_rows() {
  seed_all
  settle
  ba kv metadata delete -mount=secret "$TL_SECRET_PREFIX/NPMRC" >/dev/null
  ba kv delete -mount=secret "$TL_SECRET_PREFIX/OMP_ENV" >/dev/null
  ba kv destroy -mount=secret -versions=1 "$TL_SECRET_PREFIX/ATUIN_KEY" >/dev/null
  engine apply
  assert_rc "apply with local copies present" "$RC" 0
  assert_bytes "local NPMRC kept (404)" "$(file_of NPMRC)" "v-NPMRC"
  assert_bytes "local OMP_ENV kept (deleted)" "$(file_of OMP_ENV)" "v-OMP_ENV"
  assert_bytes "local ATUIN_KEY kept (destroyed)" "$(file_of ATUIN_KEY)" "v-ATUIN_KEY"
  assert_has "banner" "$T/err" "vault-missing"
  assert_eq "never written" "$(vault_writes)" 0
  rm -f "$(file_of NPMRC)"
  engine apply
  assert_rc "apply when the file is gone too" "$RC" 1
  assert_has "says which secret" "$T/err" "NPMRC"
}

test_offline_with_a_recent_contact_keeps_going() {
  seed_all
  settle
  srv_spawn "$T/dead"
  use_srv "$T/dead"
  kill -9 "$(cat "$T/dead/pid")"
  wait "$(cat "$T/dead/pid")" 2>/dev/null
  : >"$T/bao.log"
  local before
  before=$(cat "$(state_file last-contact)")
  engine apply
  assert_rc "apply" "$RC" 0
  assert_has "banner" "$T/err" "unreachable"
  assert_has "names the cause" "$T/err" "connection refused"
  if [[ $TL_SHIM_OK -eq 1 ]]; then
    assert_eq "circuit breaker: one vault call" "$(wc -l <"$T/bao.log" | tr -d ' ')" 1
  fi
  assert_eq "last-contact is not refreshed" "$(cat "$(state_file last-contact)")" "$before"
  assert_bytes "files untouched" "$(file_of OMP_ENV)" "v-OMP_ENV"
}

test_offline_bounds() {
  seed_all
  settle
  srv_spawn "$T/dead"
  use_srv "$T/dead"
  kill -9 "$(cat "$T/dead/pid")"
  wait "$(cat "$T/dead/pid")" 2>/dev/null
  local now
  now=$(date +%s)
  printf '%s\n' $((now - 6 * 86400)) >"$(state_file last-contact)"
  engine apply
  assert_rc "6 days since contact" "$RC" 0
  printf '%s\n' $((now - 8 * 86400)) >"$(state_file last-contact)"
  engine apply
  assert_rc "8 days since contact" "$RC" 1
  assert_has "explains the bound" "$T/err" "7 days"
  rm -f "$(state_file last-contact)"
  engine apply
  assert_rc "no contact ever recorded" "$RC" 1
  contact_now() { printf '%s\n' "$(date +%s)" >"$(state_file last-contact)"; }
  contact_now
  rm -f "$(file_of NPMRC)"
  engine apply
  assert_rc "a missing file always fails" "$RC" 1
  assert_has "names the missing file" "$T/err" "NPMRC"
}

test_sealed_vault_counts_as_offline() {
  seed_all
  settle
  srv_spawn "$T/sealed"
  use_srv "$T/sealed"
  ba operator seal >/dev/null
  engine apply
  assert_rc "apply" "$RC" 0
  assert_has "banner" "$T/err" "sealed"
}

test_bad_token_fails_with_the_fix() {
  seed_all
  settle
  ENGINE_ENV=(VAULT_TOKEN=bogus)
  engine apply
  assert_rc "apply" "$RC" 1
  assert_has "names the fix" "$T/err" "just openbao-login"
  assert_bytes "files untouched" "$(file_of OMP_ENV)" "v-OMP_ENV"
}

test_untrusted_certificate_fails_with_the_fix() {
  seed_all
  settle
  srv_spawn "$T/tls" tls
  use_srv "$T/tls"
  engine apply
  assert_rc "apply" "$RC" 1
  assert_has "mentions the certificate" "$T/err" "x509"
  assert_has "names the fix" "$T/err" "CA"
}

test_last_contact_counts_not_found_as_an_answer() {
  seed_s OMP_ENV x
  lput .omp/.env x
  engine apply
  assert_rc "most secrets missing everywhere" "$RC" 1
  assert_eq "vault answered every read" "$([[ -s $(state_file last-contact) ]] && echo yes)" yes
}

test_legacy_records_migrate() {
  seed_all
  seed_s OMP_ENV "v2-bytes"
  seed_s NPMRC "other"
  put_legacy OMP_ENV "$(sha_of v-OMP_ENV)"
  put_legacy NPMRC "$(sha_of never-seen)"
  printf '%s' other >"$(file_of NPMRC)"
  printf '%s' "local-edit" >"$(file_of ATUIN_KEY)"
  put_legacy ATUIN_KEY "$(sha_of v-ATUIN_KEY)"
  engine apply
  assert_rc "apply" "$RC" 0
  assert_bytes "behind via the legacy hash: pulled" "$(file_of OMP_ENV)" "v2-bytes"
  assert_absent "legacy file removed after migration" "$(state_file OMP_ENV.sha256)"
  assert_eq "migrated base is the matching version, then pulled to v2" "$(base_version OMP_ENV)" 2
  assert_eq "legacy hash of an edited file becomes base v1: ahead" "$(base_version ATUIN_KEY)" 1
  assert_bytes "edit kept" "$(file_of ATUIN_KEY)" "local-edit"
  assert_absent "legacy file removed (ATUIN_KEY)" "$(state_file ATUIN_KEY.sha256)"
  assert_has "ahead reported" "$T/err" "ATUIN_KEY"
  assert_bytes "equal bytes: in sync, no pull" "$(file_of NPMRC)" other
  assert_eq "in-sync NPMRC got a base at the current version" "$(base_version NPMRC)" 2
  assert_absent "legacy file of an in-sync secret removed" "$(state_file NPMRC.sha256)"
}

test_unmatched_legacy_record_is_row_12() {
  seed_all
  seed_s NPMRC "vault-two"
  printf '%s' "local-x" >"$(file_of NPMRC)"
  put_legacy NPMRC "$(sha_of never-seen)"
  engine apply
  assert_rc "apply" "$RC" 0
  assert_bytes "local kept" "$(file_of NPMRC)" "local-x"
  assert_has "unknown" "$T/err" "unknown"
  assert_eq "legacy record kept for the next try" "$([[ -f $(state_file NPMRC.sha256) ]] && echo yes)" yes
  assert_absent "no base" "$(state_file NPMRC.base.json)"
}

test_interrupted_migration_converges() {
  seed_all
  settle
  seed_s OMP_ENV "v2-bytes"
  rm -f "$(state_file OMP_ENV.base.json)"
  put_legacy OMP_ENV "$(sha_of v-OMP_ENV)"
  ENGINE_ENV=(SECRETSPEC_TEST_CRASH_AT=base-written)
  engine apply
  assert_rc "killed after writing base.json" "$RC" 137
  assert_eq "base.json exists" "$(base_version OMP_ENV)" 1
  assert_eq "legacy file still there" "$([[ -f $(state_file OMP_ENV.sha256) ]] && echo yes)" yes
  ENGINE_ENV=()
  engine apply
  assert_rc "re-run" "$RC" 0
  assert_bytes "converged" "$(file_of OMP_ENV)" "v2-bytes"
  assert_absent "legacy file gone" "$(state_file OMP_ENV.sha256)"
  assert_eq "base caught up" "$(base_version OMP_ENV)" 2
}

test_crash_before_the_rename_leaves_the_old_file() {
  seed_all
  settle
  seed_s OMP_ENV "new-env"
  ENGINE_ENV=(SECRETSPEC_TEST_CRASH_AT=pull-tmp-written)
  engine apply
  assert_rc "killed" "$RC" 137
  assert_bytes "old file intact" "$(file_of OMP_ENV)" "v-OMP_ENV"
  assert_eq "a temp file is left" "$(find "$T_HOME/.omp" -name '*.sspull.*' | wc -l | tr -d ' ')" 1
  ENGINE_ENV=()
  engine apply
  assert_rc "re-run" "$RC" 0
  assert_bytes "converged" "$(file_of OMP_ENV)" "new-env"
  assert_eq "temp file cleaned" "$(find "$T_HOME/.omp" -name '*.sspull.*' | wc -l | tr -d ' ')" 0
  assert_eq "base recorded" "$(base_version OMP_ENV)" 2
}

test_crash_after_the_rename_converges() {
  seed_all
  settle
  seed_s OMP_ENV "new-env"
  ENGINE_ENV=(SECRETSPEC_TEST_CRASH_AT=pull-renamed)
  engine apply
  assert_rc "killed" "$RC" 137
  assert_bytes "new file already in place" "$(file_of OMP_ENV)" "new-env"
  assert_eq "base still old" "$(base_version OMP_ENV)" 1
  ENGINE_ENV=()
  engine apply
  assert_rc "re-run" "$RC" 0
  assert_eq "base caught up" "$(base_version OMP_ENV)" 2
  assert_eq "quiet" "$(cat "$T/out")" ""
}

test_pull_refuses_when_the_destination_changed_since_decide() {
  # shellcheck source=/dev/null
  . "$ROOT/common.sh"
  # shellcheck source=/dev/null
  . "$ROOT/state.sh"
  # shellcheck source=/dev/null
  . "$ROOT/pull.sh"
  in_sandbox
  work_init
  state_init
  printf '%s' decided >"$T/dest"
  printf '%s' incoming >"$T/src"
  printf '%s' "changed meanwhile" >"$T/dest"
  pull_file X "$T/dest" 600 "$T/src" "$(sha_of decided)" 2 t "$(sha_of incoming)" 2>"$T/err"
  assert_rc "pull_file" "$?" 1
  assert_bytes "destination keeps the newer edit" "$T/dest" "changed meanwhile"
  assert_eq "temp file removed" "$(find "$T" -name '.dest.sspull.*' | wc -l | tr -d ' ')" 0
  assert_absent "no base written" "$STATE_DIR/X.base.json"
}

test_apply_never_reads_stdin() {
  seed_all
  settle
  local pid i
  mkfifo "$T/fifo"
  exec 9<>"$T/fifo"
  env -i HOME="$T_HOME" PATH="$T_SHIM:$PATH" XDG_STATE_HOME="$T_STATE" TMPDIR="$T/tmp" TZ=UTC \
    SECRETSPEC_SYNC_ADDR="$S_ADDR" VAULT_TOKEN="$S_TOK" "${TL_ENGINE[@]}" apply <&9 >"$T/out" 2>"$T/err" &
  pid=$!
  for i in $(seq 1 150); do
    kill -0 "$pid" 2>/dev/null || break
    sleep 0.1
  done
  if kill -0 "$pid" 2>/dev/null; then
    kill -9 "$pid"
    bad "apply waited for stdin"
  else
    wait "$pid"
    assert_rc "apply with an open, silent stdin" "$?" 0
  fi
  exec 9<&-
}

test_no_value_leaks_into_output_or_argv() {
  local plant="PLANT-$RANDOM-$RANDOM-secret"
  seed_all
  seed_s OMP_ENV "KEY=$plant"
  seed_s NPMRC "token=$plant-npm"
  lput .npmrc "token=$plant-local"
  engine apply
  assert_lacks "stdout" "$T/out" "$plant"
  assert_lacks "stderr" "$T/err" "$plant"
  assert_has "positive control: the value reached the disk" "$(file_of OMP_ENV)" "$plant"
  if [[ $TL_SHIM_OK -eq 1 ]]; then
    assert_lacks "bao argv" "$T/bao.log" "$plant"
    assert_lacks "token in argv" "$T/bao.log" "$S_TOK"
  fi
  assert_has "positive control: the leak detector sees a leaky log" <(printf 'kv put x v=%s\n' "$plant") "$plant"
}

# The Home Manager activation PATH has no awk (home.emptyActivationPath): bash,
# coreutils, diffutils, findutils, gnugrep, gnused, jq. apply must follow D1/D2
# on every outcome with only those tools.
test_apply_runs_on_the_activation_path() {
  local t p n farm=$T/actbin
  mkdir -p "$farm"
  for t in bash cat chmod cp cut date dirname basename find grep head ln ls mkdir mktemp mv od rm sed sleep sort stat sync tail tee touch tr uniq wc cmp diff jq id readlink sha256sum shasum; do
    p=$(command -v "$t" 2>/dev/null) || continue
    [[ $p == /* ]] && ln -s "$p" "$farm/$t"
  done
  ln -s "$T_SHIM/bao" "$farm/bao"
  assert_eq "positive control: awk is absent from the activation PATH" "$(PATH=$farm command -v awk || echo none)" none
  assert_eq "positive control: jq is on it" "$([[ $(PATH=$farm command -v jq) == "$farm/jq" ]] && echo yes)" yes
  ENGINE_ENV=("PATH=$farm")

  # pulls: the vault has everything, this Mac has nothing
  for n in $NAMES; do seed_s "$n" "v-$n"; done
  engine apply
  assert_rc "first run pulls" "$RC" 0
  assert_eq "14 pulled lines" "$(grep -c '^pulled ' "$T/out")" 14
  assert_lacks "pulls: no missing tool" "$T/err" "not found"

  # ahead banner
  printf '%s' "edited locally" >"$(file_of OMP_ENV)"
  engine apply
  assert_rc "ahead" "$RC" 0
  assert_has "ahead banner names the secret" "$T/err" "OMP_ENV"
  assert_has "ahead banner names the state" "$T/err" "ahead"
  assert_lacks "ahead: no missing tool" "$T/err" "not found"
  lput .omp/.env "v-OMP_ENV"

  # not in the vault, local copy present
  ba kv metadata delete -mount=secret "$TL_SECRET_PREFIX/NPMRC" >/dev/null
  engine apply
  assert_rc "404 on one path" "$RC" 0
  assert_has "vault-missing banner" "$T/err" "vault-missing"
  assert_lacks "404: no missing tool" "$T/err" "not found"
  seed_s NPMRC "v-NPMRC"

  # sealed
  srv_spawn "$T/sealed"
  use_srv "$T/sealed"
  ba operator seal >/dev/null
  engine apply
  assert_rc "sealed" "$RC" 0
  assert_has "sealed banner" "$T/err" "sealed"
  assert_lacks "sealed: no missing tool" "$T/err" "not found"

  # killed server
  srv_spawn "$T/dead"
  use_srv "$T/dead"
  kill -9 "$(cat "$T/dead/pid")"
  wait "$(cat "$T/dead/pid")" 2>/dev/null
  engine apply
  assert_rc "killed server" "$RC" 0
  assert_has "offline banner" "$T/err" "unreachable"
  assert_lacks "killed: no missing tool" "$T/err" "not found"

  # bad token
  use_srv "$TL_MAIN_SRV"
  ENGINE_ENV=("PATH=$farm" VAULT_TOKEN=bogus)
  engine apply
  assert_rc "bad token" "$RC" 1
  assert_has "bad token names the fix" "$T/err" "just openbao-login"
  assert_lacks "bad token: no missing tool" "$T/err" "not found"
  assert_bytes "files untouched" "$(file_of OMP_ENV)" "v-OMP_ENV"
}

tl_init
tl_run_all
tl_done
