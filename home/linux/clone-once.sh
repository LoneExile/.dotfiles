# shellcheck shell=bash
# clone_once GIT URL DEST: clone URL into DEST, but only when nothing is at DEST yet. Sourced by a
# Home Manager activation step (home/linux/neovim.nix), which supplies `run` (it prints instead of
# acting on a dry run). Needs git and coreutils only.
#
# The clone is the user's from then on, as on the Mac: this never pulls, resets or replaces it.
#   - DEST exists in any form (a checkout, an empty directory, a file, a link, a broken link): nothing
#     happens and nothing is printed.
#   - DEST is absent: the clone goes into a temporary directory next to DEST, which is moved to DEST
#     only when the clone succeeded, so a half-done clone is never taken for the user's checkout.
#   - The clone fails (no network, no such repo): one line on stderr, and the step returns 0, so a switch
#     without network still succeeds. git removes the directory of a failed clone itself (tested).
clone_once() {
  local git=$1 url=$2 dest=$3 tmp
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    return 0
  fi
  tmp="$(dirname "$dest")/.clone-once.$$.$(basename "$dest")"
  run mkdir -p "$(dirname "$dest")"
  if run "$git" clone --quiet "$url" "$tmp" 2>/dev/null; then
    run mv "$tmp" "$dest"
  else
    echo "clone-once: could not clone $url into $dest" >&2
  fi
  return 0
}
