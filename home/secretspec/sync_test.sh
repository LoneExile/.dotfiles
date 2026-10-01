#!/usr/bin/env bash
# Tests for `materialize.sh sync` and `sync --push NAME`. The interactive flows
# run on a pseudo-terminal (tty_drive.py) with the answers typed ahead; nvim is a
# stub that records its calls.
set -uo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=testlib.sh
. "$ROOT/testlib.sh" || exit 1
# shellcheck source=testlib_engine.sh
. "$ROOT/testlib_engine.sh" || exit 1

HOSTNAME_NOW=$(/usr/sbin/scutil --get LocalHostName)

# vault_value NAME [VERSION]: the stored bytes, via a file.
vault_bytes_equal() { # label NAME VERSION WANT
  assert_bytes "$1" "$(vget "$2" "$3")" "$4"
}
vault_writer() { ba kv get -format=json -mount=secret "$TL_SECRET_PREFIX/$1" | jq -r '.data.data.writer // ""'; }

test_sync_needs_a_terminal() {
  seed_all
  engine sync
  assert_rc "sync without a terminal" "$RC" 1
  assert_has "says why" "$T/err" "needs a terminal"
  assert_has "points at --push" "$T/err" "--push NAME"
}

test_in_sync_secrets_get_their_records_without_a_prompt() {
  seed_all
  tty_engine "" sync
  assert_rc "sync" "$RC" 0
  assert_has "table printed" "$T/out" "14 secrets: 14 in-sync"
  assert_eq "a base for every secret" "$(find "$T_STATE/$STATE_REL" -name '*.base.json' | wc -l | tr -d ' ')" 14
  assert_lacks "no prompt" "$T/out" "[y/N"
}

test_pulls_are_automatic_and_quiet() {
  seed_all
  settle
  seed_s OMP_ENV "newer"
  rm -f "$(file_of ATUIN_KEY)"
  tty_engine "" sync
  assert_rc "sync" "$RC" 0
  assert_has "pulled behind" "$T/out" "pulled OMP_ENV v1 → v2"
  assert_has "pulled missing" "$T/out" "pulled ATUIN_KEY v1 → v1"
  assert_bytes "file updated" "$(file_of OMP_ENV)" "newer"
  assert_lacks "no prompt" "$T/out" "[y/N"
}

test_ahead_push_confirmed() {
  seed_all
  reseed OMP_ENV $'KEEP=1\nKEY=PLANT-old\n'
  settle
  printf '%s' $'KEEP=1\nKEY=PLANT-new\nADDED=PLANT-added\n' >"$(file_of OMP_ENV)"
  tty_engine $'y\n' sync
  assert_rc "sync" "$RC" 0
  assert_has "keys added" "$T/out" "keys added (local vs OpenBao): ADDED"
  assert_has "keys changed" "$T/out" "keys changed (local vs OpenBao): KEY"
  assert_has "prompt names the versions" "$T/out" "push OMP_ENV to OpenBao (v2 → v3)? [y/N/v]"
  assert_has "pushed line" "$T/out" "pushed OMP_ENV v2 → v3"
  assert_lacks "no value in the transcript" "$T/out" "PLANT"
  assert_bytes "vault has the local bytes" "$(vget OMP_ENV 3)" $'KEEP=1\nKEY=PLANT-new\nADDED=PLANT-added\n'
  assert_eq "base follows" "$(base_version OMP_ENV)" 3
  assert_eq "writer recorded" "$(vault_writer OMP_ENV)" "$HOSTNAME_NOW"
  assert_eq "old version still readable" "$(cat "$(vget OMP_ENV 2)")" $'KEEP=1\nKEY=PLANT-old'
}

test_ahead_default_answer_is_no() {
  seed_all
  settle
  printf '%s' "edited" >"$(file_of NPMRC)"
  tty_engine $'\n' sync
  assert_rc "sync" "$RC" 0
  assert_has "skipped" "$T/out" "skipped"
  assert_eq "vault untouched" "$(vver NPMRC)" 1
  assert_bytes "local untouched" "$(file_of NPMRC)" "edited"
}

