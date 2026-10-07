#!/usr/bin/env bash
# Tests for infra/vault-map.sh (map_get, map_put). A stub `secretspec` keeps the "vault" in files
# under $T/store; it refuses an empty `set` like the real one. Fixtures only.
set -uo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../home/secretspec/testlib.sh
. "$ROOT/home/secretspec/testlib.sh" || exit 1

PW=fixture0luks0pass0123456789abcdef0123456789abcdef0123456789ab

stub() {
  mkdir -p "$T/bin" "$T/store"
  cat >"$T/bin/secretspec" <<'EOF'
#!/bin/sh
f="$STUB_DIR/$2"
case "$1" in
  get) [ -f "$f" ] || { echo "no such secret" >&2; exit 1; }; cat "$f" ;;
  set) [ "${STUB_SET_FAILS:-0}" = 0 ] || exit 1
       d=$(cat); [ -n "$d" ] || { echo "Secret value cannot be empty" >&2; exit 1; }
       printf '%s' "$d" >"$f" ;;
esac
EOF
  chmod +x "$T/bin/secretspec"
  export STUB_DIR="$T/store" PATH="$T/bin:$PATH"
}
# put KEY NAME VALUE: run map_put as vm-install.sh does (die exits the subshell), print the exit status.
put() {
  (
    die() {
      printf 'vm-install: %s\n' "$1" >&2
      exit 1
    }
    # shellcheck source=vault-map.sh
    . "$ROOT/infra/vault-map.sh"
    map_put "$@"
  ) >"$T/out" 2>"$T/err"
  echo $?
}
stored() { cat "$T/store/$1"; }

test_put_adds_and_overwrites_one_entry() {
  stub
  printf '{}' >"$T/store/K"
  assert_rc "add" "$(put K vmone "$PW")" 0
  assert_eq "stored" '{"vmone":"'"$PW"'"}' "$(stored K)"
  assert_rc "overwrite" "$(put K vmone other)" 0
  assert_eq "overwritten" '{"vmone":"other"}' "$(stored K)"
}

test_put_keeps_the_other_entries() {
  stub
  printf '{"keep":"v"}' >"$T/store/K"
  assert_rc "add" "$(put K vmone x)" 0
  assert_eq "both" '{"keep":"v","vmone":"x"}' "$(stored K)"
}

test_non_object_map_fails_without_echoing_the_value() {
  local bad
  for bad in '[1]' '"text"' '7' 'null'; do
    stub
    printf '%s' "$bad" >"$T/store/K"
    assert_rc "map $bad" "$(put K vmone "$PW")" 1
    assert_has "names the key" "$T/err" "K in the vault is not a JSON object"
    assert_lacks "stderr hides the value" "$T/err" "fixture0luks0pass"
    assert_lacks "stdout hides the value" "$T/out" "fixture0luks0pass"
    assert_eq "stored value untouched" "$bad" "$(stored K)"
  done
}

test_unreadable_secret_fails_and_writes_nothing() {
  stub
  assert_rc "missing secret" "$(put NOKEY vmone "$PW")" 1
  assert_has "says it cannot read" "$T/err" "cannot read NOKEY from the vault"
  assert_lacks "stderr hides the value" "$T/err" "fixture0luks0pass"
  assert_absent "nothing written" "$T/store/NOKEY"
}

test_empty_stored_value_fails_and_stays_empty() {
  stub
  : >"$T/store/E"
  assert_rc "empty secret" "$(put E vmone "$PW")" 1
  assert_lacks "stderr hides the value" "$T/err" "fixture0luks0pass"
  assert_eq "still empty" "" "$(stored E)"
}

test_failed_vault_write_is_reported() {
  stub
  printf '{"keep":"v"}' >"$T/store/K"
  export STUB_SET_FAILS=1
  assert_rc "set fails" "$(put K vmone "$PW")" 1
  assert_has "says it cannot write" "$T/err" "cannot write K to the vault"
  assert_eq "stored value untouched" '{"keep":"v"}' "$(stored K)"
}

test_get_reads_one_entry() {
  stub
  printf '{"vmone":"%s","vmtwo":"y"}' "$PW" >"$T/store/K"
  assert_eq "map_get" "$PW" "$(. "$ROOT/infra/vault-map.sh"; map_get K vmone)"
  assert_eq "absent name" "" "$(. "$ROOT/infra/vault-map.sh"; map_get K nobody)"
}

tl_init_pure
tl_run_all
tl_done
