#!/usr/bin/env bash
# Tests for state.sh: base records, last-contact, backup slot, migration of the
# old <NAME>.sha256 records, crash safety.
set -uo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=testlib.sh
. "$ROOT/testlib.sh" || exit 1
# shellcheck source=common.sh
. "$ROOT/common.sh" || exit 1
# shellcheck source=kv.sh
. "$ROOT/kv.sh" || exit 1
# shellcheck source=state.sh
. "$ROOT/state.sh" || exit 1

st_ready() {
  in_sandbox
  work_init
  kv_init
  state_init
}

# proc CODE: run CODE in a fresh bash with the scripts sourced, so a crash seam
# (kill -9 $$) only kills that process.
proc() {
  "$TL_BASH" -c ". '$ROOT/common.sh'; . '$ROOT/kv.sh'; . '$ROOT/state.sh'; work_init; kv_init; state_init; $1"
}

SHA_A=$(sha_of A)
SHA_B=$(sha_of B)
SHA_C=$(sha_of C)

test_layout_and_modes() {
  in_sandbox
  state_dir_init
  assert_absent "state_dir_init writes nothing" "$STATE_DIR"
  work_init
  state_init
  assert_eq "state dir mode" "$(file_mode "$STATE_DIR")" 700
  assert_eq "backup dir mode" "$(file_mode "$STATE_DIR/backup")" 700
  base_write NAME1 3 "$SHA_A" 2026-01-01T00:00:00Z
  contact_write
  printf 'x' >"$T/f"
  backup_put NAME1 "$T/f"
  assert_eq "base.json mode" "$(file_mode "$STATE_DIR/NAME1.base.json")" 600
  assert_eq "last-contact mode" "$(file_mode "$STATE_DIR/last-contact")" 600
  assert_eq "backup mode" "$(file_mode "$STATE_DIR/backup/NAME1")" 600
  assert_eq "state_dir_init honours XDG_STATE_HOME" "$STATE_DIR" "$T_STATE/dotfiles/secretspec"
}

test_base_round_trip() {
  st_ready
  base_read NAME1
  assert_eq "no record reads empty" "[$B_VERSION|$B_SHA|$B_CT|$B_NOTE]" "[|||]"
  base_write NAME1 3 "$SHA_A" 2026-01-01T00:00:00.123Z
  base_read NAME1
  assert_eq "round trip" "$B_VERSION|$B_SHA|$B_CT" "3|$SHA_A|2026-01-01T00:00:00.123Z"
  base_write NAME1 4 "$SHA_B" 2026-01-02T00:00:00Z
  base_read NAME1
  assert_eq "overwrite" "$B_VERSION|$B_SHA" "4|$SHA_B"
  assert_eq "no temp files left" "$(find "$STATE_DIR" -name '.tmp.*' | wc -l | tr -d ' ')" 0
  assert_eq "record is plain JSON with the three fields" "$(jq -c 'keys' "$STATE_DIR/NAME1.base.json")" '["created_time","sha256","version"]'
}

test_unusable_records_read_as_no_base() {
  st_ready
  local i=0 body
  for body in 'not json' '{}' '{"version":0,"sha256":"x","created_time":"t"}' \
    "{\"version\":\"3\",\"sha256\":\"$SHA_A\",\"created_time\":\"t\"}" \
    "{\"version\":3,\"sha256\":\"abc\",\"created_time\":\"t\"}" \
    "{\"version\":1.5,\"sha256\":\"$SHA_A\",\"created_time\":\"t\"}" \
    "{\"version\":3,\"sha256\":\"$SHA_A\"}"; do
    i=$((i + 1))
    printf '%s' "$body" >"$STATE_DIR/BAD$i.base.json"
    base_read "BAD$i"
    assert_eq "unusable record #$i" "[$B_VERSION|$B_SHA|$B_CT]/$B_NOTE" "[||]/corrupt"
  done
}