test_ahead_raw_diff_runs_nvim_on_private_copies() {
  seed_all
  settle
  printf '%s' "edited" >"$(file_of NPMRC)"
  nvim_stub
  tty_engine $'v\nn\n' sync
  assert_rc "sync" "$RC" 0
  assert_eq "nvim called once" "$(nvim_calls)" 1
  local c=$T/nvim.call.1
  assert_eq "arguments before --" "$(sed '/^--$/q' "$c/argv" | tr '\n' ' ')" "--clean -n -R -d --cmd set noswapfile nowritebackup noundofile shadafile=NONE -- "
  assert_eq "first file is the live file" "$(cat "$c/path1")" "$(file_of NPMRC)"
  assert_eq "second file is a private copy" "$(basename "$(cat "$c/path2")")" "NPMRC.vault"
  assert_eq "copy mode" "$(cat "$c/mode2")" 600
  assert_eq "copy directory mode" "$(cat "$c/dirmode2")" 700
  assert_bytes "copy holds the vault bytes" "$c/file2" "v-NPMRC"
  assert_eq "no temp directory left behind" "$(find "$T/tmp" -mindepth 1 | wc -l | tr -d ' ')" 0
  assert_eq "vault untouched" "$(vver NPMRC)" 1
}

test_diverged_keep_local() {
  seed_all
  settle
  seed_s NPMRC "vault-side"
  printf '%s' "local-side" >"$(file_of NPMRC)"
  tty_engine $'k\n' sync
  assert_rc "sync" "$RC" 0
  assert_has "pushed" "$T/out" "pushed NPMRC v2 → v3"
  assert_bytes "vault has the local side" "$(vget NPMRC 3)" "local-side"
  assert_bytes "the vault side stays in history" "$(vget NPMRC 2)" "vault-side"
  assert_eq "base" "$(base_version NPMRC)" 3
}

test_diverged_take_vault_keeps_a_backup() {
  seed_all
  settle
  seed_s NPMRC "vault-side"
  printf '%s' "local-side" >"$(file_of NPMRC)"
  tty_engine $'t\n' sync
  assert_rc "sync" "$RC" 0
  assert_has "took" "$T/out" "took vault NPMRC v2"
  assert_bytes "local is the vault side" "$(file_of NPMRC)" "vault-side"
  assert_bytes "backup slot holds the local side" "$(state_file backup/NPMRC)" "local-side"
  assert_eq "backup mode" "$(tl_mode "$(state_file backup/NPMRC)")" 600
  assert_eq "base" "$(base_version NPMRC)" 2
  assert_eq "vault untouched" "$(vver NPMRC)" 2
}

test_diverged_skip_and_no_default() {
  seed_all
  settle
  seed_s NPMRC "vault-side"
  printf '%s' "local-side" >"$(file_of NPMRC)"
  tty_engine $'\n\ns\n' sync
  assert_rc "sync" "$RC" 0
  assert_eq "Enter alone does not choose: asked again twice" "$(grep -c 'answer one of: ktms' "$T/out")" 2
  assert_bytes "local untouched" "$(file_of NPMRC)" "local-side"
  assert_eq "vault untouched" "$(vver NPMRC)" 2
  tty_engine $'\004' sync
  assert_has "end of input skips" "$T/out" "skipped"
}

test_diverged_merge_edits_a_private_copy_and_pushes_it() {
  seed_all
  settle
  seed_s NPMRC "vault-side"
  printf '%s' "local-side" >"$(file_of NPMRC)"
  nvim_stub
  printf '%s' "+merged" >"$T/nvim.edit"
  tty_engine $'m\ny\n' sync
  assert_rc "sync" "$RC" 0
  local c=$T/nvim.call.1
  assert_eq "three windows: local, base, vault" "$(for i in 1 2 3; do basename "$(cat "$c/path$i")"; done | tr '\n' ' ')" "NPMRC.local NPMRC.base NPMRC.vault "
  assert_bytes "base window shows the version both sides started from" "$c/file2" "v-NPMRC"
  assert_bytes "vault window shows the vault side" "$c/file3" "vault-side"
  assert_bytes "the editor started from the local bytes" "$c/file1" "local-side"
  assert_has "base and vault are read-only" "$c/argv" "setlocal readonly nomodifiable"
  assert_eq "the live file was not what nvim edited" "$([[ $(cat "$c/path1") != "$(file_of NPMRC)" ]] && echo yes)" yes
  assert_has "pushed" "$T/out" "pushed NPMRC v2 → v3"
  assert_bytes "vault has the merge" "$(vget NPMRC 3)" "local-side+merged"
  assert_bytes "local has the merge" "$(file_of NPMRC)" "local-side+merged"
  assert_bytes "original local bytes saved" "$(state_file backup/NPMRC)" "local-side"
  assert_eq "no temp directory left behind" "$(find "$T/tmp" -mindepth 1 | wc -l | tr -d ' ')" 0
}

