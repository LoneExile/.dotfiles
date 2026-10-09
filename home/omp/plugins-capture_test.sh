#!/usr/bin/env bash
# Tests for home/omp/plugins-capture.sh: it copies the omp plugin manifests (package.json, bun.lock,
# omp-plugins.lock.json) out of a plugin home into the repo, and refuses to when they hold anything
# that must not be public or that a Linux VM without private registries could not resolve.
# Fixtures only. Token-shaped values are assembled at run time so that no source line looks like a token.
set -uo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
# shellcheck source=../secretspec/testlib.sh
. "$ROOT/home/secretspec/testlib.sh" || exit 1
CAP=$ROOT/home/omp/plugins-capture.sh

command -v perl >/dev/null || {
  echo "perl not found on PATH" >&2
  exit 2
}

# A plugin home as omp keeps it: bun.lock is JSONC (trailing commas), the lock file lists one
# stale plugin that is not a dependency and one whose version differs from the installed one.
mkhome() { # mkhome DIR
  local d=$1
  mkdir -p "$d/node_modules/plug-a" "$d/node_modules/plug-b"
  cat >"$d/package.json" <<'EOF'
{
  "name": "omp-plugins",
  "private": true,
  "dependencies": {
    "plug-a": "^1.2.0",
    "@scope/plug-b": "npm:@scope/plug-b@2.0.0",
    "plug-c": "npm:plug-c"
  }
}
EOF
  cat >"$d/bun.lock" <<'EOF'
{
  "lockfileVersion": 1,
  "configVersion": 1,
  "workspaces": {
    "": {
      "name": "omp-plugins",
      "dependencies": {
        "plug-a": "^1.2.0",
        "@scope/plug-b": "npm:@scope/plug-b@2.0.0",
        "plug-c": "npm:plug-c",
      },
    },
  },
  "packages": {
    "plug-a": ["plug-a@1.2.5", "", {}, "sha512-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=="],

    "@scope/plug-b": ["@scope/plug-b@2.0.0", "", { "dependencies": { "dep-x": "^3.0.0" } }, "sha512-BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=="],

    "dep-x": ["dep-x@3.1.0", "", {}, "sha512-CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC=="],

    "plug-c": ["plug-c@0.3.1", "", {}, "sha512-DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD=="],
  }
}
EOF
  cat >"$d/omp-plugins.lock.json" <<'EOF'
{
  "plugins": {
    "plug-a": { "version": "1.2.0", "enabledFeatures": null, "enabled": true },
    "@scope/plug-b": { "version": "2.0.0", "enabledFeatures": null, "enabled": false },
    "plug-c": { "version": "0.3.1", "enabledFeatures": null, "enabled": true },
    "stale-one": { "version": "0.1.0", "enabledFeatures": null, "enabled": true },
    "@stale/two": { "version": "9.9.9", "enabledFeatures": null, "enabled": true }
  },
  "settings": {}
}
EOF
  printf '{"version":"1.2.5"}\n' >"$d/node_modules/plug-a/package.json"
  mkdir -p "$d/node_modules/@scope/plug-b"
  printf '{"version":"2.0.0"}\n' >"$d/node_modules/@scope/plug-b/package.json"
  # plug-c is not installed on disk: its lock version stays as it is.
  rm -rf "$d/node_modules/plug-b"
}

cap() { bash "$CAP" "$@" >"$T/out" 2>"$T/err"; echo $?; }
# listing DIR: the names in DIR, sorted, one line.
listing() { (cd "$1" && ls -A | LC_ALL=C sort | tr '\n' ' '); }
# tok KIND: a token-shaped string, assembled here so that no line of this file holds one.
tok() {
  local a b
  case $1 in
    ghp) a=gh; b=p_; printf '%s%s%s' "$a" "$b" "0123456789abcdefghijklmnopqrstuvwxyzAB" ;;
    pat) a=github; b=_pat_; printf '%s%s%s' "$a" "$b" "11ABCDEFG0123456789abcdefghijklmnopqrstuv" ;;
    npm) a=np; b=m_; printf '%s%s%s' "$a" "$b" "0123456789abcdefghijklmnopqrstuvwxyz" ;;
    auth) a=_auth; b=Token; printf '%s%s' "$a" "$b" ;;
    bearer) printf '%s %s' "Bear""er" "abcdef0123456789" ;;
    sk) a=s; b=k-; printf '%s%s%s' "$a" "$b" "abcdefghijklmnopqrstuvwxyz0123" ;;
    aws) a=AK; b=IA; printf '%s%s%s' "$a" "$b" "ABCDEFGHIJKLMNOP" ;;
    pem) printf '%s' "-----BEGIN ""PRIVATE KEY-----" ;;
  esac
}

