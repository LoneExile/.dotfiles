#!/usr/bin/env bash
# Install NixOS on a fresh Debian VM named in the terragrunt output `vms`.
# Run it in the infra unit directory, under secretspec (the TF_VAR_* values are read from the
# environment). Arguments: <name> <repo-root>. Never prints a secret.
#
# Files that must reach the new system but not the repo or the Nix store go in a 0700
# staging tree that nixos-anywhere copies to the target before the bootloader is installed:
#   /root/.ssh/authorized_keys   root's keys for stage 2 (cloud-init no longer sets keys)
set -euo pipefail
umask 077

if [ $# -ne 2 ]; then
  echo "usage: vm-install.sh <name> <repo-root>" >&2
  exit 2
fi
name=$1
repo=$2
infra=$repo/infra

die() {
  printf 'vm-install: %s\n' "$1" >&2
  exit 1
}

[ -n "${TF_VAR_ssh_authorized_keys:-}" ] || die "TF_VAR_ssh_authorized_keys is empty (run it under secretspec: just vm-install $name)"

ip=$(bash "$infra/vm-ip.sh" "$name")
if ! ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new "debian@$ip" true; then
  echo "error: $name does not accept debian@ — still booting, host key changed (ssh-keygen -R $ip), or already NixOS? use just vm-deploy" >&2
  exit 1
fi

work=$(mktemp -d "${TMPDIR:-/tmp}/vm-install.XXXXXX")
trap 'rm -rf "$work"' EXIT
files=$work/files

# mkdirm MODE DIR: create DIR with an explicit mode (tar carries it to the target; /etc must stay 0755).
mkdirm() {
  mkdir -p "$2"
  chmod "$1" "$2"
}
mkdirm 755 "$files"
mkdirm 700 "$files/root"
mkdirm 700 "$files/root/.ssh"

printf '%s\n' "$(printf '%s' "$TF_VAR_ssh_authorized_keys")" >"$files/root/.ssh/authorized_keys"
ssh-keygen -l -f "$files/root/.ssh/authorized_keys" >/dev/null || die "TF_VAR_ssh_authorized_keys holds no valid SSH public key"

# macOS tar would add AppleDouble (._*) entries for files with extended attributes.
export COPYFILE_DISABLE=1
nix run --inputs-from "$repo" nixos-anywhere -- \
  --flake "$repo#proxmox-guest" --build-on remote \
  --extra-files "$files" \
  --target-host "debian@$ip"
ssh-keygen -R "$ip"
