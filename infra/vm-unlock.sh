#!/usr/bin/env bash
# Unlock a VM that waits for its LUKS passphrase in the initrd (after vm-install, a reboot or a
# restart of the Proxmox host). Run it in the infra unit directory, under secretspec.
# Argument: <name>. Never prints the passphrase: it is read from the environment and written
# to the ssh pipe by a shell builtin, so it is not in any argv and no tty can echo it.
#
# The connection goes to the initrd's sshd (port 2222) and is pinned to the public key that
# vm-install stored in VM_INITRD_HOST_KEYS: a throwaway known_hosts file, strict checking, no
# fallback to other keys. A mismatch aborts; it is never retried.
# The answer goes to systemd's ask-password protocol: the pending query is a file
# /run/systemd/ask-password/ask.* with a Socket= line, and systemd-reply-password sends stdin
# to that socket. The initrd has bash and coreutils only, so the remote part is bash builtins.
set -euo pipefail
umask 077

if [ $# -ne 1 ]; then
  echo "usage: vm-unlock.sh <name>" >&2
  exit 2
fi
name=$1
infra=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
port=2222
timeout=${VM_UNLOCK_TIMEOUT:-300}

die() {
  printf 'vm-unlock: %s\n' "$1" >&2
  exit 1
}

for var in VM_LUKS_KEYS VM_INITRD_HOST_KEYS; do
  [ -n "${!var:-}" ] || die "$var is empty (run it under secretspec: just vm-unlock $name)"
done
pub=$(printf '%s' "$VM_INITRD_HOST_KEYS" | jq -r --arg n "$name" '.[$n] // empty') || die "VM_INITRD_HOST_KEYS is not valid JSON"
[ -n "$pub" ] || die "no initrd host key is pinned for $name (it was not installed with vm-install)"
luks=$(printf '%s' "$VM_LUKS_KEYS" | jq -r --arg n "$name" '.[$n] // empty') || die "VM_LUKS_KEYS is not valid JSON"
[ -n "$luks" ] || die "no LUKS passphrase is stored for $name"

ip=$(bash "$infra/vm-ip.sh" "$name")

work=$(mktemp -d "${TMPDIR:-/tmp}/vm-unlock.XXXXXX")
trap 'rm -rf "$work"' EXIT
printf '[%s]:%s %s\n' "$ip" "$port" "$pub" >"$work/known_hosts"
err=$work/ssh.err

# up PORT: does the VM accept a TCP connection there?
up() { nc -z -w 3 "$ip" "$1" >/dev/null 2>&1; }

# Already running: the initrd's port is closed and the normal sshd answers.
if ! up "$port" && up 22; then
  echo "vm-unlock: $name already answers on port 22; nothing to unlock"
  exit 0
fi

# Runs in the initrd. The query file is read on fd 3, so stdin stays the passphrase that
# systemd-reply-password reads. Exit 3 when no query is pending yet (cryptsetup has not asked).
remote='for f in /run/systemd/ask-password/ask.*; do
  [ -e "$f" ] || continue
  while IFS= read -r l <&3; do
    case $l in Socket=*) exec /bin/systemd-reply-password 1 "${l#Socket=}";; esac
  done 3<"$f"
done
exit 3'

deadline=$((SECONDS + timeout))
unlocked=0
while [ "$SECONDS" -lt "$deadline" ]; do
  rc=0
  printf '%s' "$luks" | ssh -p "$port" -o BatchMode=yes -o ConnectTimeout=5 \
    -o UserKnownHostsFile="$work/known_hosts" -o GlobalKnownHostsFile=/dev/null \
    -o StrictHostKeyChecking=yes -o HostKeyAlgorithms=ssh-ed25519 -o LogLevel=ERROR \
    "root@$ip" "$remote" 2>"$err" || rc=$?
  if [ "$rc" -eq 0 ]; then
    unlocked=1
    break
  fi
  if grep -qiE 'host key verification failed|host identification has changed' "$err"; then
    die "the initrd of $name does not present the pinned host key. Not retrying: check that the address belongs to $name; vm-install pins a new key."
  fi
  if grep -qiE 'permission denied' "$err"; then
    die "the initrd of $name refused this SSH key (permission denied)"
  fi
  sleep 3
done
[ "$unlocked" -eq 1 ] || die "no passphrase prompt answered within ${timeout}s (the VM may be down, still booting, or stuck: qm terminal on its node shows the console)"

echo "vm-unlock: passphrase sent to $name; waiting for it to boot"
while [ "$SECONDS" -lt "$deadline" ]; do
  if up 22; then
    echo "vm-unlock: $name answers on port 22"
    exit 0
  fi
  sleep 3
done
die "$name did not answer on port 22 within ${timeout}s after the unlock (wrong passphrase: the prompt returns on the console)"