# The merge is pushed first and installed second: a check-and-set race must leave
# the local file exactly as it was, so the one backup slot still gets the original
# when the user then takes the vault.
test_a_merge_that_loses_the_cas_race_leaves_the_local_file_alone() {
  seed_all
  settle
  seed_s NPMRC "vault-side"
  printf '%s' "local-side-ORIGINAL" >"$(file_of NPMRC)"
  nvim_stub
  printf '%s' "+merged" >"$T/nvim.edit"
  shim_race NPMRC racer
  tty_engine $'m\ny\ns\n' sync
  assert_rc "sync" "$RC" 0
  assert_has "the race is noticed" "$T/out" "OpenBao changed while you were deciding"
  assert_bytes "local file is still the original" "$(file_of NPMRC)" "local-side-ORIGINAL"
  assert_absent "no backup was needed" "$(state_file backup/NPMRC)"
  assert_bytes "the vault has the racer's value, nothing of the merge" "$(vget NPMRC 3)" "racer"
  assert_eq "vault has exactly three versions" "$(vver NPMRC)" 3
}

test_merge_then_cas_race_then_take_vault_keeps_the_original_local_bytes() {
  seed_all
  settle
  seed_s NPMRC "vault-side"
  printf '%s' "local-side-ORIGINAL" >"$(file_of NPMRC)"
  nvim_stub
  printf '%s' "merged-result-without-the-original-text" >"$T/nvim.edit"
  sed -i.bak 's|>>"${files\[0\]}"|>"${files[0]}"|' "$T_SHIM/nvim"
  rm -f "$T_SHIM/nvim.bak"
  shim_race NPMRC racer
  # m = merge, y = push the merge (loses the race), t = take vault on the re-decided state
  tty_engine $'m\ny\nt\n' sync
  assert_rc "sync" "$RC" 0
  assert_bytes "local now follows the vault" "$(file_of NPMRC)" "racer"
  assert_bytes "the original local bytes are in the backup slot" "$(state_file backup/NPMRC)" "local-side-ORIGINAL"
}

test_diverged_merge_without_edits_asks_again() {
  seed_all
  settle
  seed_s NPMRC "vault-side"
  printf '%s' "local-side" >"$(file_of NPMRC)"
  nvim_stub
  tty_engine $'m\ns\n' sync
  assert_has "noticed" "$T/out" "no changes made"
  assert_eq "vault untouched" "$(vver NPMRC)" 2
  assert_bytes "local untouched" "$(file_of NPMRC)" "local-side"
}

test_unknown_rows() {
  seed_all
  # No settle: no records. Table order of the three: ATUIN_KEY, NPMRC, OMP_ENV.
  printf '%s' "local-a" >"$(file_of ATUIN_KEY)"
  printf '%s' "local-n" >"$(file_of NPMRC)"
  printf '%s' "local-o" >"$(file_of OMP_ENV)"
  tty_engine $'s\nk\nt\n' sync
  assert_rc "sync" "$RC" 0
  assert_has "unknown named" "$T/out" "no record of a previous sync"
  assert_bytes "skipped: local kept" "$(file_of ATUIN_KEY)" "local-a"
  assert_eq "skipped: vault untouched" "$(vver ATUIN_KEY)" 1
  assert_bytes "kept local: pushed with check-and-set on v1" "$(vget NPMRC 2)" "local-n"
  assert_has "pushed line" "$T/out" "pushed NPMRC v1 → v2"
  assert_bytes "took vault" "$(file_of OMP_ENV)" "v-OMP_ENV"
  assert_bytes "took vault: backup" "$(state_file backup/OMP_ENV)" "local-o"
}

