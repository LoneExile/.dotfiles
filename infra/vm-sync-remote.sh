#!/usr/bin/env bash
# The part of vm-sync and vm-deploy that runs ON the VM, as the agent user (never as root: root
# runs nothing inside the user's home). The Mac sends this file over SSH and calls one subcommand:
#
#   hindsight               read the Hindsight URL and API key (two lines) on stdin, write
#                           ~/.config/dotfiles/hindsight.env (zsh reads it, see home/linux/agent.nix)
#   hindsight-remove NAME   remove that file (the vault map has no entry for the VM NAME), one line
#   skills-prepare NAME...  make ~/.omp/agent/skills, check the named entries, record them
#   plugins-status          say whether the captured omp plugins are installed
#   unsync                  remove exactly what the sync placed
#
# The sync keeps a record of what it placed, so that `unsync` (run by vm-deploy before the VM leaves
# the agent role) removes that and nothing else: ~/.local/state/dotfiles/vm-sync/manifest, one line
# per item: `file REL`, `dir REL` (a directory the sync made: removed only while empty), `backup REL`
# (a file of the user that the sync displaced: put back by unsync), `skill NAME` (a directory of
# ~/.omp/agent/skills). REL is relative to $HOME and never leaves it. The plugin install (Home Manager
# places the manifests, a user service installs them) has no line: unsync recognises it by the
# records the Home Manager activation keeps for the files it placed, and removes ~/.omp/plugins as one
# directory together with those records and the install stamp.
#
# The key comes on stdin only: never an argument, never printed, never in the manifest.
# Exit: 0 done, 1 refused or failed, 2 usage.
set -uo pipefail

