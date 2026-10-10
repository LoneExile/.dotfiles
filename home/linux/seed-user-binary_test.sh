#!/usr/bin/env bash
# Tests for home/linux/seed-user-binary.sh (seed_user_binary): the Home Manager activation step of the agent role that gives the user
# a regular copy of omp in ~/.local/bin, so that `omp update` can replace it. Plain files in a temp HOME. `run` is Home Manager's,
# replaced here by one that acts; `mv` is a shim that logs its arguments (and can fail) before it runs the real one. The step
# runs under the minimal PATH of an activation script and with `set -eu -o pipefail`, as Home Manager runs it.
set -uo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
# shellcheck source=../secretspec/testlib.sh
. "$ROOT/home/secretspec/testlib.sh" || exit 1
# shellcheck source=minpath_testlib.sh
. "$ROOT/home/linux/minpath_testlib.sh" || exit 1
SCRIPT=$ROOT/home/linux/seed-user-binary.sh

# mkshim: the mv shim, in the minimal bin directory (minimal_path keeps a command that is already there).
mkshim() {
  mkdir -p "$T/minbin"
  cat >"$T/minbin/mv" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >>"$T/mv.log"
[ -z "\${FAKE_MV_FAIL:-}" ] || exit 1
exec "$(command -v mv)" "\$@"
EOF
  chmod +x "$T/minbin/mv"
  : >"$T/mv.log"
}
# store CONTENT: a read-only executable standing for the store binary; prints its path.
store() {
  mkdir -p "$T/store"
  local f=$T/store/omp$RANDOM
  printf '%s' "$1" >"$f"
  chmod 555 "$f"
  echo "$f"
}
# seed SRC DEST [SETUP]: the activation step; SETUP is evaluated first (a `run` or `DRY_RUN` definition, an exported failure switch).
# Prints the exit status; stdout and stderr land in $T/out and $T/err.
seed() {
  mkshim
  (
    PATH=$(minimal_path "$T/minbin")
    export PATH
    set -eu -o pipefail
    run() { if [ -n "${DRY_RUN:-}" ]; then echo "would run: $*"; else "$@"; fi; }
    [ -z "${3:-}" ] || eval "$3"
    # shellcheck source=seed-user-binary.sh
    . "$SCRIPT"
    seed_user_binary "$1" "$2"
  ) >"$T/out" 2>"$T/err"
  echo $?
}
DEST() { echo "$T_HOME/.local/bin/omp"; }
mode() { tl_mode "$1"; }
inode() { ls -i "$1" | cut -d' ' -f1; }
listing() { ls -A "$1" | tr '\n' ' '; }

test_a_missing_file_is_seeded_as_a_regular_executable_copy_and_the_directory_is_made() {
  local s
  s=$(store binary-1)
  assert_rc "seed" "$(seed "$s" "$(DEST)")" 0
  assert_eq "content" binary-1 "$(cat "$(DEST)")"
  assert_eq "mode 755, not the 555 of the store file" 755 "$(mode "$(DEST)")"
  assert_eq "a regular file, not a link" "" "$(find "$(DEST)" -type l)"
  assert_eq "owned by the user that ran it" "$(id -u)" "$(stat -c %u "$(DEST)" 2>/dev/null || stat -f %u "$(DEST)")"
  assert_eq "nothing else is left in the directory (no temporary file)" "omp " "$(listing "$(dirname "$(DEST)")")"
  assert_has "says what it did" "$T/out" "seeded $(DEST)"
}

test_the_mode_is_755_whatever_the_umask() {
  local s
  s=$(store binary-1)
  assert_rc "seed under umask 077" "$(seed "$s" "$(DEST)" 'umask 077')" 0
  assert_eq "mode" 755 "$(mode "$(DEST)")"
}

