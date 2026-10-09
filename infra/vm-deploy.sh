#!/usr/bin/env bash
# Deploy the NixOS configuration of a VM's role to the installed VM. Run it from anywhere; the
# justfile recipe `vm-deploy` calls it. Arguments: <name> <repo-root>.
#   address: the state's `vms` output (infra/vm-ip.sh), the VM that is really there
#   role:    the vault's TF_VAR_vms entry (infra/vm-config.sh), because the role changes no
#            resource and so needs no apply before it can be deployed
# Both are read under secretspec. The build then runs outside it: it needs no secret, and its
# processes should not carry the vault's values in their environment.
# The agent role then gets the sync (infra/vm-sync-lib.sh: Hindsight file, skills). A role without the
# agent first has what an earlier sync placed removed from the agent user's home, because the user
# is gone after the switch.
set -euo pipefail

if [ $# -ne 2 ]; then
  echo "usage: vm-deploy.sh <name> <repo-root>" >&2
  exit 2
fi
name=$1
repo=$2
infra=$repo/infra

# shellcheck source=vm-sync-lib.sh
. "$infra/vm-sync-lib.sh"

ip=$(under_secretspec "$repo" "$name" vm-ip.sh)
config=$(under_secretspec "$repo" "$name" vm-config.sh)
if [ -z "$ip" ] || [ -z "$config" ]; then
  echo "vm-deploy: no address or no configuration for $name" >&2
  exit 1
fi

echo "vm-deploy: $name gets .#$config"
cd "$repo"
# Is the VM's host key pinned in known_hosts already? The switch below trusts a new key on first use
# (accept-new, as it always did); the sync never does (strict checking), and it must not send a
# secret over a key that the switch itself has only just pinned. So the answer is taken first.
pin=$(sync_host_key_state "$ip" root)
if [ "$pin" = changed ]; then
  echo "vm-deploy: the host key that $name presents does not match the one pinned in known_hosts: check that the address belongs to $name, then run the re-key step of the README (Reinstall: ssh-keygen -R $ip)" >&2
  exit 1
fi
unsynced=0
if [ "$config" != proxmox-agent ]; then
  if [ "$pin" = unpinned ]; then
    echo "vm-deploy: the host key of $name is not pinned on this Mac, so nothing was synced from here: the removal of synced files is skipped (files that a sync from another Mac, or from before the key was cleared, put into the home of the agent user stay there)" >&2
  else
    (vm_unsync "$name" "$repo" "$ip")
    unsynced=1
  fi
fi
NIX_SSHOPTS="-o StrictHostKeyChecking=accept-new" nix shell --inputs-from . nixpkgs-nixos#nixos-rebuild-ng -c nixos-rebuild-ng switch --flake ".#$config" --target-host "root@$ip" --build-host "root@$ip" || {
  if [ "$unsynced" -eq 1 ]; then
    echo "vm-deploy: the switch failed after what vm-sync placed was removed from the home of the agent user (the Hindsight file, the skills, the plugin install; they were removed, not lost: the Mac and the repo still hold them). Fix the cause, then run: just vm-deploy $name (to stay an agent instead: set the role back to agent first; the deploy then syncs again)" >&2
  fi
  exit 1
}
if [ "$config" = proxmox-agent ]; then
  if [ "$pin" != pinned ]; then
    echo "vm-deploy: $name is deployed, but its host key was not pinned before this deploy (state: $pin; the switch trusts a key on first use), and vm-sync sends secrets only to a key that was pinned already. Check that the address belongs to $name, i.e. the re-key step of the README (Reinstall: ssh-keygen -R $ip, then connect once; the VM's console has no login, so what you check is the address, not a fingerprint), then run: just vm-sync $name" >&2
    exit 1
  fi
  (vm_sync "$name" "$repo" "$ip") || {
    echo "vm-deploy: $name is deployed, but vm-sync failed (see above): fix the cause, then run: just vm-sync $name" >&2
    exit 1
  }
fi