test_rewound_rows() {
  seed_all
  settle
  ba kv metadata delete -mount=secret "$TL_SECRET_PREFIX/NPMRC" >/dev/null
  seed_s NPMRC "recreated-n"
  ba kv metadata delete -mount=secret "$TL_SECRET_PREFIX/OMP_ENV" >/dev/null
  seed_s OMP_ENV "recreated-o"
  tty_engine $'r\nt\n' sync
  assert_rc "sync" "$RC" 0
  assert_has "rewound named" "$T/out" "this Mac last synced v1"
  assert_bytes "restore: the vault now has the local bytes" "$(vget NPMRC 2)" "v-NPMRC"
  assert_bytes "take vault: local follows the recreated vault" "$(file_of OMP_ENV)" "recreated-o"
  assert_bytes "take vault: backup" "$(state_file backup/OMP_ENV)" "v-OMP_ENV"
}

test_vault_missing_rows() {
  seed_all
  settle
  ba kv metadata delete -mount=secret "$TL_SECRET_PREFIX/NPMRC" >/dev/null
  ba kv delete -mount=secret "$TL_SECRET_PREFIX/OMP_ENV" >/dev/null
  ba kv destroy -mount=secret -versions=1 "$TL_SECRET_PREFIX/ATUIN_KEY" >/dev/null
  ba kv metadata delete -mount=secret "$TL_SECRET_PREFIX/SSH_ID_CRYPT" >/dev/null
  rm -f "$(file_of SSH_ID_CRYPT)"
  # Table order: SSH_ID_CRYPT, ATUIN_KEY, NPMRC, OMP_ENV.
  tty_engine $'n\ny\ny\n' sync
  assert_rc "sync" "$RC" 0
  assert_has "nothing to restore from" "$T/out" "nothing to restore"
  assert_eq "destroyed + answered no: still missing" "$(vcount ATUIN_KEY)" 1
  assert_has "path gone: restored at cas 0" "$T/out" "pushed NPMRC - → v1"
  assert_has "deleted: restored at the current version" "$T/out" "pushed OMP_ENV v1 → v2"
  assert_bytes "restored bytes" "$(vget OMP_ENV 2)" "v-OMP_ENV"
}

test_blocked_is_explained_and_left_alone() {
  seed_all
  rm -f "$(file_of NPMRC)"
  printf '%s' target >"$T/target"
  ln -s "$T/target" "$(file_of NPMRC)"
  tty_engine "" sync
  assert_rc "sync" "$RC" 0
  assert_has "explains" "$T/out" "is not a regular file"
  assert_bytes "target untouched" "$T/target" target
}

test_a_vault_that_moves_during_the_prompt_reprompts() {
  [[ $TL_SHIM_OK -eq 1 ]] || {
    skip "bao shim is bypassed under SS_ENGINE"
    return 0
  }
  seed_all
  settle
  printf '%s' "local-edit" >"$(file_of NPMRC)"
  shim_race NPMRC racer
  tty_engine $'y\ns\n' sync
  assert_rc "sync" "$RC" 0
  assert_has "noticed the race" "$T/out" "OpenBao changed while you were deciding"
  assert_has "asked again with fresh facts" "$T/out" "both sides changed"
  assert_bytes "the other writer's value is intact" "$(vget NPMRC 2)" racer
  assert_eq "nothing newer was written" "$(vver NPMRC)" 2
  assert_bytes "local edit intact" "$(file_of NPMRC)" "local-edit"
  assert_eq "base unchanged" "$(base_version NPMRC)" 1
}

test_readback_mismatch_is_loud_and_leaves_the_base() {
  [[ $TL_SHIM_OK -eq 1 ]] || {
    skip "bao shim is bypassed under SS_ENGINE"
    return 0
  }
  seed_all
  settle
  printf '%s' "local-edit" >"$(file_of NPMRC)"
  shim_corrupt_readback
  tty_engine $'y\n' sync
  assert_rc "sync" "$RC" 1
  assert_has "says so" "$T/out" "read-back differs"
  assert_eq "base not advanced" "$(base_version NPMRC)" 1
}

test_values_that_cannot_round_trip_are_refused() {
  seed_all
  settle
  printf 'a\377b\n' >"$(file_of NPMRC)"
  tty_engine $'y\n' sync
  assert_rc "sync" "$RC" 1
  assert_has "refused" "$T/out" "refusing to push NPMRC: the value is not-utf8"
  assert_eq "vault untouched" "$(vver NPMRC)" 1
}

