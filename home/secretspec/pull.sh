# pull.sh: put vault bytes into a destination file (spec §5.9, "Pull"). Sourced,
# not run. Needs common.sh, state.sh and the globals that inspect.sh sets.

# ensure_layout: parent directories that must exist, with their modes.
ensure_layout() {
  mkdir -p "$HOME/.ssh" "$HOME/.local/share/atuin"
  chmod 700 "$HOME/.ssh" "$HOME/.local/share/atuin"
  (
    umask 022
    mkdir -p "$HOME/.config/atuin" "$HOME/.omp" "$HOME/.config/tofu"
  )
}

# install_file NAME DEST MODE SRC LSHA SHA
# Replaces DEST with the bytes of SRC (sha256 SHA): temp file in DEST's directory,
# verified, flushed, then renamed. LSHA is the hash of DEST when it was decided
# ("" for absent or empty). Returns 1 without touching DEST when DEST changed
# since then, or became a symlink or directory.
install_file() {
  local name=$1 dest=$2 mode=$3 src=$4 lsha=$5 sha=$6 parent base tmp cur
  parent=$(dirname "$dest")
  base=$(basename "$dest")
  mkdir -p "$parent"
  rm -f "$parent/.$base".sspull.*
  tmp=$(mktemp "$parent/.$base.sspull.XXXXXX") || die "cannot create a temp file in $parent"
  if ! cat "$src" >"$tmp"; then
    rm -f "$tmp"
    die "cannot write $tmp"
  fi
  chmod "$mode" "$tmp"
  if [[ $(file_sha256 "$tmp") != "$sha" ]]; then
    rm -f "$tmp"
    die "the copy of $name written to $parent does not match the expected bytes"
  fi
  sync "$tmp" || {
    rm -f "$tmp"
    die "cannot flush $tmp to disk"
  }
  crash_point pull-tmp-written
  cur=""
  if [[ -L $dest || -d $dest ]]; then
    cur=blocked
  elif [[ -s $dest ]]; then
    cur=$(file_sha256 "$dest") || cur=unreadable
  fi
  if [[ $cur != "$lsha" ]]; then
    rm -f "$tmp"
    echo "skipped $name: $dest changed while it was being written" >&2
    return 1
  fi
  mv -f "$tmp" "$dest"
}

# pull_file NAME DEST MODE SRC LSHA VERSION CT SHA
# install_file, then record the base: vault version VERSION, created at CT.
pull_file() {
  install_file "$1" "$2" "$3" "$4" "$5" "$8" || return 1
  crash_point pull-renamed
  base_write "$1" "$6" "$8" "$7"
}

# settle_auto NAME DEST MODE: after inspect, handle the rows that need no human.
#   5 in-sync: enforce the mode, record the base when it differs.
#   4, 8, 9 (missing-local, behind, stale): pull and print "pulled NAME vA → vB".
# Returns 0 when handled, 1 when the state is something else, 2 when a pull was
# skipped because the file changed meanwhile (the reason is on stderr).
settle_auto() {
  local name=$1 dest=$2 mode=$3 old
  case $D_STATE in
    in-sync)
      if [[ $(file_mode "$dest") != "$mode" ]]; then
        chmod "$mode" "$dest"
      fi
      if [[ $D_BV != "$D_CUR" || $D_BSHA != "$D_VSHA" || $D_BCT != "$D_CT" ]]; then
        base_write "$name" "$D_CUR" "$D_VSHA" "$D_CT"
      fi
      return 0
      ;;
    missing-local | behind | stale)
      old=${D_BV:+v$D_BV}
      if pull_file "$name" "$dest" "$mode" "$I_VALUE" "$D_LSHA" "$I_VERSION" "$I_CT" "$D_VSHA"; then
        echo "pulled $name ${old:--} → v$I_VERSION"
        return 0
      fi
      return 2
      ;;
  esac
  return 1
}
