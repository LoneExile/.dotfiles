#!/usr/bin/env bash
# Install the Mason language servers of home/omp/mason-lsp.txt, for omp. ExecStart of the user service
# mason-lsp-install (home/linux/agent.nix).
#
#   mason-lsp-install.sh <sha256 of the list> <nvim> <init.lua> <package>...
#
# omp starts a language server when its executable is on PATH, and pi-mason-bridge (one of the captured
# omp plugins) puts Mason's bin directory, ~/.local/share/nvim/mason/bin, on omp's PATH. This installs
# what Mason would, with `nvim --headless -u <init.lua> "+MasonInstall <package>" +qa`: in headless mode
# MasonInstall waits until the install is done and makes nvim exit with status 1 when it failed. The
# init file (home/linux/mason-init.lua) loads mason.nvim and nothing else, so no Neovim config of the
# user is read or written.
#
# A stamp (~/.local/state/dotfiles/mason-lsp.stamp) holds the hash of the list that was satisfied last, and
# is written only when every package of the list is there, so a failed run is tried again at the next
# start. Nothing runs while the stamp matches the hash and Mason's packages directory is there (a wiped
# directory is rebuilt, as omp-plugins-install.sh rebuilds a missing node_modules). A run installs only the
# packages that have no receipt yet (<mason>/packages/<name>/mason-receipt.json, written when an install is
# finished), each by its own nvim run, so that one failing or renamed package neither stops nor hides the
# others, and it checks the receipt as well as the exit status of nvim. Nothing is ever uninstalled: a server
# that someone installed by hand stays, so does one that dropped out of the list, and a listed server that
# someone removed by hand is not put back until the list changes.
#
# npm, go, cargo and nvim itself write caches. They go to one work directory under ~/.cache/dotfiles
# (XDG_CONFIG_HOME and XDG_CACHE_HOME too, which also keeps go's telemetry file out of ~/.config) that is
# removed at the end, also after a failure; Mason's own data stays where Neovim keeps it.
# PATH must hold what the installs run (measured, README): curl, gzip, tar, getconf (Mason tells glibc
# from musl with it), node and npm, go, cargo with rustc, a C compiler, git and nix (nil is built from a
# git tag, and its build script runs nix), and a shell with coreutils.
# Exit: 0 everything is there, 1 an install failed, 2 usage.
set -uo pipefail

die() { # die CODE MESSAGE
  printf 'mason-lsp-install: %s\n' "$2" >&2
  exit "$1"
}

[ $# -ge 4 ] || die 2 "usage: mason-lsp-install.sh <sha256 of the list> <nvim> <init.lua> <package>..."
want=$1
nvim=$2
init=$3
shift 3
[[ $want =~ ^[0-9a-f]{64}$ ]] || die 2 "the first argument is not a sha256 hash"
[ -x "$nvim" ] && [ ! -d "$nvim" ] || die 2 "nvim is not an executable file: $nvim"
[ -f "$init" ] || die 2 "the init file is missing: $init"
for name in "$@"; do
  [[ $name =~ ^[a-z0-9][a-z0-9._-]*$ ]] || die 2 "not a plain package name: $(printf '%q' "$name")"
done

mason=${XDG_DATA_HOME:-$HOME/.local/share}/nvim/mason
stamp=${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/mason-lsp.stamp
work=${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles/mason-lsp-install

have=$(cat "$stamp" 2>/dev/null || true)
if [ "$have" = "$want" ] && [ -d "$mason/packages" ]; then
  echo "mason-lsp-install: up to date"
  exit 0
fi

missing=()
for name in "$@"; do
  [ -f "$mason/packages/$name/mason-receipt.json" ] || missing+=("$name")
done

if [ ${#missing[@]} -eq 0 ]; then
  mkdir -p "$(dirname "$stamp")"
  printf '%s\n' "$want" >"$stamp.tmp"
  mv -f "$stamp.tmp" "$stamp"
  echo "mason-lsp-install: up to date"
  exit 0
fi

# go makes its module cache read-only unless told otherwise (-modcacherw below); the chmod makes sure
# that rm gets through whatever a tool left. bash runs the EXIT trap also when systemd stops the service (SIGTERM).
cleanup() {
  chmod -R u+w "$work" 2>/dev/null || true
  rm -rf "$work"
}
trap cleanup EXIT
cleanup
mkdir -p "$work" || die 1 "cannot create $work"
cd "$work" || die 1 "cannot enter $work"
export XDG_CONFIG_HOME=$work/config XDG_CACHE_HOME=$work/cache npm_config_cache=$work/npm GOPATH=$work/go GOFLAGS=-modcacherw CARGO_HOME=$work/cargo

failed=()
for name in "${missing[@]}"; do
  echo "mason-lsp-install: installing $name"
  "$nvim" --headless -u "$init" -i NONE --noplugin "+MasonInstall $name" +qa
  rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "mason-lsp-install: nvim exited with status $rc for $name" >&2
    failed+=("$name")
  elif [ ! -f "$mason/packages/$name/mason-receipt.json" ]; then
    echo "mason-lsp-install: nvim exited with status 0 for $name, but Mason wrote no receipt" >&2
    failed+=("$name")
  fi
done

[ ${#failed[@]} -eq 0 ] || die 1 "failed: ${failed[*]}; the next start tries again"

mkdir -p "$(dirname "$stamp")"
printf '%s\n' "$want" >"$stamp.tmp"
mv -f "$stamp.tmp" "$stamp"
echo "mason-lsp-install: installed ${missing[*]}"