test_captures_the_three_files() {
  mkhome "$T/src"
  assert_rc "capture" "$(cap "$T/src" "$T/dest")" 0
  assert_eq "exactly the three files" "bun.lock omp-plugins.lock.json package.json " "$(listing "$T/dest")"
  assert_eq "package.json is byte-identical" "$(shasum -a 256 <"$T/src/package.json")" "$(shasum -a 256 <"$T/dest/package.json")"
  assert_eq "bun.lock is byte-identical" "$(shasum -a 256 <"$T/src/bun.lock")" "$(shasum -a 256 <"$T/dest/bun.lock")"
  assert_eq "files are 644" "644 644 644" "$(tl_mode "$T/dest/package.json") $(tl_mode "$T/dest/bun.lock") $(tl_mode "$T/dest/omp-plugins.lock.json")"
  assert_has "says it captured" "$T/out" "captured"
}

test_drops_lock_entries_that_are_not_dependencies() {
  mkhome "$T/src"
  assert_rc "capture" "$(cap "$T/src" "$T/dest")" 0
  assert_eq "kept: the dependencies, in the lock's order" "plug-a @scope/plug-b plug-c" "$(jq -r '.plugins | keys_unsorted | join(" ")' "$T/dest/omp-plugins.lock.json")"
  assert_has "names the first dropped entry" "$T/out" "dropped stale lock entry: stale-one"
  assert_has "names the second dropped entry" "$T/out" "dropped stale lock entry: @stale/two"
  assert_eq "enabled state is kept" "false" "$(jq -r '.plugins["@scope/plug-b"].enabled' "$T/dest/omp-plugins.lock.json")"
  assert_eq "settings are kept" "{}" "$(jq -c '.settings' "$T/dest/omp-plugins.lock.json")"
}

test_aligns_a_lock_version_with_the_installed_one() {
  mkhome "$T/src"
  assert_rc "capture" "$(cap "$T/src" "$T/dest")" 0
  assert_eq "drifted version follows the disk" "1.2.5" "$(jq -r '.plugins["plug-a"].version' "$T/dest/omp-plugins.lock.json")"
  assert_has "says so" "$T/out" "aligned lock version of plug-a: 1.2.0 -> 1.2.5"
  assert_eq "an equal version stays" "2.0.0" "$(jq -r '.plugins["@scope/plug-b"].version' "$T/dest/omp-plugins.lock.json")"
  assert_eq "a plugin that is not on disk keeps its version" "0.3.1" "$(jq -r '.plugins["plug-c"].version' "$T/dest/omp-plugins.lock.json")"
}

test_a_second_run_changes_nothing_and_replaces_older_copies() {
  mkhome "$T/src"
  mkdir -p "$T/dest"
  printf 'old' >"$T/dest/package.json"
  assert_rc "first" "$(cap "$T/src" "$T/dest")" 0
  local before
  before=$(cat "$T/dest/package.json" "$T/dest/bun.lock" "$T/dest/omp-plugins.lock.json" | shasum -a 256)
  assert_rc "second" "$(cap "$T/src" "$T/dest")" 0
  assert_eq "same bytes" "$before" "$(cat "$T/dest/package.json" "$T/dest/bun.lock" "$T/dest/omp-plugins.lock.json" | shasum -a 256)"
  assert_eq "the old copy is gone" "omp-plugins" "$(jq -r .name "$T/dest/package.json")"
}

test_no_file_of_dest_is_touched_when_a_check_fails() {
  mkhome "$T/src"
  mkdir -p "$T/dest"
  printf 'previous package' >"$T/dest/package.json"
  printf 'previous lock' >"$T/dest/bun.lock"
  printf 'plug-a@file:../x' >>"$T/src/bun.lock"
  assert_rc "rejected" "$(cap "$T/src" "$T/dest")" 1
  assert_eq "package.json untouched" "previous package" "$(cat "$T/dest/package.json")"
  assert_eq "bun.lock untouched" "previous lock" "$(cat "$T/dest/bun.lock")"
  assert_eq "nothing else appeared" "bun.lock package.json " "$(listing "$T/dest")"
}