test_last_contact_bound() {
  st_ready
  contact_fresh && bad "no record is not fresh" || ok "no record is not fresh"
  contact_write
  contact_fresh && ok "just now is fresh" || bad "just now is fresh"
  local now
  now=$(date +%s)
  printf '%s\n' $((now - 6 * 86400)) >"$STATE_DIR/last-contact"
  contact_fresh && ok "6 days is fresh" || bad "6 days is fresh"
  printf '%s\n' $((now - 7 * 86400 - 60)) >"$STATE_DIR/last-contact"
  contact_fresh && bad "7 days and a minute is stale" || ok "7 days and a minute is stale"
  assert_eq "age is reported in seconds" "$([[ $(contact_age) -ge 604860 && $(contact_age) -le 604900 ]] && echo yes)" yes
  printf 'garbage' >"$STATE_DIR/last-contact"
  contact_fresh && bad "garbage is not fresh" || ok "garbage is not fresh"
  # A time in the future (clock set back, file edited) would give a negative
  # age and never trip the bound: it is not a contact.
  printf '%s\n' $((now + 90 * 86400)) >"$STATE_DIR/last-contact"
  contact_fresh && bad "90 days in the future is not fresh" || ok "90 days in the future is not fresh"
  assert_eq "no age is reported for the future" "$(contact_age)" ""
  printf '%s\n' 99999999999 >"$STATE_DIR/last-contact"
  contact_fresh && bad "year 5138 is not fresh" || ok "year 5138 is not fresh"
}

test_backup_has_one_slot() {
  st_ready
  printf 'first' >"$T/a"
  printf 'second' >"$T/b"
  backup_put NAME1 "$T/a"
  backup_put NAME1 "$T/b"
  assert_bytes "newest backup wins" "$STATE_DIR/backup/NAME1" second
  assert_eq "one file in the slot dir" "$(find "$STATE_DIR/backup" -type f | wc -l | tr -d ' ')" 1
}

test_state_init_removes_stale_temp_files() {
  st_ready
  : >"$STATE_DIR/.tmp.AAAAAA"
  : >"$STATE_DIR/backup/.tmp.BBBBBB"
  state_init
  assert_eq "stale temp files are gone" "$(find "$STATE_DIR" -name '.tmp.*' | wc -l | tr -d ' ')" 0
}

test_crash_while_writing_a_record_keeps_the_old_one() {
  st_ready
  base_write NAME1 3 "$SHA_A" t3
  proc "base_write NAME1 4 $SHA_B t4"
  assert_rc "control run without a crash" "$?" 0
  SECRETSPEC_TEST_CRASH_AT=state-tmp-written proc "base_write NAME1 5 $SHA_C t5"
  assert_rc "killed after the temp file" "$?" 137
  base_read NAME1
  assert_eq "old record intact" "$B_VERSION" 4
  assert_eq "a temp file was left behind" "$(find "$STATE_DIR" -name '.tmp.*' | wc -l | tr -d ' ')" 1
  state_init
  assert_eq "next run cleans it" "$(find "$STATE_DIR" -name '.tmp.*' | wc -l | tr -d ' ')" 0
}

test_legacy_sha_is_read_only_when_valid() {
  st_ready
  printf '%s\n' "$SHA_A" >"$STATE_DIR/NAME1.sha256"
  assert_eq "valid legacy hash" "$(base_legacy NAME1)" "$SHA_A"
  printf 'not-a-hash\n' >"$STATE_DIR/NAME2.sha256"
  assert_eq "garbage legacy file" "$(base_legacy NAME2)" ""
  assert_eq "no legacy file" "$(base_legacy NAME3)" ""
}

test_migrate_current_version_matches() {
  st_ready
  seed_s M1 A
  printf '%s\n' "$SHA_A" >"$STATE_DIR/M1.sha256"
  kv_read M1
  state_migrate M1 "$KV_VERSION" "$KV_CT" "$KV_SHA" 1
  assert_rc "migrate" "$?" 0
  base_read M1
  assert_eq "base is the current version" "$B_VERSION|$B_SHA" "1|$SHA_A"
  assert_eq "created_time copied from the vault" "$B_CT" "$KV_CT"
  assert_absent "legacy file removed" "$STATE_DIR/M1.sha256"
}

test_migrate_scans_newest_first() {
  st_ready
  local v
  for v in A B A C; do seed_s M2 "$v"; done
  printf '%s\n' "$SHA_A" >"$STATE_DIR/M2.sha256"
  kv_read M2
  state_migrate M2 "$KV_VERSION" "$KV_CT" "$KV_SHA" 1
  assert_rc "migrate" "$?" 0
  base_read M2
  assert_eq "newest matching version wins (v3, not v1)" "$B_VERSION|$B_SHA" "3|$SHA_A"
  assert_absent "legacy file removed" "$STATE_DIR/M2.sha256"
}

