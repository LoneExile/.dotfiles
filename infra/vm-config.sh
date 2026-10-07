#!/usr/bin/env bash
# Print the flake attribute of the NixOS configuration a VM gets, from its `role` in TF_VAR_vms:
#   clean (the default when the entry has no role)  ->  proxmox-guest
#   agent                                           ->  proxmox-agent
# Run it under secretspec (the vault value is the intent; the state's `vms` output only shows it
# after an apply, and a role changes no resource, so a deploy must not wait for one).
# Argument: <name>. Exit 1 with a message that names the field, never its value; exit 2 on usage.
set -uo pipefail

if [ $# -ne 1 ]; then
  echo "usage: vm-config.sh <name>" >&2
  exit 2
fi
name=$1

die() {
  printf 'vm-config: %s\n' "$1" >&2
  exit 1
}

[ -n "${TF_VAR_vms:-}" ] || die "TF_VAR_vms is empty (run it under secretspec: just vm-deploy $name)"

# A role missing or null is clean, like the optional() default of variables.tf. Anything else
# that is not one of the two strings stops here, and the entry's value never reaches a message.
role=$(printf '%s' "$TF_VAR_vms" | jq -r --arg n "$name" '
  .[$n] | select(. != null)
  | if type != "object" then error("entry")
    elif has("role") and .role != null then .role
    else "clean" end
  | if type == "string" then "role:" + . else error("role") end
' 2>/dev/null) || die "the entry of $name in TF_VAR_vms has an unexpected shape, or its role is not a string"
[ -n "$role" ] || die "no VM named $name in TF_VAR_vms"
role=${role#role:}

case $role in
clean) echo proxmox-guest ;;
agent) echo proxmox-agent ;;
*) die "the role of $name in TF_VAR_vms is not clean or agent" ;;
esac
