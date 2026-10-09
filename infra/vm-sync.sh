#!/usr/bin/env bash
# Sync the Hindsight URL and key and the skills of this Mac to the agent user of a VM (role agent only). The
# justfile recipe `vm-sync` calls it; vm-deploy runs the same steps after an agent deploy.
# Arguments: <name> <repo-root>. What it does and does not do: see infra/vm-sync-lib.sh.
#   address: the state's `vms` output (infra/vm-ip.sh); role: the vault's TF_VAR_vms (infra/vm-config.sh)
set -euo pipefail

if [ $# -ne 2 ]; then
  echo "usage: vm-sync.sh <name> <repo-root>" >&2
  exit 2
fi
name=$1
repo=$2

# shellcheck source=vm-sync-lib.sh
. "$repo/infra/vm-sync-lib.sh"

ip=$(under_secretspec "$repo" "$name" vm-ip.sh)
config=$(under_secretspec "$repo" "$name" vm-config.sh)
if [ -z "$ip" ] || [ -z "$config" ]; then
  echo "vm-sync: no address or no configuration for $name" >&2
  exit 1
fi
if [ "$config" != proxmox-agent ]; then
  echo "vm-sync: $name has the clean role (.#$config): there is no agent user to sync to" >&2
  exit 1
fi

vm_sync "$name" "$repo" "$ip"
