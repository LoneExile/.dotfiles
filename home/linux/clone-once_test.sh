#!/usr/bin/env bash
# Tests for home/linux/clone-once.sh (clone_once): the activation helper that clones a repo into a
# directory only when nothing is there yet. The remote is a local bare repo (no network); `run` is
# Home Manager's, replaced here by one that acts (or, on a dry run, only prints).
set -uo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
# shellcheck source=../secretspec/testlib.sh
. "$ROOT/home/secretspec/testlib.sh" || exit 1
command -v git >/dev/null || { echo "git not found: skipping the clone-once tests"; exit 0; }
GIT=$(command -v git)

# conce URL DEST: run clone_once the way the activation does (set -eu -o pipefail); stdout and stderr
# land in $T/out and $T/err; prints the exit status.
conce() {
  (
    export HOME=$T_HOME GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
    set -eu -o pipefail
    run() { if [ -n "${DRY_RUN:-}" ]; then echo "would run: $*"; else "$@"; fi; }
    # shellcheck source=clone-once.sh
    . "$ROOT/home/linux/clone-once.sh"
    clone_once "$GIT" "$@"
  ) >"$T/out" 2>"$T/err"
  echo $?
}
# remote: a bare repo with one commit (file init.lua, "remote"); prints its file:// URL.
remote() {
  local w=$T/work
  "$GIT" init -q "$w"
  printf 'remote' >"$w/init.lua"
  "$GIT" -C "$w" -c user.name=t -c user.email=t@t add init.lua
  "$GIT" -C "$w" -c user.name=t -c user.email=t@t commit -qm one
  "$GIT" clone -q --bare "$w" "$T/remote.git"
  echo "file://$T/remote.git"
}
DEST() { echo "$T_HOME/.config/nvim"; }
# leftovers: entries next to DEST other than DEST itself (a temp dir the helper did not remove).
leftovers() { find "$T_HOME/.config" -mindepth 1 -maxdepth 1 ! -name nvim 2>/dev/null; }

test_an_absent_directory_is_cloned() {
  local url
  url=$(remote)
  assert_rc "clone" "$(conce "$url" "$(DEST)")" 0
  assert_eq "the remote's file is there" remote "$(cat "$(DEST)/init.lua" 2>/dev/null)"
  assert_eq "it is a git checkout of the remote" "$url" "$("$GIT" -C "$(DEST)" remote get-url origin 2>/dev/null)"
  assert_eq "no temp dir is left next to it" "" "$(leftovers)"
  assert_eq "nothing on stderr" "" "$(cat "$T/err")"
}

test_a_checkout_with_a_local_edit_is_left_as_it_is() {
  local url
  url=$(remote)
  conce "$url" "$(DEST)" >/dev/null
  printf 'edited on the host' >"$(DEST)/init.lua"
  assert_rc "run again (the next switch)" "$(conce "$url" "$(DEST)")" 0
  assert_eq "the edit stays" "edited on the host" "$(cat "$(DEST)/init.lua")"
  assert_eq "nothing printed" "" "$(cat "$T/out" "$T/err")"
}

test_an_empty_directory_is_left_as_it_is() {
  local url
  url=$(remote)
  mkdir -p "$(DEST)"
  assert_rc "run" "$(conce "$url" "$(DEST)")" 0
  assert_eq "still empty" "" "$(ls -A "$(DEST)")"
  assert_eq "nothing printed" "" "$(cat "$T/out" "$T/err")"
}

test_a_file_in_the_way_is_left_as_it_is() {
  local url
  url=$(remote)
  mkdir -p "$(dirname "$(DEST)")"
  printf 'a file' >"$(DEST)"
  assert_rc "run" "$(conce "$url" "$(DEST)")" 0
  assert_eq "the file stays" "a file" "$(cat "$(DEST)")"
  assert_eq "no temp dir is left next to it" "" "$(leftovers)"
}

test_a_broken_symlink_is_left_as_it_is() {
  local url
  url=$(remote)
  mkdir -p "$(dirname "$(DEST)")"
  ln -s "$T/nowhere" "$(DEST)"
  assert_rc "run" "$(conce "$url" "$(DEST)")" 0
  assert_eq "still the same link" "$T/nowhere" "$(readlink "$(DEST)")"
  assert_eq "no temp dir is left next to it" "" "$(leftovers)"
}

test_an_unreachable_remote_warns_and_does_not_fail() {
  assert_rc "run (no network, no such repo)" "$(conce "file:///nonexistent/nvim.git" "$(DEST)")" 0
  assert_eq "one line on stderr names the URL and the directory" "clone-once: could not clone file:///nonexistent/nvim.git into $(DEST)" "$(cat "$T/err")"
  assert_absent "no directory" "$(DEST)"
  assert_eq "no temp dir is left" "" "$(leftovers)"
}

test_a_dry_run_changes_nothing() {
  local url
  url=$(remote)
  assert_rc "dry run" "$(DRY_RUN=1 conce "$url" "$(DEST)")" 0
  assert_absent "no directory" "$(DEST)"
  assert_eq "no temp dir is left" "" "$(leftovers)"
}

tl_init_pure
tl_run_all
tl_done
