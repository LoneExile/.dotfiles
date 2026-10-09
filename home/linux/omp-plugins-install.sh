#!/usr/bin/env bash
# Install the captured omp plugins: `bun install --frozen-lockfile` in ~/.omp/plugins, only when the
# captured files changed. ExecStart of the user service omp-plugins-install (home/linux/agent.nix).
#
#   omp-plugins-install.sh <sha256 of the captured files>
#
# The argument is the hash of the repo copies of package.json, bun.lock and omp-plugins.lock.json,
# computed by Nix. A stamp (~/.local/state/dotfiles/omp-plugins.stamp) holds the hash of the set
# that was installed last, and is written only after a successful install, so a failed install
# (network, registry) is tried again at the next start. Nothing is installed again while the stamp
# matches and node_modules is there; a missing node_modules is rebuilt. The manifests themselves are
# placed by the Home Manager activation (writable-copy.sh); this script does not touch them.
#
# bun's download cache lives inside the plugins home and is removed after the run, so everything
# the install makes sits under one directory (and a role flip removes it with that directory).
# Needs bun (and node, for the lifecycle scripts of some plugins) on PATH.
set -uo pipefail

die() { # die CODE MESSAGE
  printf 'omp-plugins-install: %s\n' "$2" >&2
  exit "$1"
}

[ $# -eq 1 ] || die 2 "usage: omp-plugins-install.sh <sha256 of the captured files>"
want=$1
[[ $want =~ ^[0-9a-f]{64}$ ]] || die 2 "the argument is not a sha256 hash"

plugins=$HOME/.omp/plugins
stamp=${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/omp-plugins.stamp

for f in package.json bun.lock; do
  [ -f "$plugins/$f" ] || die 1 "$plugins/$f is missing (the Home Manager activation places it)"
done

have=$(cat "$stamp" 2>/dev/null || true)
if [ "$have" = "$want" ] && [ -d "$plugins/node_modules" ]; then
  echo "omp-plugins-install: up to date"
  exit 0
fi

cache=$plugins/.bun-cache
rc=0
(cd "$plugins" && BUN_INSTALL_CACHE_DIR=$cache bun install --frozen-lockfile) || rc=$?
rm -rf "$cache"
[ "$rc" -eq 0 ] || die "$rc" "bun install failed with status $rc; the next start tries again"

mkdir -p "$(dirname "$stamp")"
printf '%s\n' "$want" >"$stamp.tmp"
mv -f "$stamp.tmp" "$stamp"
echo "omp-plugins-install: installed"