# reject_case LABEL FILE APPEND-TEXT KIND: append the text to FILE of a good home; the capture
# must fail with exit 1, name the file and the kind, never print the offending text, write no dest.
reject_case() {
  local label=$1 file=$2 text=$3 kind=$4
  rm -rf "$T/src" "$T/dest"
  mkhome "$T/src"
  printf '%s\n' "$text" >>"$T/src/$file"
  assert_rc "$label: rejected" "$(cap "$T/src" "$T/dest")" 1
  assert_has "$label: names the file" "$T/err" "$file"
  assert_has "$label: names the kind" "$T/err" "$kind"
  assert_lacks "$label: stderr hides the text" "$T/err" "$text"
  assert_lacks "$label: stdout hides the text" "$T/out" "$text"
  assert_absent "$label: dest not created" "$T/dest"
}

test_rejects_local_and_remote_sources_in_bun_lock() {
  reject_case "file:" bun.lock '"x": ["x@file:../local", "", {}, "sha512-A"],' "local or non-registry source"
  reject_case "link:" bun.lock '"x": ["x@link:../local", "", {}, "sha512-A"],' "local or non-registry source"
  reject_case "workspace:" bun.lock '"x": ["x@workspace:packages/x", "", {}],' "local or non-registry source"
  reject_case "github:" bun.lock '"x": ["x@github:someone/x#abc", "", {}],' "local or non-registry source"
  reject_case "git+" bun.lock '"x": ["x@git+https://example.org/x.git", "", {}],' "local or non-registry source"
  reject_case "scp-style git remote" package.json '"note": "git@example.org:someone/x.git"' "local or non-registry source"
}

test_rejects_urls() {
  reject_case "a url" bun.lock '"x": ["x@1.0.0", "https://registry.example.org/", {}, "sha512-A"],' "URL"
  reject_case "a ssh url" package.json '// ssh://git@example.org/x.git' "URL"
}

test_rejects_a_registry_other_than_the_default() {
  mkhome "$T/src"
  perl -pi -e 's/"plug-a\@1.2.5", ""/"plug-a\@1.2.5", "my-registry"/' "$T/src/bun.lock"
  assert_rc "rejected" "$(cap "$T/src" "$T/dest")" 1
  assert_has "names bun.lock" "$T/err" "bun.lock"
  assert_has "names the kind" "$T/err" "registry other than the default"
  assert_absent "dest not created" "$T/dest"
}

test_rejects_absolute_paths() {
  # assembled here: `just check` refuses a literal /Users/<name> anywhere in the repo
  reject_case "mac home" package.json "\"note\": \"/Use""rs/someone/dev/x\"" "absolute path"
  reject_case "linux home" omp-plugins.lock.json '"note": "/home/someone/x"' "absolute path"
  reject_case "nix store" bun.lock '"x": ["x@1.0.0", "", {}, "/nix/store/abc-x"],' "absolute path"
  reject_case "tilde" package.json '"note": "~/dev/x"' "absolute path"
  reject_case "windows path" package.json '"note": "C:\\Users\\someone"' "absolute path"
}

test_rejects_a_package_that_is_not_resolved_to_name_at_version() {
  mkhome "$T/src"
  perl -pi -e 's/"plug-a\@1.2.5"/"plug-a"/' "$T/src/bun.lock"
  assert_rc "rejected" "$(cap "$T/src" "$T/dest")" 1
  assert_has "names bun.lock" "$T/err" "bun.lock"
  assert_has "names the kind" "$T/err" "not resolved to name@version"
  assert_absent "dest not created" "$T/dest"
}

test_rejects_token_shapes_in_every_file() {
  local f
  for f in package.json bun.lock omp-plugins.lock.json; do
    reject_case "classic token in $f" "$f" "\"note\": \"$(tok ghp)\"" "token"
    reject_case "fine-grained token in $f" "$f" "\"note\": \"$(tok pat)\"" "token"
  done
  reject_case "npm token" package.json "\"note\": \"$(tok npm)\"" "token"
  reject_case "npm auth line" package.json "\"note\": \"$(tok auth)\"" "token"
  reject_case "bearer header" omp-plugins.lock.json "\"note\": \"$(tok bearer)\"" "token"
  reject_case "sk key" package.json "\"note\": \"$(tok sk)\"" "token"
  reject_case "aws key id" package.json "\"note\": \"$(tok aws)\"" "token"
  reject_case "private key block" bun.lock "$(tok pem)" "token"
}