test_push_flag() {
  seed_all
  settle
  printf '%s' "edited" >"$(file_of NPMRC)"
  engine sync --push NPMRC
  assert_rc "ahead" "$RC" 0
  assert_has "pushed" "$T/out" "pushed NPMRC v1 → v2"
  assert_bytes "vault" "$(vget NPMRC 2)" edited

  seed_s OMP_ENV "vault-side"
  printf '%s' "local-side" >"$(file_of OMP_ENV)"
  engine sync --push OMP_ENV
  assert_rc "diverged" "$RC" 0
  assert_bytes "vault has the local side" "$(vget OMP_ENV 3)" "local-side"

  rm -f "$(state_file ATUIN_KEY.base.json)"
  printf '%s' "other" >"$(file_of ATUIN_KEY)"
  engine sync --push ATUIN_KEY
  assert_rc "unknown" "$RC" 0

  ba kv metadata delete -mount=secret "$TL_SECRET_PREFIX/SSH_ID_CRYPT" >/dev/null
  engine sync --push SSH_ID_CRYPT
  assert_rc "vault-missing" "$RC" 0
  assert_has "created at cas 0" "$T/out" "pushed SSH_ID_CRYPT - → v1"

  ba kv metadata delete -mount=secret "$TL_SECRET_PREFIX/SSH_ID_CRYPT_PUB" >/dev/null
  seed_s SSH_ID_CRYPT_PUB "recreated"
  engine sync --push SSH_ID_CRYPT_PUB
  assert_rc "rewound" "$RC" 0
}

test_push_flag_refuses_everything_else() {
  seed_all
  settle
  engine sync --push NPMRC
  assert_rc "in-sync" "$RC" 1
  assert_has "says why" "$T/err" "refusing to push NPMRC: it is in-sync"
  seed_s OMP_ENV "newer"
  engine sync --push OMP_ENV
  assert_rc "behind" "$RC" 1
  rm -f "$(file_of ATUIN_KEY)"
  engine sync --push ATUIN_KEY
  assert_rc "missing-local" "$RC" 1
  rm -f "$(file_of SSH_ID_CRYPT)"
  ln -s "$T/nowhere" "$(file_of SSH_ID_CRYPT)"
  engine sync --push SSH_ID_CRYPT
  assert_rc "blocked" "$RC" 1
  engine sync --push NOT_A_SECRET
  assert_rc "unknown name" "$RC" 1
  assert_has "lists how to see the names" "$T/err" "unknown secret"
  engine sync --push
  assert_rc "missing name" "$RC" 1
  assert_eq "nothing was written" "$(vver OMP_ENV)" 2
}

test_push_flag_stops_when_the_vault_moves() {
  [[ $TL_SHIM_OK -eq 1 ]] || {
    skip "bao shim is bypassed under SS_ENGINE"
    return 0
  }
  seed_all
  settle
  printf '%s' "local-edit" >"$(file_of NPMRC)"
  shim_race NPMRC racer
  engine sync --push NPMRC
  assert_rc "push" "$RC" 1
  assert_has "names check-and-set" "$T/err" "check-and-set"
  assert_bytes "the other writer's value is intact" "$(vget NPMRC 2)" racer
  assert_bytes "local edit intact" "$(file_of NPMRC)" "local-edit"
}

test_push_flag_offline() {
  seed_all
  settle
  srv_spawn "$T/dead"
  use_srv "$T/dead"
  kill -9 "$(cat "$T/dead/pid")"
  wait "$(cat "$T/dead/pid")" 2>/dev/null
  printf '%s' "edited" >"$(file_of NPMRC)"
  engine sync --push NPMRC
  assert_rc "push" "$RC" 1
  assert_has "names the cause" "$T/err" "connection refused"
  assert_bytes "local intact" "$(file_of NPMRC)" edited
}

test_sync_stops_when_the_vault_is_unreachable() {
  seed_all
  settle
  srv_spawn "$T/dead"
  use_srv "$T/dead"
  kill -9 "$(cat "$T/dead/pid")"
  wait "$(cat "$T/dead/pid")" 2>/dev/null
  tty_engine "" sync
  assert_rc "sync" "$RC" 1
  assert_has "names the cause" "$T/out" "OpenBao is unreachable"
}

