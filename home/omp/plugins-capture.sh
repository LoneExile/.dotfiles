#!/usr/bin/env bash
# Capture the omp plugin manifests of this Mac into the repo, for the agent VMs.
#
#   plugins-capture.sh <omp plugin home> <destination directory>
#
# Copies package.json and bun.lock byte for byte, and omp-plugins.lock.json with two changes: the
# entries of plugins that are not dependencies of package.json are dropped (stale: they are not
# installed), and each version is set to the one installed on disk, which is what `omp plugin
# doctor` compares with. node_modules, caches and installed_plugins.json are not captured.
#
# Nothing is written until every check passes. The files end up in a public repository and are
# installed on a machine that has no .npmrc, so a file is refused when it holds
#   - a local or non-registry source (file:, link:, workspace:, git, github: ...),
#   - a URL of any scheme, or a registry other than the default one,
#   - an absolute path of a machine,
#   - a token, key or credential (by shape),
# and package.json must name every dependency as a registry spec. The message names the file and
# the kind of finding and never the text that matched. Needs jq and perl.
#
# Exit: 0 captured, 1 a check failed (nothing written), 2 usage or a missing input.
set -uo pipefail

die() { # die CODE MESSAGE
  printf 'plugins-capture: %s\n' "$2" >&2
  exit "$1"
}