test_rejects_dependency_specs_that_are_not_registry_specs() {
  local spec
  for spec in 'file:../local' 'link:../x' 'git+ssh://git@example.org/x.git' 'github:someone/x' 'someone/x' 'workspace:*' 'http://example.org/x.tgz' '../x'; do
    rm -rf "$T/src" "$T/dest"
    mkhome "$T/src"
    jq --arg s "$spec" '.dependencies["bad"] = $s' "$T/src/package.json" >"$T/pj" && mv "$T/pj" "$T/src/package.json"
    assert_rc "spec $spec" "$(cap "$T/src" "$T/dest")" 1
    assert_has "names package.json" "$T/err" "package.json"
    assert_absent "dest not created for $spec" "$T/dest"
  done
}

test_accepts_the_registry_spec_forms_omp_writes() {
  local spec
  for spec in '^0.2.2' '1.0.0' '>=1.0.0 <2' '*' 'latest' 'npm:bad' 'npm:bad@1.2.3' 'npm:@s/bad@1.2.3-omp.4' '~3.1'; do
    rm -rf "$T/src" "$T/dest"
    mkhome "$T/src"
    jq --arg s "$spec" '.dependencies["bad"] = $s' "$T/src/package.json" >"$T/pj" && mv "$T/pj" "$T/src/package.json"
    assert_rc "spec $spec" "$(cap "$T/src" "$T/dest")" 0
  done
}

test_rejects_workspaces_other_than_the_root() {
  rm -rf "$T/src" "$T/dest"
  mkhome "$T/src"
  # a second workspace entry
  perl -0pi -e 's/"workspaces": \{/"workspaces": {\n    "packages\/x": { "name": "x" },/' "$T/src/bun.lock"
  assert_rc "second workspace" "$(cap "$T/src" "$T/dest")" 1
  assert_has "names bun.lock" "$T/err" "bun.lock"
  assert_has "names the kind" "$T/err" "workspace"
  assert_absent "dest not created" "$T/dest"
}

test_rejects_unreadable_manifests() {
  mkhome "$T/src"
  printf 'not json' >"$T/src/package.json"
  assert_rc "bad package.json" "$(cap "$T/src" "$T/dest")" 1
  assert_has "names package.json" "$T/err" "package.json"
  mkhome "$T/src"
  printf 'not json' >"$T/src/omp-plugins.lock.json"
  assert_rc "bad lock" "$(cap "$T/src" "$T/dest")" 1
  assert_has "names the lock file" "$T/err" "omp-plugins.lock.json"
  mkhome "$T/src"
  printf '{"packages": 7}' >"$T/src/bun.lock"
  assert_rc "bad bun.lock" "$(cap "$T/src" "$T/dest")" 1
  assert_has "names bun.lock" "$T/err" "bun.lock"
  assert_absent "dest not created" "$T/dest"
}

test_usage_and_missing_inputs_exit_2() {
  mkhome "$T/src"
  assert_rc "no arguments" "$(cap)" 2
  assert_rc "one argument" "$(cap "$T/src")" 2
  rm "$T/src/bun.lock"
  assert_rc "bun.lock missing" "$(cap "$T/src" "$T/dest")" 2
  assert_has "names the file" "$T/err" "bun.lock"
  assert_absent "dest not created" "$T/dest"
  assert_rc "no such directory" "$(cap "$T/nowhere" "$T/dest")" 2
  assert_has "says which directory is missing" "$T/err" "no such directory"
}

# A finding inside a file that parses is what really happens (the other cases append text after the
# JSON, which a parser would refuse too): only the scan stops these.
test_a_finding_inside_valid_json_stops_the_capture() {
  local f
  for f in package.json omp-plugins.lock.json; do
    rm -rf "$T/src" "$T/dest"
    mkhome "$T/src"
    jq --arg v "https://example.org/x" '.homepage = $v' "$T/src/$f" >"$T/j" && mv "$T/j" "$T/src/$f"
    assert_rc "url in $f" "$(cap "$T/src" "$T/dest")" 1
    assert_has "names $f" "$T/err" "$f"
    assert_absent "dest not created for $f" "$T/dest"
  done
  rm -rf "$T/src" "$T/dest"
  mkhome "$T/src"
  jq --arg v "$(tok ghp)" '.settings.note = $v' "$T/src/omp-plugins.lock.json" >"$T/j" && mv "$T/j" "$T/src/omp-plugins.lock.json"
  assert_rc "token in the lock file" "$(cap "$T/src" "$T/dest")" 1
  assert_has "names the kind" "$T/err" "token"
  assert_absent "dest not created" "$T/dest"
}

tl_init_pure
tl_run_all
tl_done
