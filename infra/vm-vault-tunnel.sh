#!/usr/bin/env bash
# Forward TCP 8250 of this Mac to TCP 8250 of the agent VM, for the browser step of an OIDC login that runs on the VM. The justfile recipe
# `vm-vault-tunnel` calls it. Arguments: <name> <repo-root>. Runs on the Mac, in the foreground, until Ctrl-C.
#   Why: the UnitLLM repo's `just vault-login` runs `bao login -method=oidc`, which listens on localhost:8250 of the machine it runs on and sends the
#   browser to the vault's sign-in page; the vault allows only the redirect http://localhost:8250/oidc/callback. The VM has no browser and the Mac's
#   browser cannot reach the VM's loopback, so this forwards the Mac's port to the VM's: the sign-in finishes in the Mac's browser, and the callback
#   reaches the bao that waits on the VM. The sign-in itself, and the token it makes, are never seen here: this script only carries the bytes.
#   1. The port must be free on this Mac (127.0.0.1 and ::1): a bao login that runs here, or an earlier tunnel, would take the callback. Refused otherwise.
#   2. The address comes from the state's `vms` output and the role from the vault (infra/vm-sync-lib.sh, as in vm-sync); the clean role has no agent user
#      and no bao, and is refused. The address is never printed and never written to a file: it is only in the argument list of ssh.
#   3. ssh runs in the foreground (exec): the exit status is its own, Ctrl-C ends the tunnel. The host key must be pinned already (StrictHostKeyChecking=yes,
#      nothing is written to known_hosts), ExitOnForwardFailure makes a port that cannot be bound a failure, and GatewayPorts=no keeps the local end on the
#      loopback whatever ~/.ssh/config says (so the LAN never reaches the callback listener).
# VM_VAULT_TUNNEL_PORT changes the port (for the tests only: the vault's role allows 8250 and nothing else).
set -euo pipefail

if [ $# -ne 2 ]; then
  echo "usage: vm-vault-tunnel.sh <name> <repo-root>" >&2
  exit 2
fi
name=$1
repo=$2

vt_die() {
  printf 'vm-vault-tunnel: %s\n' "$1" >&2
  exit 1
}
[[ $name =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,62}$ ]] || vt_die "not a valid VM name (letters, digits, dots, dashes and underscores)"
port=${VM_VAULT_TUNNEL_PORT:-8250}
[[ $port =~ ^[1-9][0-9]{0,4}$ ]] && [ "$port" -le 65535 ] || vt_die "not a TCP port: $port"

# vt_listening ADDR PORT: does something accept a TCP connection at this local address? (bash's own /dev/tcp: no other tool is needed.)
vt_listening() { (exec 3<>"/dev/tcp/$1/$2") 2>/dev/null; }
for addr in 127.0.0.1 ::1; do
  if vt_listening "$addr" "$port"; then
    vt_die "TCP $port is already in use on this Mac (something answers on $addr): stop it first (a bao login that runs here, or an earlier tunnel), then run this again"
  fi
done

# shellcheck source=vm-sync-lib.sh
. "$repo/infra/vm-sync-lib.sh"

ip=$(under_secretspec "$repo" "$name" vm-ip.sh)
config=$(under_secretspec "$repo" "$name" vm-config.sh)
[ -n "$ip" ] && [ -n "$config" ] || vt_die "no address or no configuration for $name"
[ "$config" = proxmox-agent ] || vt_die "$name has the clean role (.#$config): it has no agent user and no bao to log in with"

printf 'vm-vault-tunnel: forwarding TCP %s of this Mac to TCP %s of %s until Ctrl-C: run `just vault-login` on the VM (in the UnitLLM repo), then open the URL it prints in this Mac'"'"'s browser\n' "$port" "$port" "$name"
exec ssh "${sync_ssh_opts[@]}" -N -o ExitOnForwardFailure=yes -o GatewayPorts=no -L "$port:localhost:$port" "$sync_user@$ip"