test_migrate_without_a_match_changes_nothing() {
  st_ready
  seed_s M3 A
  seed_s M3 B
  printf '%s\n' "$(sha_of Z)" >"$STATE_DIR/M3.sha256"
  kv_read M3
  state_migrate M3 "$KV_VERSION" "$KV_CT" "$KV_SHA" 1
  assert_rc "no match" "$?" 1
  assert_absent "no base written" "$STATE_DIR/M3.base.json"
  assert_eq "legacy file kept" "$(base_legacy M3)" "$(sha_of Z)"
  base_read M3
  assert_eq "no base" "$B_VERSION" ""
}

test_migrate_ignores_pruned_deleted_and_destroyed_versions() {
  st_ready
  ba kv metadata put -mount=secret -max-versions=3 "$TL_SECRET_PREFIX/M4" >/dev/null
  local v
  for v in A B C D E; do seed_s M4 "$v"; done
  printf '%s\n' "$SHA_A" >"$STATE_DIR/M4.sha256"
  kv_read M4
  state_migrate M4 "$KV_VERSION" "$KV_CT" "$KV_SHA" 1
  assert_rc "match only in a pruned version" "$?" 1

  seed_s M5 A
  seed_s M5 B
  seed_s M5 C
  ba kv delete -mount=secret -versions=1 "$TL_SECRET_PREFIX/M5" >/dev/null
  ba kv destroy -mount=secret -versions=2 "$TL_SECRET_PREFIX/M5" >/dev/null
  printf '%s\n' "$SHA_A" >"$STATE_DIR/M5.sha256"
  kv_read M5
  state_migrate M5 "$KV_VERSION" "$KV_CT" "$KV_SHA" 1
  assert_rc "match only in a deleted version" "$?" 1
  printf '%s\n' "$SHA_B" >"$STATE_DIR/M5.sha256"
  state_migrate M5 "$KV_VERSION" "$KV_CT" "$KV_SHA" 1
  assert_rc "match only in a destroyed version" "$?" 1
}

test_migrate_dry_run_writes_nothing() {
  st_ready
  seed_s M6 A
  seed_s M6 B
  printf '%s\n' "$SHA_A" >"$STATE_DIR/M6.sha256"
  kv_read M6
  state_migrate M6 "$KV_VERSION" "$KV_CT" "$KV_SHA" 0
  assert_rc "dry run" "$?" 0
  assert_eq "result is reported" "$B_VERSION" 1
  assert_absent "no base.json" "$STATE_DIR/M6.base.json"
  assert_eq "legacy file untouched" "$(base_legacy M6)" "$SHA_A"
}

test_migrate_with_the_vault_down_changes_nothing() {
  st_ready
  seed_s M7 A
  seed_s M7 B
  printf '%s\n' "$SHA_A" >"$STATE_DIR/M7.sha256"
  kv_read M7
  local cur=$KV_VERSION ct=$KV_CT sha=$KV_SHA
  srv_spawn "$T/dead"
  use_srv "$T/dead"
  SECRETSPEC_SYNC_ADDR=$S_ADDR VAULT_TOKEN=$S_TOK
  kv_init
  kill -9 "$(cat "$T/dead/pid")"
  wait "$(cat "$T/dead/pid")" 2>/dev/null
  state_migrate M7 "$cur" "$ct" "$sha" 1
  assert_rc "vault unreachable" "$?" 2
  assert_eq "class is soft" "$KV_CLASS" soft
  assert_absent "no base.json" "$STATE_DIR/M7.base.json"
  assert_eq "legacy file untouched" "$(base_legacy M7)" "$SHA_A"
}

test_interrupted_migration_converges() {
  st_ready
  seed_s M8 A
  seed_s M8 B
  printf '%s\n' "$SHA_A" >"$STATE_DIR/M8.sha256"
  SECRETSPEC_TEST_CRASH_AT=base-written proc 'kv_read M8; state_migrate M8 "$KV_VERSION" "$KV_CT" "$KV_SHA" 1'
  assert_rc "killed between base.json and removing the legacy file" "$?" 137
  base_read M8
  assert_eq "base.json already counts" "$B_VERSION" 1
  assert_eq "legacy file still there" "$(base_legacy M8)" "$SHA_A"
  state_prune_legacy M8
  assert_absent "next run prunes the legacy file" "$STATE_DIR/M8.sha256"
  base_read M8
  assert_eq "base survives" "$B_VERSION" 1
  printf '%s\n' "$SHA_C" >"$STATE_DIR/M9.sha256"
  state_prune_legacy M9
  assert_eq "no base: legacy file is kept" "$(base_legacy M9)" "$SHA_C"
}

tl_init
tl_run_all
tl_done
