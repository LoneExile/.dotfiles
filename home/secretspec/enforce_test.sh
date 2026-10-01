#!/usr/bin/env bash
# Tests for `materialize.sh enforce-cas`: cas_required on the 14 paths (spec D8).
set -uo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=testlib.sh
. "$ROOT/testlib.sh" || exit 1
# shellcheck source=testlib_engine.sh
. "$ROOT/testlib_engine.sh" || exit 1

# token_with CAPS_ON_METADATA: a token whose policy has these capabilities on the
# metadata paths plus create/read/update on the data paths.
token_with() {
  printf 'path "secret/metadata/%s/*" { capabilities=[%s] }\npath "secret/data/%s/*" { capabilities=["create","read","update"] }\n' \
    "$TL_SECRET_PREFIX" "$1" "$TL_SECRET_PREFIX" | ba policy write enforce-test - >/dev/null
  ba token create -no-default-policy -policy=enforce-test -format=json | jq -r .auth.client_token
}

test_enforce_sets_cas_required_on_every_path_and_keeps_settings() {
  seed_all
  settle
  ba kv metadata put -mount=secret -max-versions=7 "$TL_SECRET_PREFIX/NPMRC" >/dev/null
  engine enforce-cas
  assert_rc "enforce-cas" "$RC" 0
  assert_eq "one line per secret" "$(grep -c '^cas_required ' "$T/out")" 14
  local n bad=0
  for n in $NAMES; do
    [[ $(vmeta "$n" | jq -r .data.cas_required) == true ]] || bad=$((bad + 1))
  done
  assert_eq "every path has cas_required" "$bad" 0
  assert_eq "other settings are kept" "$(vmeta NPMRC | jq -r .data.max_versions)" 7

  printf '{"data":{"value":"plain"}}' | ba write -format=json "secret/data/$TL_SECRET_PREFIX/NPMRC" - >/dev/null 2>"$T/e"
  assert_rc "a write without check-and-set is now refused" "$?" 2
  assert_has "says why" "$T/e" "check-and-set parameter required"

  printf '%s' "edited" >"$(file_of NPMRC)"
  engine sync --push NPMRC
  assert_rc "this engine still pushes" "$RC" 0
  assert_has "pushed" "$T/out" "pushed NPMRC v1 → v2"
  engine apply
  assert_rc "and still applies" "$RC" 0
  engine enforce-cas
  assert_rc "running it again" "$RC" 0
}

test_a_missing_path_fails_but_the_rest_are_enforced() {
  seed_all
  ba kv metadata delete -mount=secret "$TL_SECRET_PREFIX/SSH_ID_CRYPT" >/dev/null
  engine enforce-cas
  assert_rc "enforce-cas" "$RC" 1
  assert_has "names the path" "$T/err" "SSH_ID_CRYPT: no such path"
  assert_eq "the other 13 are done" "$(grep -c '^cas_required ' "$T/out")" 13
  assert_has "summary" "$T/err" "1 of 14 paths are not enforced"
}

test_update_alone_is_not_enough_but_patch_is() {
  seed_all
  local weak strong
  weak=$(token_with '"read","update"')
  ENGINE_ENV=(VAULT_TOKEN="$weak")
  engine enforce-cas
  assert_rc "token with update only" "$RC" 1
  assert_has "names the capability" "$T/err" "patch capability"
  assert_eq "nothing enforced" "$(vmeta NPMRC | jq -r .data.cas_required)" false
  strong=$(token_with '"read","patch"')
  ENGINE_ENV=(VAULT_TOKEN="$strong")
  engine enforce-cas
  assert_rc "token with patch" "$RC" 0
  assert_eq "enforced" "$(vmeta NPMRC | jq -r .data.cas_required)" true
}

test_enforce_stops_when_the_vault_is_unreachable() {
  seed_all
  srv_spawn "$T/dead"
  use_srv "$T/dead"
  kill -9 "$(cat "$T/dead/pid")"
  wait "$(cat "$T/dead/pid")" 2>/dev/null
  engine enforce-cas
  assert_rc "enforce-cas" "$RC" 1
  assert_has "names the cause" "$T/err" "unreachable"
}

tl_init
tl_run_all
tl_done
