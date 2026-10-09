#!/usr/bin/env bash
# Tests for home/linux/docker-contexts.sh: the Home Manager activation step of the agent role that makes docker contexts for the user
# (`rootless`, the local daemon, and `jumphost`, ssh://...), once, and makes the first one the current context when it creates it.
# `docker` is a shim over a directory: it keeps the contexts as files and logs every call; no daemon, no network.
set -uo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
# shellcheck source=../secretspec/testlib.sh
. "$ROOT/home/secretspec/testlib.sh" || exit 1
# shellcheck source=minpath_testlib.sh
. "$ROOT/home/linux/minpath_testlib.sh" || exit 1
SCRIPT=$ROOT/home/linux/docker-contexts.sh

mkdocker() {
  mkdir -p "$T/bin" "$T/ctx"
  cat >"$T/bin/docker" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >>"$T/calls.log"
cd "$T/ctx" || exit 9
case "\$1 \$2" in
  "context inspect")
    shift 2
    [ "\$1" = --format ] && shift 2
    [ -f "ctx-\$1" ] || { echo "context \"\$1\" does not exist" >&2; exit 1; }
    cat "ctx-\$1" ;;
  "context create")
    [ -f "ctx-\$3" ] && exit 1
    [ "\${FAKE_DOCKER_FAIL:-}" = create ] && { echo "create failed" >&2; exit 1; }
    printf '%s' "\${5#host=}" >"ctx-\$3" ;;
  "context update")
    [ -f "ctx-\$3" ] || exit 1
    [ "\${FAKE_DOCKER_FAIL:-}" = update ] && { echo "update failed" >&2; exit 1; }
    printf '%s' "\${5#host=}" >"ctx-\$3" ;;
  "context use")
    printf '%s' "\$3" >current ;;
  *) echo "unexpected docker call: \$*" >&2; exit 99 ;;
esac
EOF
  chmod +x "$T/bin/docker"
  : >"$T/calls.log"
}
# step NAME HOST [current]: the activation step; prints the exit status.
step() {
  (
    PATH=$(minimal_path "$T/minbin")
    export PATH
    # shellcheck disable=SC2329 # called by ensure_docker_context
    run() { "$@"; }
    [ -z "${4:-}" ] || eval "$4"
    # shellcheck source=docker-contexts.sh
    . "$SCRIPT"
    ensure_docker_context "$T/bin/docker" "$1" "$2" "${3:-}"
  ) >"$T/out" 2>"$T/err"
  echo $?
}
host_of() { cat "$T/ctx/ctx-$1" 2>/dev/null; }
current() { cat "$T/ctx/current" 2>/dev/null; }

test_creates_a_missing_context_and_makes_it_current_when_asked() {
  mkdocker
  assert_rc "step" "$(step rootless unix:///run/user/1000/docker.sock current)" 0
  assert_eq "created with the host" "unix:///run/user/1000/docker.sock" "$(host_of rootless)"
  assert_eq "and current" rootless "$(current)"
  assert_eq "silent" "" "$(cat "$T/out" "$T/err")"
}

test_a_context_that_is_there_with_the_same_host_is_left_alone_and_the_current_one_is_not_touched() {
  mkdocker
  assert_rc "first" "$(step rootless unix:///run/user/1000/docker.sock current)" 0
  printf 'jumphost' >"$T/ctx/current"
  : >"$T/calls.log"
  assert_rc "second" "$(step rootless unix:///run/user/1000/docker.sock current)" 0
  assert_eq "the user's choice stays current" jumphost "$(current)"
  assert_eq "only the question was asked" 1 "$(wc -l <"$T/calls.log" | tr -d ' ')"
  assert_has "it was a read" "$T/calls.log" "context inspect"
}

test_a_context_with_another_host_is_updated_and_the_current_one_is_still_not_touched() {
  mkdocker
  assert_rc "first" "$(step rootless unix:///run/user/1000/docker.sock current)" 0
  printf 'jumphost' >"$T/ctx/current"
  assert_rc "second" "$(step rootless unix:///run/user/1001/docker.sock current)" 0
  assert_eq "host updated" "unix:///run/user/1001/docker.sock" "$(host_of rootless)"
  assert_eq "current untouched" jumphost "$(current)"
}

test_a_context_without_the_current_flag_is_not_made_current() {
  mkdocker
  assert_rc "step" "$(step jumphost ssh://jumphost_server)" 0
  assert_eq "created" "ssh://jumphost_server" "$(host_of jumphost)"
  assert_eq "not current" "" "$(current)"
}

test_a_failing_docker_is_reported_and_never_fails_the_activation() {
  mkdocker
  assert_rc "create fails" "$(FAKE_DOCKER_FAIL=create step rootless unix:///x current)" 0
  assert_has "says which context" "$T/err" "rootless"
  assert_has "and what failed" "$T/err" "could not"
  assert_eq "nothing made current" "" "$(current)"
  assert_rc "ok" "$(step rootless unix:///x current)" 0
  assert_rc "update fails" "$(FAKE_DOCKER_FAIL=update step rootless unix:///y current)" 0
  assert_has "says it" "$T/err" "could not"
  assert_eq "the old host stays" "unix:///x" "$(host_of rootless)"
}

test_a_dry_run_makes_nothing() {
  mkdocker
  assert_rc "step" "$(step rootless unix:///x current 'run() { echo "would run: $*"; }')" 0
  assert_eq "no context" "" "$(host_of rootless)"
  assert_eq "none current" "" "$(current)"
  assert_has "says what it would do" "$T/out" "would run:"
}

tl_init_pure
tl_run_all
tl_done