state_root=${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles
state_dir=$state_root/vm-sync
manifest=$state_dir/manifest

die() { # die CODE MESSAGE
  printf 'vm-sync-remote: %s\n' "$2" >&2
  exit "$1"
}

# record KIND REL: add a line to the manifest unless it is there.
record() {
  mkdir -p "$state_dir" || die 1 "cannot create $state_dir"
  grep -qxF -- "$1 $2" "$manifest" 2>/dev/null || printf '%s %s\n' "$1" "$2" >>"$manifest"
}

# mkdir_recorded REL [MODE]: mkdir -p REL below $HOME, recording each directory that had to be made.
mkdir_recorded() {
  local rel=$1 mode=${2:-} part="" comp
  local IFS=/
  for comp in $rel; do
    part=${part:+$part/}$comp
    if [ ! -d "$HOME/$part" ]; then
      if [ -n "$mode" ]; then mkdir -m "$mode" "$HOME/$part"; else mkdir "$HOME/$part"; fi || die 1 "cannot create ~/$part"
      record dir "$part"
    fi
  done
}

# valid_name NAME: a single path component of letters, digits, dot, underscore, dash; not starting
# with dot or dash.
valid_name() { [[ $1 =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; }

# valid_rel REL: a relative path of such components, with no "." or ".." component.
valid_rel() {
  [[ $1 =~ ^[A-Za-z0-9._][A-Za-z0-9._/-]*$ ]] || return 1
  case "/$1/" in
    */../* | */./* | *//*) return 1 ;;
  esac
  return 0
}

# parent_is_plain REL: no component above the last one of $HOME/REL is a link.
parent_is_plain() {
  local rel=${1%/*} part="" comp
  [ "$rel" != "$1" ] || return 0
  local IFS=/
  for comp in $rel; do
    part=${part:+$part/}$comp
    [ ! -L "$HOME/$part" ] || return 1
  done
  return 0
}

# hindsight.env is ours when the manifest has it or its first line is the marker.
hs_rel=.config/dotfiles/hindsight.env
hs_mark='# vm-sync: written from the vault map VM_HINDSIGHT; vm-sync removes it when the VM has no entry'
hs_is_ours() { # hs_is_ours FILE
  grep -qxF -- "file $hs_rel" "$manifest" 2>/dev/null || [ "$(head -n 1 -- "$1" 2>/dev/null)" = "$hs_mark" ]
}

cmd_hindsight() {
  local url key rest file=$HOME/$hs_rel tmp
  IFS= read -r url || true
  IFS= read -r key || true
  if IFS= read -r rest; then die 1 "more than two lines on stdin"; fi
  [[ $url =~ ^https://[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?(:[0-9]{1,5})?(/[A-Za-z0-9._/-]*)?$ ]] ||
    die 1 "the Hindsight URL on stdin has an unexpected shape (https://host[:port][/path], letters, digits and . - _ / only)"
  [[ $key =~ ^[A-Za-z0-9_-]{20,255}$ ]] ||
    die 1 "the Hindsight key on stdin has an unexpected shape (one line of 20 to 255 letters, digits, underscores or dashes)"
  parent_is_plain "$hs_rel" || die 1 "a directory above ~/$hs_rel is a link"
  mkdir_recorded .config/dotfiles 700
  if { [ -e "$file" ] || [ -L "$file" ]; } && ! hs_is_ours "$file"; then
    mv -f -- "$file" "$file.dotfiles-backup" || die 1 "cannot keep the existing hindsight.env"
    record backup "$hs_rel.dotfiles-backup"
    echo "hindsight: kept the existing hindsight.env as hindsight.env.dotfiles-backup (unsync puts it back)"
  fi
  record file "$hs_rel"
  tmp=$(mktemp "$HOME/.config/dotfiles/.hindsight.env.XXXXXX") || die 1 "cannot create a temporary file"
  printf '%s\nHINDSIGHT_API_URL='"'%s'"'\nHINDSIGHT_API_TOKEN='"'%s'"'\n' "$hs_mark" "$url" "$key" >"$tmp" || {
    rm -f "$tmp"
    die 1 "cannot write the Hindsight file"
  }
  mv -f -- "$tmp" "$file" || die 1 "cannot place hindsight.env"
  echo "hindsight: wrote ~/$hs_rel"
}

cmd_hindsight_remove() {
  [ $# -eq 1 ] || die 2 "hindsight-remove needs one VM name"
  valid_name "$1" || die 1 "not a usable VM name: $(printf '%q' "$1")"
  local file=$HOME/$hs_rel tmp
  parent_is_plain "$hs_rel" || die 1 "a directory above ~/$hs_rel is a link: left alone"
  if [ ! -e "$file" ] && [ ! -L "$file" ]; then
    echo "hindsight: no entry for $1 in VM_HINDSIGHT, no file to remove"
  elif [ -L "$file" ] || [ -d "$file" ] || ! hs_is_ours "$file"; then
    echo "hindsight: no entry for $1 in VM_HINDSIGHT; ~/$hs_rel left alone (not written by vm-sync)"
  else
    rm -f -- "$file" || die 1 "cannot remove ~/$hs_rel"
    if [ -f "$manifest" ]; then
      tmp=$(mktemp "$state_dir/.manifest.XXXXXX") || die 1 "cannot update the manifest"
      grep -vxF -- "file $hs_rel" "$manifest" >"$tmp" || true
      mv -f -- "$tmp" "$manifest" || die 1 "cannot update the manifest"
    fi
    echo "hindsight: no entry for $1 in VM_HINDSIGHT, removed ~/$hs_rel"
  fi
}

cmd_skills_prepare() {
  [ $# -ge 1 ] || die 2 "skills-prepare needs at least one name"
  local n p skills=$HOME/.omp/agent/skills
  for n in "$@"; do
    valid_name "$n" || die 1 "not a usable skill directory name: $(printf '%q' "$n")"
  done
  [ ! -L "$HOME/.omp" ] && [ ! -L "$HOME/.omp/agent" ] && [ ! -L "$skills" ] || die 1 "~/.omp, ~/.omp/agent or ~/.omp/agent/skills is a link"
  for n in "$@"; do
    p=$skills/$n
    [ ! -L "$p" ] || die 1 "$n in ~/.omp/agent/skills is a link: refusing to mirror into it"
    if [ -e "$p" ] && [ ! -d "$p" ]; then die 1 "$n in ~/.omp/agent/skills is not a directory"; fi
  done
  mkdir_recorded .omp/agent/skills
  for n in "$@"; do record skill "$n"; done
}

cmd_plugins_status() {
  local plugins=$HOME/.omp/plugins
  if [ -f "$state_root/omp-plugins.stamp" ] && [ -d "$plugins/node_modules" ]; then
    echo "plugins: installed"
    return 0
  fi
  if command -v systemctl >/dev/null 2>&1 && systemctl --user is-active omp-plugins-install.service 2>/dev/null | grep -Eq '^(active|activating)$'; then
    echo "plugins: installing in the background (journalctl --user -u omp-plugins-install)"
    return 0
  fi
  echo "plugins: not installed yet (systemctl --user status omp-plugins-install)"
}

cmd_unsync() {
  local rc=0 removed=0 line kind rel n=0 p dest
  local files="" backups="" skills="" dirs="" wc
  if command -v systemctl >/dev/null 2>&1; then
    systemctl --user stop omp-plugins-install.service >/dev/null 2>&1 || true
  fi

  if [ -f "$manifest" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
      n=$((n + 1))
      if [[ $line != *" "* ]]; then
        printf 'vm-sync-remote: refused manifest line %s\n' "$n" >&2
        rc=1
        continue
      fi
      kind=${line%% *}
      rel=${line#* }
      case $kind in
        file | backup | dir)
          if valid_rel "$rel"; then
            case $kind in
              file) files=$files$rel$'\n' ;;
              backup)
                if [[ $rel == *.dotfiles-backup ]]; then
                  backups=$backups$rel$'\n'
                else
                  printf 'vm-sync-remote: refused manifest line %s\n' "$n" >&2
                  rc=1
                fi
                ;;
              dir) dirs=$dirs$rel$'\n' ;;
            esac
          else
            printf 'vm-sync-remote: refused manifest line %s\n' "$n" >&2
            rc=1
          fi
          ;;
        skill)
          if valid_name "$rel"; then
            skills=$skills$rel$'\n'
          else
            printf 'vm-sync-remote: refused manifest line %s\n' "$n" >&2
            rc=1
          fi
          ;;
        *)
          printf 'vm-sync-remote: refused manifest line %s\n' "$n" >&2
          rc=1
          ;;
      esac
    done <"$manifest"

    while IFS= read -r rel; do
      [ -n "$rel" ] || continue
      p=$HOME/$rel
      if ! parent_is_plain "$rel"; then
        printf 'vm-sync-remote: refused: a directory above ~/%s is a link\n' "$rel" >&2
        rc=1
      elif [ -d "$p" ] && [ ! -L "$p" ]; then
        printf 'vm-sync-remote: refused: ~/%s is a directory, not a file\n' "$rel" >&2
        rc=1
      elif [ -e "$p" ] || [ -L "$p" ]; then
        rm -f -- "$p" && removed=$((removed + 1))
      fi
    done <<<"$files"

    while IFS= read -r rel; do
      [ -n "$rel" ] || continue
      p=$HOME/$rel
      dest=${p%.dotfiles-backup}
      if ! parent_is_plain "$rel"; then
        rc=1
      elif [ -e "$p" ] || [ -L "$p" ]; then
        mv -f -- "$p" "$dest" && removed=$((removed + 1))
      fi
    done <<<"$backups"

    while IFS= read -r rel; do
      [ -n "$rel" ] || continue
      p=$HOME/.omp/agent/skills/$rel
      if ! parent_is_plain ".omp/agent/skills/$rel"; then
        printf 'vm-sync-remote: refused: a directory above ~/.omp/agent/skills/%s is a link\n' "$rel" >&2
        rc=1
      elif [ -L "$p" ]; then
        rm -f -- "$p" && removed=$((removed + 1))
      elif [ -d "$p" ]; then
        rm -rf -- "$p" && removed=$((removed + 1))
      fi
    done <<<"$skills"

    # Directories the sync made, deepest first, only while empty.
    while IFS= read -r rel; do
      [ -n "$rel" ] || continue
      p=$HOME/$rel
      if parent_is_plain "$rel" && [ -d "$p" ] && [ ! -L "$p" ]; then
        rmdir -- "$p" 2>/dev/null && removed=$((removed + 1))
      fi
    done < <(printf '%s' "$dirs" | awk '{ print length($0) "\t" $0 }' | sort -rn | cut -f2-)
  fi

  # The plugin install: placed by the Home Manager activation, recognised by its record of
  # package.json. A link in place of the directory is left alone.
  wc=$state_root/writable-copy/${HOME//\//_}_.omp_plugins_
  if [ -f "${wc}package.json" ]; then
    if [ -L "$HOME/.omp/plugins" ]; then
      echo "vm-sync-remote: ~/.omp/plugins is a link, left alone" >&2
    elif [ -d "$HOME/.omp/plugins" ] && parent_is_plain ".omp/plugins"; then
      rm -rf -- "$HOME/.omp/plugins" && removed=$((removed + 1))
    fi
    rm -f -- "${wc}package.json" "${wc}bun.lock" "${wc}omp-plugins.lock.json" "$state_root/omp-plugins.stamp"
  fi

  if [ "$rc" -eq 0 ]; then
    rm -f -- "$manifest"
    rmdir "$state_dir" 2>/dev/null || true
  fi
  if [ "$removed" -eq 0 ] && [ "$rc" -eq 0 ]; then
    echo "unsync: nothing to remove"
  else
    echo "unsync: removed $removed item(s)"
  fi
  return "$rc"
}

[ $# -ge 1 ] || die 2 "usage: vm-sync-remote.sh hindsight | hindsight-remove NAME | skills-prepare NAME... | plugins-status | unsync"
sub=$1
shift
case $sub in
  hindsight) cmd_hindsight ;;
  hindsight-remove) cmd_hindsight_remove "$@" ;;
  skills-prepare) cmd_skills_prepare "$@" ;;
  plugins-status) cmd_plugins_status ;;
  unsync) cmd_unsync ;;
  *) die 2 "unknown subcommand: $(printf '%q' "$sub")" ;;
esac