[ $# -eq 2 ] || die 2 "usage: plugins-capture.sh <omp plugin home> <destination directory>"
src=$1
dest=$2
[ -d "$src" ] || die 2 "no such directory: $src"
files=(package.json bun.lock omp-plugins.lock.json)
for f in "${files[@]}"; do
  [ -f "$src/$f" ] && [ -s "$src/$f" ] || die 2 "$f is missing or empty in $src"
done
command -v jq >/dev/null || die 2 "jq not found on PATH"
command -v perl >/dev/null || die 2 "perl not found on PATH"

bad=0
finding() { # finding FILE KIND
  printf 'plugins-capture: %s holds %s\n' "$1" "$2" >&2
  bad=1
}

# Text checks on every file, before any parsing: a file that does not parse still gets its
# findings. grep -E patterns; a character class in front keeps a hit from starting inside a word
# or inside a base64 integrity hash.
scan() { # scan FILE KIND PATTERN
  if grep -Eq -- "$3" "$src/$1"; then finding "$1" "$2"; fi
}
for f in "${files[@]}"; do
  scan "$f" "a local or non-registry source" '(^|[^A-Za-z0-9_])(file|link|workspace|github|gitlab|bitbucket|portal|patch|tarball|git\+[a-z]+|git):'
  scan "$f" "a local or non-registry source" 'git@[A-Za-z]'
  scan "$f" "a URL" '[A-Za-z][A-Za-z0-9+.-]*://'
  scan "$f" "an absolute path" '(^|[^A-Za-z0-9_.@+/=-])(/Users/|/home/|/root/|/nix/|/tmp/|/var/|/opt/|/etc/|/private/)'
  scan "$f" "an absolute path" '(^|[^A-Za-z0-9+/=])~/'
  scan "$f" "an absolute path" '(^|[^A-Za-z0-9])[A-Za-z]:\\'
  scan "$f" "a token or key" 'gh[pousr]_[A-Za-z0-9]{20,}'
  scan "$f" "a token or key" 'github_pat_[A-Za-z0-9_]{20,}'
  scan "$f" "a token or key" '(^|[^A-Za-z0-9])npm_[A-Za-z0-9]{20,}'
  scan "$f" "a token or key" 'glpat-[A-Za-z0-9_-]{15,}'
  scan "$f" "a token or key" '(^|[^A-Za-z0-9-])sk-[A-Za-z0-9_-]{20,}'
  scan "$f" "a token or key" 'AKIA[0-9A-Z]{16}'
  scan "$f" "a token or key" 'xox[abprs]-[A-Za-z0-9-]{10,}'
  scan "$f" "a token or key" '_authToken|_auth=|_password='
  scan "$f" "a token or key" 'Bearer [A-Za-z0-9._-]{8,}'
  scan "$f" "a token or key" '-----BEGIN '
done
[ "$bad" -eq 0 ] || die 1 "refused: nothing was written (see above)"

work=$(mktemp -d "${TMPDIR:-/tmp}/plugins-capture.XXXXXX") || die 2 "cannot create a temporary directory"
trap 'rm -rf "$work"' EXIT

# package.json: an object whose dependencies are registry specs. Accepted: a semver range or tag
# (no ":", "/" or "@"), or npm:<name>[@<range>].
jq -e 'type == "object" and (.dependencies | type) == "object"' "$src/package.json" >/dev/null 2>&1 ||
  die 1 "package.json is not a JSON object with a dependencies object"
badspecs=$(jq -r '
  .dependencies | to_entries[]
  | select((.value | type) != "string"
      or ((.value | test("^npm:(@[A-Za-z0-9._~-]+/)?[A-Za-z0-9._~-]+(@[^:/]+)?$") or test("^[^:/@]*$")) | not))
  | .key' "$src/package.json" 2>/dev/null | wc -l | tr -d ' ')
[ "$badspecs" -eq 0 ] || die 1 "package.json names $badspecs dependencies that are not registry specs"

# bun.lock is JSONC: remove the trailing commas, then read it as JSON. One workspace (the root),
# every package from the default registry, resolved to name@version.
perl -0pe 's/,(\s*[}\]])/$1/g' "$src/bun.lock" >"$work/bun.lock.json"
jq -e '(.packages | type) == "object" and (.workspaces | type) == "object"' "$work/bun.lock.json" >/dev/null 2>&1 ||
  die 1 "bun.lock is not a lockfile with workspaces and packages"
jq -e '.workspaces | keys == [""]' "$work/bun.lock.json" >/dev/null 2>&1 ||
  die 1 "bun.lock holds a workspace other than the root"
if ! jq -e '[.packages[] | select((.[1] // "") != "")] | length == 0' "$work/bun.lock.json" >/dev/null 2>&1; then
  die 1 "bun.lock holds a package from a registry other than the default"
fi
if ! jq -e '[.packages[] | select((.[0] | type) != "string" or ((.[0] | test("^(@[^@/]+/)?[^@/]+@[0-9][^@:/ ]*$")) | not))] | length == 0' "$work/bun.lock.json" >/dev/null 2>&1; then
  die 1 "bun.lock holds a package that is not resolved to name@version"
fi

jq -e '(.plugins | type) == "object"' "$src/omp-plugins.lock.json" >/dev/null 2>&1 ||
  die 1 "omp-plugins.lock.json is not a JSON object with a plugins object"

# The lock file: keep what package.json depends on, set each version to the installed one.
deps=$(jq -c '.dependencies | keys' "$src/package.json")
jq -r --argjson deps "$deps" '.plugins | keys_unsorted[] | select(. as $k | ($deps | index($k)) | not)' "$src/omp-plugins.lock.json" >"$work/dropped"
lock=$(jq --argjson deps "$deps" '.plugins |= with_entries(select(.key as $k | $deps | index($k)))' "$src/omp-plugins.lock.json") ||
  die 1 "omp-plugins.lock.json could not be filtered"
while IFS= read -r name; do
  echo "dropped stale lock entry: $name"
done <"$work/dropped"
while IFS= read -r name; do
  disk_file=$src/node_modules/$name/package.json
  [ -f "$disk_file" ] || continue
  disk=$(jq -r '.version // empty' "$disk_file" 2>/dev/null)
  [ -n "$disk" ] || continue
  have=$(printf '%s' "$lock" | jq -r --arg n "$name" '.plugins[$n].version // empty')
  if [ "$have" != "$disk" ]; then
    lock=$(printf '%s' "$lock" | jq --arg n "$name" --arg v "$disk" '.plugins[$n].version = $v')
    echo "aligned lock version of $name: ${have:-none} -> $disk"
  fi
done < <(printf '%s' "$lock" | jq -r '.plugins | keys_unsorted[]')

mkdir -p "$dest" || die 2 "cannot create $dest"
cp "$src/package.json" "$work/package.json"
cp "$src/bun.lock" "$work/bun.lock"
printf '%s\n' "$lock" >"$work/omp-plugins.lock.json"
for f in "${files[@]}"; do
  install -m 644 "$work/$f" "$dest/$f" || die 2 "cannot write $dest/$f"
done
echo "captured ${files[*]} -> $dest"
