#!/usr/bin/env bash
# Print the IPv4 of the named VM from the terragrunt output `vms`.
# Run it in the infra unit, under secretspec. Any failure (no state, unknown
# name, missing ip) takes the one error path and exits 1, so callers never
# start ssh or nix with an empty or "null" address.
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
  fail
  echo "terragrunt output failed:" >&2
  grep -v '^[[:space:]]*$' "$err" | tail -n 5 >&2
  exit 1
fi

ip=$(jq -er --arg n "$name" '.[$n].ip // empty' <<<"$out") || { fail; exit 1; }
printf '%s\n' "$ip"
