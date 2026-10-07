#!/usr/bin/env bash
# Install NixOS (LUKS2 root) on a fresh Debian VM named in the terragrunt output `vms`.
# Run it in the infra unit directory, under secretspec (the secrets come from the environment
# and go back to the vault with `secretspec set`). Arguments: <name> <repo-root>.
# Never prints a secret: values travel through pipes, files in a 0700 temp dir, and the
# environment of a single process, never through argv.
#
# Per VM, in the vault (JSON maps keyed by VM name, so the repo names no VM):
#   VM_LUKS_KEYS          the disk passphrase; generated once, kept across reinstalls
#   VM_INITRD_HOST_KEYS   the public key of the initrd SSH host key; a fresh key pair on every
#                         install, `vm-unlock` pins the connection to it
# Files that must reach the new system but not the repo or the Nix store go in a staging tree
# that nixos-anywhere copies to the target before the bootloader is installed (the bootloader
# step reads them into the initrd, see hosts/nixos/proxmox-guest):
#   /root/.ssh/authorized_keys                    root's keys for stage 2 and for the initrd
#   /etc/secrets/initrd/ssh_host_ed25519_key      the initrd SSH host key
#   /etc/secrets/initrd/10-initrd.network         the initrd's static address
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

# shellcheck source=vault-map.sh
. "$infra/vault-map.sh"

for var in TF_VAR_ssh_authorized_keys TF_VAR_vms VM_LUKS_KEYS VM_INITRD_HOST_KEYS; do
  [ -n "${!var:-}" ] || die "$var is empty (run it under secretspec: just vm-install $name)"
done

ip=$(bash "$infra/vm-ip.sh" "$name")
if ! ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new "debian@$ip" true; then
  echo "error: $name does not accept debian@ — still booting, host key changed (ssh-keygen -R $ip), or already NixOS? use just vm-deploy" >&2
  exit 1
fi

# The VM entry supplies the initrd's static network. Same fields cloud-init gets from Proxmox.
fields=$(printf '%s' "$TF_VAR_vms" | jq -r --arg n "$name" '.[$n] | select(. != null) | [.mac, .ipv4_cidr, .gateway] | @tsv') ||
  die "TF_VAR_vms is not valid JSON"
[ -n "$fields" ] || die "no VM named $name in TF_VAR_vms"
IFS=$'\t' read -r mac cidr gateway <<<"$fields"
[[ $mac =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]] || die "the mac of $name in TF_VAR_vms is not a MAC address"
[[ $cidr =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$ ]] || die "the ipv4_cidr of $name in TF_VAR_vms is not <ipv4>/<prefix>"
[[ $gateway =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "the gateway of $name in TF_VAR_vms is not an IPv4 address"

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
mkdirm 755 "$files/etc"
mkdirm 755 "$files/etc/secrets"
mkdirm 700 "$files/etc/secrets/initrd"

printf '%s\n' "$(printf '%s' "$TF_VAR_ssh_authorized_keys")" >"$files/root/.ssh/authorized_keys"
ssh-keygen -l -f "$files/root/.ssh/authorized_keys" >/dev/null || die "TF_VAR_ssh_authorized_keys holds no valid SSH public key"

# The disk passphrase: stored in the vault before anything is formatted, so it cannot be lost.
luks=$(map_get VM_LUKS_KEYS "$name") || die "cannot read VM_LUKS_KEYS from the vault"
if [ -z "$luks" ]; then
  luks=$(openssl rand -hex 32)
  map_put VM_LUKS_KEYS "$name" "$luks"
  echo "vm-install: generated a LUKS passphrase for $name and stored it in the vault (VM_LUKS_KEYS)"
fi
printf '%s' "$luks" >"$work/luks-passphrase"

# A fresh initrd host key for every install. Its public half is pinned in the vault first,
# so a VM that gets installed is never left without a pin.
ssh-keygen -q -t ed25519 -N '' -C '' -f "$files/etc/secrets/initrd/ssh_host_ed25519_key"
pub=$(cut -d ' ' -f 1,2 "$files/etc/secrets/initrd/ssh_host_ed25519_key.pub")
rm -f "$files/etc/secrets/initrd/ssh_host_ed25519_key.pub"
map_put VM_INITRD_HOST_KEYS "$name" "$pub"

# The initrd's static address. Mode 0644: networkd reads its files as the unprivileged user
# systemd-network (measured: with 0600 it fails with "Permission denied" and the initrd has no
# address). The 0700 directory /etc/secrets/initrd keeps other users out of the source copy.
# The role clears the NIC before switch-root, so stage 2 gets its network from cloud-init.
cat >"$files/etc/secrets/initrd/10-initrd.network" <<EOF
[Match]
MACAddress=$mac

[Network]
Address=$cidr
Gateway=$gateway
EOF
chmod 644 "$files/etc/secrets/initrd/10-initrd.network"

# Last look before the disk is formatted: both entries must still be what this run stored.
[ "$(map_get VM_LUKS_KEYS "$name")" = "$luks" ] || die "the LUKS passphrase entry of $name changed in the vault during the run; nothing was formatted"
[ "$(map_get VM_INITRD_HOST_KEYS "$name")" = "$pub" ] || die "the initrd host key entry of $name changed in the vault during the run; nothing was formatted"

# macOS tar would add AppleDouble (._*) entries for files with extended attributes.
export COPYFILE_DISABLE=1
nix run --inputs-from "$repo" nixos-anywhere -- \
  --flake "$repo#proxmox-guest" --build-on remote \
  --disk-encryption-keys /tmp/luks-passphrase "$work/luks-passphrase" \
  --extra-files "$files" \
  --target-host "debian@$ip"
ssh-keygen -R "$ip"
echo "vm-install: $name is installed and waits for its disk passphrase: just vm-unlock $name"
