#!/usr/bin/env bash
# Tests for home/linux/writable-copy.sh (writable_copy): the activation helper that installs a
# repo file as a writable one. Plain files in a temp HOME; `run` is Home Manager's, replaced here by
# one that acts (or, on a dry run, only prints).
set -uo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
# shellcheck source=../secretspec/testlib.sh
. "$ROOT/home/secretspec/testlib.sh" || exit 1

# wcopy SRC DEST: run writable_copy the way the activation does (set -eu -o pipefail); stdout and
# stderr land in $T/out and $T/err; prints the exit status.
wcopy() {
  (
    export HOME=$T_HOME
    set -eu -o pipefail
    run() { if [ -n "${DRY_RUN:-}" ]; then echo "would run: $*"; else "$@"; fi; }
    # shellcheck source=writable-copy.sh
    . "$ROOT/home/linux/writable-copy.sh"
    writable_copy "$@"
  ) >"$T/out" 2>"$T/err"
  echo $?
}
# repo CONTENT: a read-only file standing for a store file; prints its path.
repo() {
  mkdir -p "$T/store"
  local f=$T/store/f$RANDOM
  printf '%s' "$1" >"$f"
  chmod 444 "$f"
  echo "$f"
}
DEST() { echo "$T_HOME/.omp/agent/config.yml"; }
mode() { tl_mode "$1"; }

test_installs_a_missing_file_writable_and_creates_the_directory() {
  local s
  s=$(repo one)
  assert_rc "install" "$(wcopy "$s" "$(DEST)")" 0
  assert_eq "content" one "$(cat "$(DEST)")"
  assert_eq "owner can write" 644 "$(mode "$(DEST)")"
  assert_eq "not a link" "" "$(find "$(DEST)" -type l)"
}

test_an_identical_file_is_left_alone() {
  local s
  s=$(repo one)
  mkdir -p "$(dirname "$(DEST)")"
  printf one >"$(DEST)"
  assert_rc "run" "$(wcopy "$s" "$(DEST)")" 0
  assert_eq "content" one "$(cat "$(DEST)")"
  assert_absent "no backup" "$(DEST).dotfiles-backup"
}

test_an_edit_on_the_vm_survives_while_the_repo_copy_is_unchanged() {
  local s
  s=$(repo one)
  assert_rc "install" "$(wcopy "$s" "$(DEST)")" 0
  printf 'edited on the VM' >"$(DEST)"
  assert_rc "activation again (a deploy, a reboot)" "$(wcopy "$s" "$(DEST)")" 0
  assert_eq "the edit stays" "edited on the VM" "$(cat "$(DEST)")"
  assert_absent "no backup" "$(DEST).dotfiles-backup"
  assert_rc "and again" "$(wcopy "$s" "$(DEST)")" 0
  assert_eq "still there" "edited on the VM" "$(cat "$(DEST)")"
}

test_a_new_repo_copy_replaces_the_file_and_keeps_the_edit_as_a_backup() {
  local s1 s2
  s1=$(repo one)
  s2=$(repo two)
  assert_rc "install" "$(wcopy "$s1" "$(DEST)")" 0
  printf 'edited on the VM' >"$(DEST)"
  assert_rc "the repo copy changed" "$(wcopy "$s2" "$(DEST)")" 0
  assert_eq "new content" two "$(cat "$(DEST)")"
  assert_eq "the edit is the backup" "edited on the VM" "$(cat "$(DEST).dotfiles-backup")"
  assert_has "says so" "$T/out" "dotfiles-backup"
  assert_eq "writable" 644 "$(mode "$(DEST)")"
  assert_rc "the next activation" "$(wcopy "$s2" "$(DEST)")" 0
  assert_eq "nothing more happens" two "$(cat "$(DEST)")"
}

test_a_new_repo_copy_replaces_an_unedited_file_without_a_backup() {
  local s1 s2
  s1=$(repo one)
  s2=$(repo two)
  assert_rc "install" "$(wcopy "$s1" "$(DEST)")" 0
  assert_rc "the repo copy changed" "$(wcopy "$s2" "$(DEST)")" 0
  assert_eq "new content" two "$(cat "$(DEST)")"
  assert_absent "no backup" "$(DEST).dotfiles-backup"
}

test_a_file_nobody_installed_is_backed_up_when_it_differs() {
  local s
  s=$(repo one)
  mkdir -p "$(dirname "$(DEST)")"
  printf 'was here before' >"$(DEST)"
  assert_rc "install over it" "$(wcopy "$s" "$(DEST)")" 0
  assert_eq "new content" one "$(cat "$(DEST)")"
  assert_eq "the old file is the backup" "was here before" "$(cat "$(DEST).dotfiles-backup")"
}

test_a_link_into_the_store_becomes_a_writable_file() {
  # What an earlier Home Manager generation left: a symlink to a read-only store file.
  local s old
  s=$(repo one)
  old=$(repo old)
  mkdir -p "$(dirname "$(DEST)")"
  ln -s "$old" "$(DEST)"
  assert_rc "install over the link" "$(wcopy "$s" "$(DEST)")" 0
  assert_eq "content" one "$(cat "$(DEST)")"
  assert_eq "now a regular file" "" "$(find "$(DEST)" -type l)"
  assert_eq "writable" 644 "$(mode "$(DEST)")"
  assert_eq "the old target is untouched" old "$(cat "$old")"
}

test_a_read_only_copy_is_replaced() {
  local s1 s2
  s1=$(repo one)
  s2=$(repo two)
  assert_rc "install" "$(wcopy "$s1" "$(DEST)")" 0
  chmod 444 "$(DEST)"
  assert_rc "the repo copy changed" "$(wcopy "$s2" "$(DEST)")" 0
  assert_eq "content" two "$(cat "$(DEST)")"
  assert_eq "writable again" 644 "$(mode "$(DEST)")"
}

test_files_do_not_share_a_record() {
  local s1 s2 other
  s1=$(repo one)
  s2=$(repo two)
  other=$T_HOME/.omp/agent/models.yml
  assert_rc "first file" "$(wcopy "$s1" "$(DEST)")" 0
  assert_rc "second file, another content" "$(wcopy "$s2" "$other")" 0
  printf 'edited' >"$(DEST)"
  assert_rc "first again" "$(wcopy "$s1" "$(DEST)")" 0
  assert_eq "its edit stays" edited "$(cat "$(DEST)")"
  assert_eq "the other is untouched" two "$(cat "$other")"
}

test_a_dry_run_changes_nothing() {
  local s
  s=$(repo one)
  assert_rc "dry run" "$(DRY_RUN=1 wcopy "$s" "$(DEST)")" 0
  assert_absent "no file" "$(DEST)"
  assert_absent "no record" "$T_HOME/.local/state/dotfiles"
  assert_has "says what it would do" "$T/out" "would run: cp"
}

test_it_keeps_going_under_the_activations_strict_mode() {
  # set -eu -o pipefail is on in wcopy(); a missing record and a missing destination must not stop it.
  local s
  s=$(repo one)
  assert_rc "first activation" "$(wcopy "$s" "$(DEST)")" 0
  assert_rc "second activation" "$(wcopy "$s" "$(DEST)")" 0
}

tl_init_pure
tl_run_all
tl_done
