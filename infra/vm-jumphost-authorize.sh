#!/usr/bin/env bash
# Let the agent VM's own jumphost key reach the jumphost's Docker API, and nothing else. The justfile recipe `vm-jumphost-authorize` calls it.
# Arguments: <name> <repo-root>. Runs on the Mac.
#   1. The VM (role agent, jumphost piece deployed) made ~/.ssh/id_ed25519_jumphost on itself (home/linux/ssh-key.sh). Only its PUBLIC half is
#      read here, over ssh, with the host key already pinned (as vm-sync does). The private key never leaves the VM.
#   2. The public key must be one ssh-ed25519 line of the right length; anything else is refused here, before the jumphost is contacted.
#      Its comment is not taken from the VM: it is built here from the VM name (`<name> docker-jumphost`), so a VM cannot pick the text
#      that names its line (the revocation key). The file is read bounded (a regular file, at most 2048 bytes).
#   3. The line `restrict,command="docker system dial-stdio" ssh-ed25519 <key> <comment>` is appended to the jumphost's authorized_keys
#      over the Mac's own access (the Mac's ssh config entry Host jumphost_server), once, after a timestamped backup, atomically, and without
#      touching any other line (infra/vm-jumphost-authorize-remote.sh). `restrict` takes away the shell, the pty, every forwarding and the
#      agent; the forced command leaves only the Docker API of that host, as the user of the account.
# Revoke: README, "Jumphost".
set -euo pipefail

if [ $# -ne 2 ]; then
  echo "usage: vm-jumphost-authorize.sh <name> <repo-root>" >&2
  exit 2
fi
name=$1
repo=$2

jh_die() {
  printf 'vm-jumphost-authorize: %s\n' "$1" >&2
  exit 1
}
[[ $name =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,62}$ ]] || jh_die "not a valid VM name (letters, digits, dots, dashes and underscores)"

# shellcheck source=vm-sync-lib.sh
. "$repo/infra/vm-sync-lib.sh"

jh_host=${JUMPHOST_SSH_HOST:-jumphost_server}
pubfile='~/.ssh/id_ed25519_jumphost.pub'

ip=$(under_secretspec "$repo" "$name" vm-ip.sh)
config=$(under_secretspec "$repo" "$name" vm-config.sh)
[ -n "$ip" ] && [ -n "$config" ] || jh_die "no address or no configuration for $name"
[ "$config" = proxmox-agent ] || jh_die "$name has the clean role (.#$config): it has no agent user and no jumphost key"

case $(sync_host_key_state "$ip" "$sync_user") in
  pinned) ;;
  unpinned | changed) sync_die_host_key "$name" "$ip" ;;
  *) jh_die "cannot log in to $name as $sync_user (is the VM up and unlocked?)" ;;
esac

pub=$(ssh "${sync_ssh_opts[@]}" "$sync_user@$ip" "test -f $pubfile && head -c 2048 $pubfile") ||
  jh_die "cannot read $pubfile on $name: deploy the agent role with the jumphost option on first (just vm-deploy $name)"

# exactly one line, ssh-ed25519, a key blob of the right length and shape
[ "$(printf '%s' "$pub" | grep -c '')" -eq 1 ] || jh_die "the public key file of $name is not exactly one line: refusing"
oneline=$(printf '%s' "$pub" | tr -d '\r')
read -r ktype kblob vmcomment <<<"$oneline"
[ "${ktype:-}" = ssh-ed25519 ] || jh_die "the key of $name is not an ssh-ed25519 key: refusing"
[[ ${kblob:-} =~ ^[A-Za-z0-9+/]{68}$ ]] || jh_die "the key of $name is malformed (wrong length or characters): refusing"
hex=$(printf '%s' "$kblob" | base64 -d 2>/dev/null | od -An -v -tx1 | tr -d ' \n')
# 00000b "ssh-ed25519" 000020 + 32 bytes
[[ $hex =~ ^0000000b7373682d6564323535313900000020[0-9a-f]{64}$ ]] || jh_die "the key of $name is malformed (not an ed25519 public key blob): refusing"
kcomment="$name docker-jumphost" # the comment that the VM wrote (vmcomment) is not used

line="restrict,command=\"docker system dial-stdio\" ssh-ed25519 $kblob $kcomment"
fp=$(printf '%s\n' "ssh-ed25519 $kblob" | ssh-keygen -l -f - 2>/dev/null | awk '{print $2}') || fp=
echo "vm-jumphost-authorize: key of $name${fp:+ ($fp)} -> $jh_host, restricted to docker system dial-stdio"

b64script=$(base64 <"$repo/infra/vm-jumphost-authorize-remote.sh" | tr -d '\n') || jh_die "cannot read infra/vm-jumphost-authorize-remote.sh"
b64line=$(printf '%s' "$line" | base64 | tr -d '\n')
cmd='d=$(mktemp -d) && trap '"'"'rm -rf "$d"'"'"' EXIT && printf %s '"'$b64script'"' | base64 -d >"$d/r.sh" && bash "$d/r.sh" '"'$b64line'"
rc=0
ssh -o BatchMode=yes -o ConnectTimeout=10 "$jh_host" "$cmd" || rc=$?
case $rc in
  0) ;;
  255) jh_die "cannot reach $jh_host with the Mac's own ssh access: nothing was changed" ;;
  *) jh_die "the jumphost refused or failed (status $rc, see above): nothing was changed" ;;
esac