test_the_copy_runs() {
  local s
  s=$(store '#!/bin/sh
echo "omp 18.8.7"')
  assert_rc "seed" "$(seed "$s" "$(DEST)")" 0
  assert_eq "it is a program that runs from its own place" "omp 18.8.7" "$("$(DEST)")"
}

test_a_link_into_the_store_is_replaced_by_a_copy_and_the_store_file_stays() {
  local s old
  s=$(store binary-2)
  old=$(store old-store-binary)
  mkdir -p "$(dirname "$(DEST)")"
  ln -s "$old" "$(DEST)"
  assert_rc "seed" "$(seed "$s" "$(DEST)")" 0
  assert_eq "a regular file now" "" "$(find "$(DEST)" -type l)"
  assert_eq "content is the seed's" binary-2 "$(cat "$(DEST)")"
  assert_eq "mode" 755 "$(mode "$(DEST)")"
  assert_eq "the file that the link named is untouched" old-store-binary "$(cat "$old")"
  assert_eq "and keeps its mode" 555 "$(mode "$old")"
  assert_has "says what the link was" "$T/out" "it was a link to $old"
}

test_a_dangling_link_is_replaced() {
  local s
  s=$(store binary-3)
  mkdir -p "$(dirname "$(DEST)")"
  ln -s /nonexistent/store/path/bin/omp "$(DEST)"
  assert_rc "seed" "$(seed "$s" "$(DEST)")" 0
  assert_eq "a regular file" "" "$(find "$(DEST)" -type l)"
  assert_eq "content" binary-3 "$(cat "$(DEST)")"
}

test_a_link_to_a_directory_is_left_alone() {
  local s
  s=$(store binary-4)
  mkdir -p "$(dirname "$(DEST)")" "$T/elsewhere"
  ln -s "$T/elsewhere" "$(DEST)"
  assert_rc "seed" "$(seed "$s" "$(DEST)")" 0
  assert_eq "still the same link" "$T/elsewhere" "$(readlink "$(DEST)")"
  assert_eq "nothing was put into the directory" "" "$(listing "$T/elsewhere")"
  assert_has "says so" "$T/err" "link to a directory, left alone"
}

test_a_regular_file_is_never_replaced_not_even_by_a_newer_seed() {
  local s
  s=$(store binary-5-new)
  mkdir -p "$(dirname "$(DEST)")"
  printf 'updated by omp update' >"$(DEST)"
  chmod 700 "$(DEST)"
  local before
  before=$(inode "$(DEST)")
  assert_rc "seed" "$(seed "$s" "$(DEST)")" 0
  assert_eq "content is the user's" "updated by omp update" "$(cat "$(DEST)")"
  assert_eq "mode is the user's" 700 "$(mode "$(DEST)")"
  assert_eq "the same file (no rename over it)" "$before" "$(inode "$(DEST)")"
  assert_eq "no rename was attempted" "" "$(cat "$T/mv.log")"
  assert_eq "no temporary file" "omp " "$(listing "$(dirname "$(DEST)")")"
  assert_eq "silent" "" "$(cat "$T/out" "$T/err")"
}

test_every_run_after_the_first_changes_nothing_and_a_user_update_survives() {
  local s1 s2
  s1=$(store binary-6-pin)
  s2=$(store binary-6-newer-pin)
  assert_rc "first run" "$(seed "$s1" "$(DEST)")" 0
  assert_eq "seeded" binary-6-pin "$(cat "$(DEST)")"
  assert_rc "second run (a deploy, a reboot)" "$(seed "$s1" "$(DEST)")" 0
  assert_eq "no rename on the second run" "" "$(cat "$T/mv.log")"
  printf 'omp update put this here' >"$(DEST)"
  assert_rc "a deploy of a newer pin" "$(seed "$s2" "$(DEST)")" 0
  assert_eq "the user's copy stays" "omp update put this here" "$(cat "$(DEST)")"
}

test_deleting_the_copy_gives_the_seed_back() {
  local s1 s2
  s1=$(store binary-7-pin)
  s2=$(store binary-7-newer-pin)
  assert_rc "first run" "$(seed "$s1" "$(DEST)")" 0
  rm "$(DEST)"
  assert_rc "run after the reset" "$(seed "$s2" "$(DEST)")" 0
  assert_eq "the current pin is back" binary-7-newer-pin "$(cat "$(DEST)")"
}

test_the_copy_is_renamed_over_the_target_from_the_same_directory() {
  local s tmp target
  s=$(store binary-8)
  assert_rc "seed" "$(seed "$s" "$(DEST)")" 0
  assert_eq "one rename" 1 "$(wc -l <"$T/mv.log" | tr -d ' ')"
  # shellcheck disable=SC2034 # the first word is the -f flag
  read -r _ tmp target <"$T/mv.log"
  assert_eq "the target is the file itself" "$(DEST)" "$target"
  assert_eq "the source is in the directory of the target (same file system, so the rename is atomic)" "$(dirname "$(DEST)")" "$(dirname "$tmp")"
  assert_absent "the temporary name is gone" "$tmp"
}

test_a_failed_copy_leaves_the_target_as_it_was_and_no_temporary_file() {
  mkdir -p "$(dirname "$(DEST)")"
  ln -s /nonexistent/store/path/bin/omp "$(DEST)"
  assert_rc "seed from a source that is not there" "$(seed "$T/store/not-there" "$(DEST)")" 1
  assert_eq "the target is the link it was" /nonexistent/store/path/bin/omp "$(readlink "$(DEST)")"
  assert_eq "no temporary file" "omp " "$(listing "$(dirname "$(DEST)")")"
}

test_a_failed_rename_leaves_the_target_as_it_was_and_no_temporary_file() {
  local s old
  s=$(store binary-9)
  old=$(store old-store-binary-9)
  mkdir -p "$(dirname "$(DEST)")"
  ln -s "$old" "$(DEST)"
  assert_rc "seed with a mv that fails" "$(seed "$s" "$(DEST)" 'export FAKE_MV_FAIL=1')" 1
  assert_eq "the target is the link it was" "$old" "$(readlink "$(DEST)")"
  assert_eq "no temporary file" "omp " "$(listing "$(dirname "$(DEST)")")"
}

test_a_dry_run_changes_nothing() {
  local s
  s=$(store binary-10)
  assert_rc "seed" "$(seed "$s" "$(DEST)" 'DRY_RUN=1')" 0
  assert_absent "no file" "$(DEST)"
  assert_absent "no directory" "$(dirname "$(DEST)")"
  assert_has "says what it would do" "$T/out" "would seed $(DEST)"
}

tl_init_pure
tl_run_all
tl_done
