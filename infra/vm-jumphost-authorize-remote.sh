#!/usr/bin/env bash
# The part of vm-jumphost-authorize that runs ON the jumphost, as its user (the Mac sends this file over ssh):
#
#   vm-jumphost-authorize-remote.sh <base64 of one authorized_keys line>
#
# It appends that line to ~/.ssh/authorized_keys, once, and touches nothing else:
#   - the key (its ssh-ed25519 blob) is already there with exactly these options (the comment may differ): "already authorized", nothing changes;
#   - the key is there with other options (it could be unrestricted): refused, exit 1, nothing changes;
#   - otherwise: a timestamped backup of the file (mode 600, `cp -p`), then a new file is written beside it (the old content, a final
#     newline if it lacked one, the new line), checked (the old file is the beginning of the new one, one line longer), set to mode 600
#     and moved over the old one with rename, which is atomic. A missing file is made the same way, without a backup.
#   - authorized_keys a link or no regular file: refused.
# An existing line is never removed, reordered or changed. Exit: 0 done or already there, 1 refused, 2 failed (nothing changed).
set -eu
umask 077

line=$(printf %s "${1:-}" | base64 -d)
blob=$(printf '%s\n' "$line" | awk '{ for (i = 1; i < NF; i++) if ($i == "ssh-ed25519") { print $(i + 1); exit } }')
[ -n "$blob" ] || {
  echo "authorize: no ssh-ed25519 key in the line" >&2
  exit 2
}

# the line must be the restricted form of this key (the Mac builds it so; a line of any other shape is never written here)
prefix="restrict,command=\"docker system dial-stdio\" ssh-ed25519 $blob"
case $line in
  "$prefix "*) ;;
  *)
    echo "authorize: the line is not the restricted form of this key: refusing" >&2
    exit 2
    ;;
esac

dir=$HOME/.ssh
ak=$dir/authorized_keys
[ -d "$dir" ] || mkdir -m 700 "$dir"
if [ -L "$ak" ]; then
  echo "authorize: $ak is a link: refusing to replace it" >&2
  exit 1
fi
if [ -e "$ak" ] && [ ! -f "$ak" ]; then
  echo "authorize: $ak is not a regular file" >&2
  exit 1
fi

bak=
if [ -f "$ak" ]; then
  at=$(awk -v b="$blob" '{ for (i = 1; i < NF; i++) if ($i == "ssh-ed25519" && $(i + 1) == b) { print NR; exit } }' "$ak")
  if [ -n "$at" ]; then
    have=$(sed -n "${at}p" "$ak")
    case $have in
      "$prefix" | "$prefix "*)
        echo "already authorized (line $at of authorized_keys): nothing changed"
        exit 0
        ;;
    esac
    echo "authorize: this key is already in authorized_keys (line $at) with other options than the restricted ones: left as it is, nothing changed" >&2
    exit 1
  fi
  stamp=$(date -u +%Y%m%dT%H%M%SZ)
  bak=$ak.bak-$stamp
  n=0
  while [ -e "$bak" ]; do
    n=$((n + 1))
    bak=$ak.bak-$stamp-$n
  done
  cp -p "$ak" "$bak"
  chmod 600 "$bak"
fi

tmp=$(mktemp "$dir/authorized_keys.new.XXXXXX")
trap 'rm -f "$tmp"' EXIT
if [ -f "$ak" ]; then
  cat "$ak" >"$tmp"
  [ -z "$(tail -c 1 "$ak")" ] || printf '\n' >>"$tmp"
fi
printf '%s\n' "$line" >>"$tmp"
if [ -f "$ak" ]; then
  size=$(wc -c <"$ak" | tr -d ' ')
  head -c "$size" "$tmp" | cmp -s - "$ak" || {
    echo "authorize: the new file does not begin with the old one: nothing was changed (backup ${bak##*/})" >&2
    exit 2
  }
  [ "$(grep -c '' "$tmp")" -eq $(($(grep -c '' "$ak") + 1)) ] || {
    echo "authorize: the new file is not exactly one line longer: nothing was changed (backup ${bak##*/})" >&2
    exit 2
  }
fi
chmod 600 "$tmp"
mv -f "$tmp" "$ak"
trap - EXIT
echo "authorized: appended 1 line to authorized_keys${bak:+ (backup ${bak##*/})}"
