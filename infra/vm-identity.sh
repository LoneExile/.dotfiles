# shellcheck shell=bash
# The identity of a NixOS VM, as files. Sourced by vm-install.sh, which defines die().
# NixOS runs no cloud-init: its hostname, address, gateway and resolvers are written once, at
# install, into the tree that nixos-anywhere copies to the new system (--extra-files).
# Values come from TF_VAR_vms. They are checked here first, because they end up inside a
# systemd unit file: a newline or a stray character must not be able to add a setting.
# Messages name the field, never the value.

_octet='(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])'
_ipv4="^${_octet}(\\.${_octet}){3}\$"
_cidr="^${_octet}(\\.${_octet}){3}/(3[0-2]|[12]?[0-9])\$"

# identity_validate NAME MAC CIDR GATEWAY [RESOLVER...]
identity_validate() {
  local name=$1 mac=$2 cidr=$3 gateway=$4 r
  shift 4
  [[ $name =~ ^[a-z0-9][a-z0-9-]{2,61}[a-z0-9]$ ]] || die "the name is not a DNS label of 4 to 63 characters (lowercase letters, digits, hyphens)"
  [[ $mac =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]] || die "the mac is not a MAC address"
  [[ $cidr =~ $_cidr ]] || die "the ipv4_cidr is not <ipv4>/<prefix>"
  [[ $gateway =~ $_ipv4 ]] || die "the gateway is not an IPv4 address"
  for r in "$@"; do
    [[ $r =~ ^[0-9A-Fa-f:.]+$ ]] || die "a resolver is not an IP address"
  done
}

# identity_write DIR NAME MAC CIDR GATEWAY [RESOLVER...]
# Writes DIR/etc/hostname and DIR/etc/systemd/network/10-static.network, both mode 0644 (networkd
# reads its files as an unprivileged user), in directories of mode 0755. Matching by MAC makes the
# NIC's name irrelevant. NixOS never touches /etc/hostname while networking.hostName is empty,
# and never touches /etc/systemd/network while the role defines no networkd unit.
identity_write() {
  local dir=$1 name=$2 mac=$3 cidr=$4 gateway=$5 r d
  shift 5
  identity_validate "$name" "$mac" "$cidr" "$gateway" "$@"
  for d in "$dir" "$dir/etc" "$dir/etc/systemd" "$dir/etc/systemd/network"; do
    mkdir -p "$d"
    chmod 755 "$d"
  done
  printf '%s\n' "$name" >"$dir/etc/hostname"
  chmod 644 "$dir/etc/hostname"
  {
    printf '[Match]\nMACAddress=%s\n\n[Network]\nAddress=%s\nGateway=%s\n' "$mac" "$cidr" "$gateway"
    for r in "$@"; do
      printf 'DNS=%s\n' "$r"
    done
  } >"$dir/etc/systemd/network/10-static.network"
  chmod 644 "$dir/etc/systemd/network/10-static.network"
}
