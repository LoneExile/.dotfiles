# shellcheck shell=bash
# seed_user_binary SRC DEST: give the user a copy of the program SRC (a file of the Nix store) at DEST, a regular file that the user owns.
# Sourced by the Home Manager activation of home/linux/agent.nix, which supplies `run` (it prints instead of acting on a dry run).
# Needs coreutils only (mktemp, install, mv).
#
# omp updates itself: `omp update` downloads the release asset and renames it over its own file, and it refuses to run from the Nix
# store. So the store binary is only the seed (and the fallback, on the system PATH). DEST is the user's after that:
#   - DEST is missing: the copy is made (mode 755, owned by the user that runs this).
#   - DEST is a symlink (into the store, or dangling): it is replaced by the copy. A symlink to a directory is left alone.
#   - DEST is anything else (an updated copy, the copy of an earlier deploy, a file that the user put there): left alone, always.
#     A deploy never downgrades it, and a newer pin in the repo does not replace it either. To go back to the pin: delete DEST, then
#     deploy (or reboot: Home Manager activates at every boot).
# The copy is written to a temporary file in the directory of DEST and renamed over it, so nothing ever reads a half-written program
# and a failed copy leaves DEST as it was (the temporary file is removed).
seed_user_binary() {
  local src=$1 dest=$2 dir tmp was=""
  dir=$(dirname "$dest")
  if [ -L "$dest" ]; then
    if [ -d "$dest" ]; then
      echo "seed: $dest is a link to a directory, left alone" >&2
      return 0
    fi
    was=" (it was a link to $(readlink "$dest"))"
  elif [ -e "$dest" ]; then
    return 0
  fi
  if [ -n "${DRY_RUN:-}" ]; then
    echo "would seed $dest with a copy of $src"
    return 0
  fi
  run mkdir -p "$dir"
  tmp=$(mktemp "$dir/.$(basename "$dest").seed.XXXXXX")
  install -m 755 "$src" "$tmp" || {
    rm -f "$tmp"
    return 1
  }
  run mv -f "$tmp" "$dest" || {
    rm -f "$tmp"
    return 1
  }
  echo "seeded $dest with a copy of $src$was"
}
