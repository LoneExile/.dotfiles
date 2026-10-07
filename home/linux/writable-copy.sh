# shellcheck shell=bash
# writable_copy SRC DEST: install SRC (a file of the Nix store) as DEST, a real, writable file.
# Sourced by the Home Manager activation of home/linux/agent.nix, which supplies `run` (it prints
# instead of acting on a dry run). Needs coreutils only.
#
# Home Manager would link such a file into the store, and the store is read-only: `mise use -g`
# and omp's own settings could not write it. The repo copy wins only when it is new:
#   - DEST is missing: install it.
#   - DEST is the repo copy: nothing to do.
#   - DEST differs, and the repo copy is the one installed last time: an edit made on the VM. It
#     stays, across deploys and reboots (Home Manager activates at every boot).
#   - DEST differs, and the repo copy is new since the last install: the file is replaced. An edit
#     made on the VM is kept as DEST.dotfiles-backup first, one previous version, never dropped
#     silently. A file that is still the copy installed last time is replaced without a backup.
# "Installed last time" is a hash in ~/.local/state/dotfiles/writable-copy/, one file per DEST.
writable_copy() {
  local src=$1 dest=$2 stamp want have recorded
  stamp=${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/writable-copy/${dest//\//_}
  want=$(sha256sum <"$src")
  want=${want%% *}
  recorded=$(cat "$stamp" 2>/dev/null || true)
  if [ -f "$dest" ]; then
    have=$(sha256sum <"$dest")
    have=${have%% *}
    if [ "$have" = "$want" ]; then
      record_writable_copy "$stamp" "$want"
      return 0
    fi
    [ "$recorded" = "$want" ] && return 0
    if [ "$have" != "$recorded" ]; then
      run mv -f "$dest" "$dest.dotfiles-backup"
      echo "writable copy: $dest differed from the repo copy, kept as $(basename "$dest").dotfiles-backup"
    fi
  fi
  run mkdir -p "$(dirname "$dest")"
  run cp -f "$src" "$dest"
  run chmod u+w "$dest"
  record_writable_copy "$stamp" "$want"
}

# record_writable_copy STAMP HASH: remember which repo copy is installed (not on a dry run).
record_writable_copy() {
  [ -z "${DRY_RUN:-}" ] || return 0
  mkdir -p "$(dirname "$1")"
  printf '%s\n' "$2" >"$1"
}
