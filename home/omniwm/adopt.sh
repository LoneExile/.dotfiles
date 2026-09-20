#!/usr/bin/env bash
# Before just home/switch: if ~/.config/omniwm/settings.toml is a regular
# file, Home Manager will not replace it with the out-of-store symlink.
# TTY: nvim -d (or diff -u) then y/N to remove the regular file.
# Non-TTY: leave it and shout.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="${OMNIWM_REPO:-$ROOT/settings.toml}"
DEST="${OMNIWM_DEST:-$HOME/.config/omniwm/settings.toml}"

MODE=ask
case ${1:-} in
  --yes) MODE=yes ;;
  --keep) MODE=keep ;;
  "") ;;
  *)
    echo "usage: $0 [--yes|--keep]" >&2
    exit 2
    ;;
esac

same_file() {
  [[ -e $1 && -e $2 ]] || return 1
  [[ $(realpath "$1") == "$(realpath "$2")" ]]
}

shout_regular() {
  echo "omniwm: $DEST is a regular file; Home Manager will not replace it." >&2
  echo "  repo: $REPO" >&2
}

show_diff() {
  if command -v nvim >/dev/null 2>&1 && [[ -t 0 && -t 1 ]]; then
    nvim -d -R -n -i NONE --cmd 'set noswapfile noundofile nobackup nowritebackup shadafile=NONE' -- "$DEST" "$REPO"
    return
  fi
  diff -u --label repo --label local "$REPO" "$DEST" || true
}

confirm_replace() {
  local ans
  if cmp -s "$DEST" "$REPO"; then
    printf 'local settings.toml is not a symlink (bytes match repo). Replace with symlink? [y/N] '
  else
    show_diff
    printf 'replace local with repo (Home Manager will symlink)? [y/N] '
  fi
  read -r ans || true
  [[ $ans == [yY] ]]
}

if [[ ! -e $DEST ]]; then
  exit 0
fi

if [[ -L $DEST ]] && same_file "$DEST" "$REPO"; then
  exit 0
fi

if [[ $MODE == keep ]]; then
  shout_regular
  exit 0
fi

if [[ $MODE == yes ]]; then
  rm -f "$DEST"
  exit 0
fi

if [[ ! -t 0 || ! -t 1 ]]; then
  shout_regular
  exit 0
fi

if confirm_replace; then
  rm -f "$DEST"
else
  shout_regular
fi
