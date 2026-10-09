#!/usr/bin/env bash
# Tests for home/linux/start-user-unit.sh: the Home Manager activation step of the agent role that starts a
# user unit which the NixOS switch only loads (rootless Docker). `systemctl` is a shim that logs its calls.
set -uo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
# shellcheck source=../secretspec/testlib.sh
. "$ROOT/home/secretspec/testlib.sh" || exit 1
# shellcheck source=minpath_testlib.sh
. "$ROOT/home/linux/minpath_testlib.sh" || exit 1
SCRIPT=$ROOT/home/linux/start-user-unit.sh

# mksystemctl CAT_RC START_RC: logs "XDG_RUNTIME_DIR|arguments" per call; `cat` exits CAT_RC, `start` exits START_RC.
mksystemctl() {
  mkdir -p "$T/bin"
  cat >"$T/bin/systemctl" <<EOF
#!/bin/sh
printf '%s|%s\n' "\${XDG_RUNTIME_DIR:-unset}" "\$*" >>"$T/systemctl.log"
case "\$*" in
  "--user cat "*) exit $1 ;;
  "--user start "*) exit $2 ;;
esac
exit 0
EOF
  chmod +x "$T/bin/systemctl"
  : >"$T/systemctl.log"
}
# step [RUNTIME-DIR] [RUN-DEFINITION]: the activation step as Home Manager runs it (`run` is its wrapper); prints the exit status.
step() {
  (
    PATH=$(minimal_path "$T/minbin")
    export PATH
    unset XDG_RUNTIME_DIR
    [ -z "${1:-}" ] || export XDG_RUNTIME_DIR=$1
    # shellcheck disable=SC2329 # called by start_user_unit
    run() { "$@"; }
    [ -z "${2:-}" ] || eval "$2"
    # shellcheck source=start-user-unit.sh
    . "$SCRIPT"
    start_user_unit "$T/bin/systemctl" docker.service
  ) >"$T/out" 2>"$T/err"
  echo $?
}

test_starts_a_unit_that_the_user_manager_knows() {
  mksystemctl 0 0
  assert_rc "step" "$(step /run/user/4242)" 0
  assert_eq "asked for the unit, then started it, with the runtime directory" "/run/user/4242|--user cat docker.service
/run/user/4242|--user start docker.service" "$(cat "$T/systemctl.log")"
  assert_eq "silent" "" "$(cat "$T/out" "$T/err")"
}

test_a_unit_that_does_not_exist_or_a_user_manager_that_is_not_there_is_no_error() {
  mksystemctl 1 0
  assert_rc "step" "$(step /run/user/4242)" 0
  assert_eq "nothing was started" "/run/user/4242|--user cat docker.service" "$(cat "$T/systemctl.log")"
  assert_eq "silent: at boot Home Manager runs before the user manager, which starts the unit itself" "" "$(cat "$T/out" "$T/err")"
}

test_a_failed_start_is_reported_but_never_fails_the_activation() {
  mksystemctl 0 1
  assert_rc "step" "$(step /run/user/4242)" 0
  assert_has "names the unit" "$T/err" "docker.service"
  assert_has "says what failed" "$T/err" "could not start"
}

test_the_runtime_directory_defaults_to_the_one_of_the_user() {
  mksystemctl 0 0
  assert_rc "step" "$(step)" 0
  assert_eq "run/user/<uid>" "/run/user/$(id -u)|--user start docker.service" "$(grep -F ' start ' "$T/systemctl.log" | head -n 1)"
}

test_a_dry_run_starts_nothing() {
  mksystemctl 0 0
  assert_rc "step" "$(step /run/user/4242 'run() { echo "would run: $*"; }')" 0
  assert_eq "no start call" 0 "$(grep -cF -- '--user start' "$T/systemctl.log")"
  assert_has "says what it would do" "$T/out" "would run:"
}

tl_init_pure
tl_run_all
tl_done
