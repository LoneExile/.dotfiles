#!/usr/bin/env bash
# win-authorize.sh NAME: let the Windows host NAME log in to the hosts of hosts/windows/NAME/ssh-hosts.txt with its
# own SSH key (its entry in the infra vault map WIN_SSH_KEYS, made by win-sync), from this Mac. `just win-authorize`
# runs it; README: Windows hosts.
#
# For each Host alias, through this Mac's own login there (its ~/.ssh/config): the key line goes into the remote
# user's ~/.ssh/authorized_keys, unless that file already holds the key (whatever its comment or options). Tern's
# remote service reads the same file, so the key serves Tern too. github.com takes the key into the account of
# `gh` instead (gh ssh-key add, which needs the admin:public_key scope). Nothing is ever removed.
# Prints ok (the key was there), changed (added) or error per alias. Exit 0, 1 on any error, 2 usage.
set -uo pipefail
umask 077
repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
# shellcheck source=../../infra/vault-map.sh
. "$repo/infra/vault-map.sh" || exit 1

die() {
  printf 'win-authorize: %s\n' "$1" >&2
  exit 1
}

[ $# -eq 1 ] || {
  echo "usage: win-authorize.sh NAME" >&2
  exit 2
}
name=$1
[[ $name =~ ^[a-z0-9][a-z0-9-]*$ ]] || die "not a host name: $(printf '%q' "$name")"
list=$repo/hosts/windows/$name/ssh-hosts.txt
[ -f "$list" ] || die "no host list hosts/windows/$name/ssh-hosts.txt"

work=$(mktemp -d "${TMPDIR:-/tmp}/win-authorize.XXXXXX") || die "cannot create a temp dir"
trap 'rm -rf "$work"' EXIT
export SECRETSPEC_FILE=$repo/infra/secretspec.toml SECRETSPEC_REASON="win-authorize $name"
key=$(map_get WIN_SSH_KEYS "$name") || die "cannot read WIN_SSH_KEYS from the vault (seed it with {})"
[ -n "$key" ] || die "no SSH key for $name in the vault map WIN_SSH_KEYS yet: run just win-sync first, which makes one"
printf '%s\n' "$key" >"$work/key"
key=""
pub=$(ssh-keygen -y -f "$work/key" 2>/dev/null) || die "the SSH key of $name in WIN_SSH_KEYS is not a usable private key"
rm -f "$work/key"
read -r ktype kbody _ <<<"$pub"
printf '%s\n' "$pub" >"$work/key.pub"

# Runs on each host under `sh -c '...'`, so it holds no single quote. The key line comes on stdin. A last line
# without its newline gets one first, so the new line never joins it; permissions are set only on what it makes.
# shellcheck disable=SC2016
snippet='read -r k; set -- $k; d="$HOME/.ssh"; f="$d/authorized_keys"
if [ -f "$f" ] && grep -qF "$1 $2" "$f"; then echo present; exit 0; fi
if [ ! -d "$d" ]; then mkdir -p "$d" && chmod 700 "$d" || exit 3; fi
new=""; [ -e "$f" ] || new=1
if [ -s "$f" ] && [ -n "$(tail -c 1 "$f")" ]; then echo >>"$f" || exit 3; fi
printf "%s\n" "$k" >>"$f" || exit 3
if [ -n "$new" ]; then chmod 600 "$f" || exit 3; fi
echo added'

errors=0
while IFS= read -r alias; do
  alias=${alias%%#*}
  alias=${alias//[[:space:]]/}
  [ -n "$alias" ] || continue
  if [ "$alias" = github.com ]; then
    if ! have=$(gh api user/keys --jq '.[].key' 2>"$work/gh.err"); then
      printf 'error: github.com: cannot list the keys of the gh account: %s\n' "$(tail -n 1 "$work/gh.err")"
      errors=$((errors + 1))
    elif grep -qxF "$ktype $kbody" <<<"$have"; then
      echo "ok: github.com: the key is in the gh account"
    elif gh ssh-key add "$work/key.pub" --title "$name (Windows)" >/dev/null 2>"$work/gh.err"; then
      echo "changed: github.com: key added to the gh account"
    else
      printf 'error: github.com: gh ssh-key add failed (%s); it needs the admin:public_key scope: gh auth refresh -h github.com -s admin:public_key\n' "$(tail -n 1 "$work/gh.err")"
      errors=$((errors + 1))
    fi
    continue
  fi
  if out=$(printf '%s\n' "$pub" | ssh -o BatchMode=yes -o ConnectTimeout=10 "$alias" "sh -c '$snippet'" 2>&1); then
    case $(printf '%s' "$out" | tail -n 1) in
      present) echo "ok: $alias: the key is in ~/.ssh/authorized_keys" ;;
      added) echo "changed: $alias: key added to ~/.ssh/authorized_keys" ;;
      *)
        printf 'error: %s: unexpected answer: %s\n' "$alias" "$(printf '%s' "$out" | tail -n 1)"
        errors=$((errors + 1))
        ;;
    esac
  else
    printf 'error: %s: %s\n' "$alias" "$(printf '%s' "$out" | tail -n 1)"
    errors=$((errors + 1))
  fi
done <"$list"
[ "$errors" -eq 0 ] || exit 1