test_push_refuses_a_file_that_changed_since_review() {
  # shellcheck source=/dev/null
  . "$ROOT/common.sh"
  # shellcheck source=/dev/null
  . "$ROOT/kv.sh"
  # shellcheck source=/dev/null
  . "$ROOT/state.sh"
  # shellcheck source=/dev/null
  . "$ROOT/push.sh"
  in_sandbox
  work_init
  kv_init
  state_init
  seed_s X1 one
  printf '%s' "reviewed" >"$T/dest"
  printf '%s' "changed after review" >"$T/dest"
  push_local X1 "$T/dest" 1 "$(sha_of reviewed)" 2>"$T/err"
  assert_rc "push_local" "$?" 1
  assert_has "says why" "$T/err" "changed while it was being reviewed"
  assert_eq "vault untouched" "$(vver X1)" 1
}

test_a_crash_after_the_push_converges() {
  local point
  for point in push-written push-verified; do
    seed_all
    settle
    printf '%s' "edit-$point" >"$(file_of NPMRC)"
    ENGINE_ENV=(SECRETSPEC_TEST_CRASH_AT=$point)
    engine sync --push NPMRC
    assert_rc "killed at $point" "$RC" 137
    assert_eq "the vault already has the new version" "$(vver NPMRC)" 2
    assert_eq "base not yet advanced" "$(base_version NPMRC)" 1
    ENGINE_ENV=()
    engine apply
    assert_rc "apply after the crash" "$RC" 0
    assert_eq "base caught up by apply" "$(base_version NPMRC)" "$(vver NPMRC)"
    assert_eq "no banner: it counts as in sync" "$(cat "$T/err")" ""
    engine sync --push NPMRC
    assert_rc "pushing again is refused: nothing to push" "$RC" 1
    ba kv metadata delete -mount=secret "$TL_SECRET_PREFIX/NPMRC" >/dev/null
    rm -rf "$T_STATE"
  done
}

test_summaries_hide_values() {
  # shellcheck source=/dev/null
  . "$ROOT/common.sh"
  # shellcheck source=/dev/null
  . "$ROOT/summary.sh"
  printf '%s' $'# comment\nKEEP=1\nKEY=PLANT-a\nGONE=PLANT-b\n  SPACED = PLANT-c\nloose line\nsame line\n' >"$T/vault"
  printf '%s' $'# comment\nKEEP=1\nKEY=PLANT-A\nNEW=PLANT-d\n  SPACED = PLANT-c\nsame line\nother line\n' >"$T/local"
  summary_masked OMP_ENV "$T/local" "$T/vault" >"$T/out"
  assert_has "added" "$T/out" "keys added (local vs OpenBao): NEW"
  assert_has "changed" "$T/out" "keys changed (local vs OpenBao): KEY"
  assert_has "removed" "$T/out" "keys removed (local vs OpenBao): GONE"
  assert_has "other lines" "$T/out" "other changed lines: 2"
  assert_lacks "no value" "$T/out" "PLANT"
  printf '%s' $'ssh-key AAAA\n' >"$T/v2"
  printf '%s' $'ssh-key AAAA\n\n' >"$T/l2"
  summary_masked SSH_ID_ED25519 "$T/l2" "$T/v2" >"$T/out"
  assert_has "sizes" "$T/out" "local 14 bytes, 2 trailing newline(s); OpenBao 13 bytes, 1 trailing newline(s); whitespace-only change: yes"
  printf '%s' $'ssh-key BBBB\n' >"$T/l3"
  summary_masked SSH_ID_ED25519 "$T/l3" "$T/v2" >"$T/out"
  assert_has "real change" "$T/out" "whitespace-only change: no"
  assert_lacks "no value" "$T/out" "AAAA"
}

test_no_value_reaches_the_transcript_or_argv() {
  local plant="PLANT-$RANDOM-$RANDOM-secret"
  seed_all
  reseed OMP_ENV "KEY=$plant-vault"
  settle
  printf '%s' "KEY=$plant-local" >"$(file_of OMP_ENV)"
  nvim_stub
  tty_engine $'v\ny\n' sync
  assert_rc "sync" "$RC" 0
  assert_lacks "terminal transcript" "$T/out" "$plant"
  if [[ $TL_SHIM_OK -eq 1 ]]; then
    assert_lacks "bao argv" "$T/bao.log" "$plant"
  fi
  assert_has "positive control: the value was pushed" "$(vget OMP_ENV 3)" "$plant-local"
  assert_has "positive control: the detector sees it in a leaky log" <(printf 'kv put x v=%s\n' "$plant") "$plant"
}

tl_init
tl_run_all
tl_done
