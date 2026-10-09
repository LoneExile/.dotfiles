# shellcheck shell=bash
# minimal_path DIR: a bin directory with links to the commands that a Home Manager activation script can rely on (its
# emptyActivationPath: bash, coreutils, diffutils, findutils, gettext, gnugrep, gnused, jq, ncurses, nix) and nothing else: no awk, no ssh,
# no python. An activation script that needs another command works in a test with the full PATH and fails on the VM; run under this PATH
# it fails here too. A command that is already in DIR (a shim) is kept. Prints DIR.
minimal_path() {
  local dir=$1 c p
  mkdir -p "$dir"
  for c in bash cat chmod chown cp cut date dirname basename du env head id install ln ls mkdir mktemp mv readlink rm rmdir sleep sort stat tail tee touch tr uname wc xargs find grep egrep fgrep sed diff cmp jq; do
    [ -e "$dir/$c" ] || [ -L "$dir/$c" ] && continue
    p=$(command -v "$c") || continue
    case $p in /*) ln -s "$p" "$dir/$c" ;; esac
  done
  printf '%s\n' "$dir"
}
