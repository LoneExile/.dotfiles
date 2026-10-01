#!/usr/bin/env bash
# Tests for the harness itself (testlib.sh): a test file must not be able to
# reach anything the caller's environment names.
set -uo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=testlib.sh
. "$ROOT/testlib.sh" || exit 1

# The caller's shell exports VAULT_ADDR, BAO_ADDR and tokens (a port-forward to
# the real OpenBao, a logged-in session). kv_test.sh runs with exactly that
# environment; the listener stands in for the real OpenBao and must see nothing.
test_the_environment_of_the_caller_cannot_reach_a_vault() {
  local port
  listener_spawn "$T/canary" 300
  port=$(cat "$T/canary/port")
  mkdir -p "$T/fakehome"
  RC=0
  env HOME="$T/fakehome" VAULT_ADDR="http://127.0.0.1:$port" BAO_ADDR="http://127.0.0.1:$port" \
    VAULT_TOKEN=canary-token BAO_TOKEN=canary-token "$TL_BASH" "$ROOT/kv_test.sh" >"$T/kv_test.out" 2>&1 || RC=$?
  listener_stop "$T/canary"
  assert_eq "kv_test.sh passes in that environment" "$RC" 0
  assert_absent "the listener saw no connection from kv_test.sh" "$T/canary/seen"

  # Positive control: an unscoped bao call in the same environment does connect.
  listener_spawn "$T/control" 10
  port=$(cat "$T/control/port")
  env -i HOME="$T/fakehome" PATH="$PATH" VAULT_ADDR="http://127.0.0.1:$port" BAO_TOKEN=canary-token \
    BAO_CLIENT_TIMEOUT=2s "$TL_BAO" kv get -mount=secret canary/x >/dev/null 2>&1
  listener_stop "$T/control"
  assert_has "positive control: an unscoped bao call reaches the listener" "$T/control/seen" "CONNECTED"
}

tl_init_pure
TL_BAO=$(command -v bao) || exit 2
tl_run_all
tl_done
