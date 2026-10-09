#!/usr/bin/env bash
# Print the Hindsight URL and API key of one VM, read from the vault map VM_HINDSIGHT (a JSON object,
# VM name -> {"url": ..., "token": ...}; the public Hindsight API that the VM's omp uses and the key
# made for that VM, stored by hand, see the README). Prints two lines, the URL and then the key. Prints
# nothing and exits 0 when the VM has no entry (or the entry is null), so a caller can remove the file.
# Run it where `secretspec get` works (SECRETSPEC_FILE and SECRETSPEC_REASON set, see vm-sync-lib.sh).
# Argument: <name>. Exit 1 with a message that names the vault key and never a value; 2 on usage.
set -uo pipefail

if [ $# -ne 1 ]; then
  echo "usage: vm-hindsight-entry.sh <name>" >&2
  exit 2
fi
name=$1

die() {
  printf 'vm-hindsight-entry: %s\n' "$1" >&2
  exit 1
}

map=$(secretspec get VM_HINDSIGHT) || die "cannot read VM_HINDSIGHT from the vault"
printf '%s' "$map" | jq -e 'type == "object"' >/dev/null 2>&1 ||
  die 'VM_HINDSIGHT in the vault is not a JSON object (store {"<name>": {"url": "...", "token": "..."}}; {} means no entry yet)'

kind=$(printf '%s' "$map" | jq -r --arg n "$name" '.[$n] | type' 2>/dev/null) || die "cannot read the entry of $name in VM_HINDSIGHT"
[ "$kind" != null ] || exit 0
[ "$kind" = object ] || die "the entry of $name in VM_HINDSIGHT is not an object with a url and a token"

url=$(printf '%s' "$map" | jq -r --arg n "$name" '.[$n].url | if type == "string" then . else "" end' 2>/dev/null) || die "cannot read the entry of $name in VM_HINDSIGHT"
key=$(printf '%s' "$map" | jq -r --arg n "$name" '.[$n].token | if type == "string" then . else "" end' 2>/dev/null) || die "cannot read the entry of $name in VM_HINDSIGHT"
[[ $url =~ ^https://[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?(:[0-9]{1,5})?(/[A-Za-z0-9._/-]*)?$ ]] ||
  die "the url of $name in VM_HINDSIGHT is missing or has an unexpected shape (https://host[:port][/path])"
[[ $key =~ ^[A-Za-z0-9_-]{20,255}$ ]] ||
  die "the token of $name in VM_HINDSIGHT is missing or has an unexpected shape (20 to 255 letters, digits, underscores or dashes)"
printf '%s\n%s\n' "$url" "$key"
