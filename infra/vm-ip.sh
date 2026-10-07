#!/usr/bin/env bash
# Print the IPv4 of the named VM from the terragrunt output `vms`.
# Run it in the infra unit, under secretspec. Two failure kinds, both exit 1,
# so callers never start ssh or nix with an empty or "null" address:
#   - the VM list cannot be read from the state (store unreachable, lock held,
#     vault login or passphrase wrong): says so and shows what terragrunt said;
#   - the list is read but has no such name, or no ip: "no VM named" line.
set -uo pipefail

if [ $# -ne 1 ]; then
  echo "usage: vm-ip.sh <name>" >&2
  exit 2
fi
name=$1

err=$(mktemp)
trap 'rm -f "$err"' EXIT

fail() {
  echo "error: no VM named $name in terragrunt output (check TF_VAR_vms, then just infra-apply)" >&2
}

if ! out=$(terragrunt output -json vms 2>"$err"); then
  echo "error: could not read the VM list from the state (store unreachable, lock held, vault login or passphrase wrong?); terragrunt said:" >&2
  grep -v '^[[:space:]]*$' "$err" | tail -n 5 >&2
  exit 1
fi

ip=$(jq -er --arg n "$name" '.[$n].ip // empty' <<<"$out") || { fail; exit 1; }
printf '%s\n' "$ip"
