#!/usr/bin/env bash
# Print the GitHub token of one VM, read from the vault map VM_GH_TOKENS (a JSON object, VM name ->
# token; one dedicated fine-grained token per VM, stored by hand, see the README). Prints nothing
# and exits 0 when the VM has no entry (or the entry is empty or null), so a caller can skip.
# Run it where `secretspec get` works (SECRETSPEC_FILE and SECRETSPEC_REASON set, see vm-sync-lib.sh).
# Argument: <name>. Exit 1 with a message that names the vault key and never a value; 2 on usage.
set -uo pipefail

if [ $# -ne 1 ]; then
  echo "usage: vm-gh-token.sh <name>" >&2
  exit 2
fi
name=$1

die() {
  printf 'vm-gh-token: %s\n' "$1" >&2
  exit 1
}

map=$(secretspec get VM_GH_TOKENS) || die "cannot read VM_GH_TOKENS from the vault"
printf '%s' "$map" | jq -e 'type == "object"' >/dev/null 2>&1 ||
  die 'VM_GH_TOKENS in the vault is not a JSON object (store {"<name>": "<token>"}; {} means no token yet)'

kind=$(printf '%s' "$map" | jq -r --arg n "$name" '.[$n] | type' 2>/dev/null) || die "cannot read the entry of $name in VM_GH_TOKENS"
[ "$kind" != null ] || exit 0
[ "$kind" = string ] || die "the entry of $name in VM_GH_TOKENS is not a string"

value=$(printf '%s' "$map" | jq -r --arg n "$name" '.[$n]' 2>/dev/null) || die "cannot read the entry of $name in VM_GH_TOKENS"
[ -n "$value" ] || exit 0
[[ $value =~ ^[A-Za-z0-9_]{20,255}$ ]] ||
  die "the token of $name in VM_GH_TOKENS has an unexpected shape (one line of 20 to 255 letters, digits or underscores)"
printf '%s\n' "$value"
