#!/usr/bin/env bash
# Deploy the NixOS configuration of a VM's role to the installed VM. Run it from anywhere; the
# justfile recipe `vm-deploy` calls it. Arguments: <name> <repo-root>.
#   address: the state's `vms` output (infra/vm-ip.sh), the VM that is really there
#   role:    the vault's TF_VAR_vms entry (infra/vm-config.sh), because the role changes no
#            resource and so needs no apply before it can be deployed
# Both are read under secretspec. The build then runs outside it: it needs no secret, and its
# processes should not carry the vault's values in their environment.
set -euo pipefail

if [ $# -ne 2 ]; then
  echo "usage: vm-deploy.sh <name> <repo-root>" >&2
  exit 2
fi
name=$1
repo=$2
infra=$repo/infra

# under_secretspec SCRIPT: run an infra script in the Terragrunt unit with the vault's values.
under_secretspec() {
  (cd "$infra/proxmox/vms" && SECRETSPEC_FILE="$infra/secretspec.toml" SECRETSPEC_REASON="dotfiles infra" secretspec run -- bash "$infra/$1" "$name")
}

ip=$(under_secretspec vm-ip.sh)
config=$(under_secretspec vm-config.sh)
if [ -z "$ip" ] || [ -z "$config" ]; then
  echo "vm-deploy: no address or no configuration for $name" >&2
  exit 1
fi

echo "vm-deploy: $name gets .#$config"
cd "$repo"
NIX_SSHOPTS="-o StrictHostKeyChecking=accept-new" nix shell --inputs-from . nixpkgs-nixos#nixos-rebuild-ng -c nixos-rebuild-ng switch --flake ".#$config" --target-host "root@$ip" --build-host "root@$ip"
