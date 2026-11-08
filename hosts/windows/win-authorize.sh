#!/usr/bin/env bash
# win-authorize.sh NAME USER@ADDRESS: let the Windows host NAME (at ADDRESS) log in with its own SSH key (its entry in
# the infra vault map WIN_SSH_KEYS, made by win-sync), from this Mac. `just win-authorize` runs it; README: Windows
# hosts. It authorizes the key for:
#   - each Host alias of hosts/windows/NAME/ssh-hosts.txt (SSH from the Windows host);
#   - each [user@]host[:port] line of this Mac's Tern host list but ADDRESS itself (Tern from the Windows host, which
#     win-sync gives the same list): an SSH login to user@host, port 22. Endpoint-id lines are skipped;
#   - this Mac itself, which win-sync adds to that list by its endpoint id.
# A target that resolves (ssh -G) to the same user and host as an earlier one is skipped. For each, through this
# Mac's own login there (its ~/.ssh/config), or directly for this Mac: the key line goes into the user's
# ~/.ssh/authorized_keys, unless that file already holds the key (whatever its comment or options). Tern's remote
# service reads the same file. github.com takes the key into the account of `gh` instead (gh ssh-key add, which
# needs the admin:public_key scope). Nothing is ever removed.
# Prints ok (the key was there), changed (added) or error per target. Exit 0, 1 on any error, 2 usage.
set -uo pipefail
umask 077
repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
# shellcheck source=../../infra/vault-map.sh
. "$repo/infra/vault-map.sh" || exit 1

die() {
  printf 'win-authorize: %s\n' "$1" >&2
  exit 1
}

[ $# -eq 2 ] || {
  echo "usage: win-authorize.sh NAME USER@ADDRESS" >&2
  exit 2
}
name=$1
[[ $name =~ ^[a-z0-9][a-z0-9-]*$ ]] || die "not a host name: $(printf '%q' "$name")"
[[ $2 =~ ^[A-Za-z0-9._-]+@([A-Za-z0-9.-]+)$ ]] || die "not USER@ADDRESS: $(printf '%q' "$2")"
addr=${BASH_REMATCH[1]}
list=$repo/hosts/windows/$name/ssh-hosts.txt
[ -f "$list" ] || die "no host list hosts/windows/$name/ssh-hosts.txt"
tern_hosts=${WIN_SYNC_TERN_DIR:-$HOME/Library/Application Support/Tern}/hosts
[ -f "$tern_hosts" ] || die "no Tern host list on this Mac at $tern_hosts"

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

# Runs on each host under `sh -c '...'` (and here, for this Mac), so it holds no single quote. The key line comes on
# stdin. A last line without its newline gets one first, so the new line never joins it; permissions are set only
# on what it makes.
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
seen=""

# first_time DEST: true the first time DEST resolves (ssh -G) to its user@hostname, false after.
first_time() {
  local id
  id=$(ssh -G "$1" 2>/dev/null | awk '$1=="user"{u=$2} $1=="hostname"{h=$2} END{print u "@" h}')
  [ -n "$id" ] || id=$1
  if grep -qxF -- "$id" <<<"$seen"; then return 1; fi
  seen=$seen$id$'\n'
}

# authorize LABEL [DEST]: add the key over SSH to DEST, or with no DEST to this Mac's own file.
authorize() {
  local label=$1 out rc
  if [ $# -eq 1 ]; then
    out=$(printf '%s\n' "$pub" | sh -c "$snippet" 2>&1)
  else
    out=$(printf '%s\n' "$pub" | ssh -o BatchMode=yes -o ConnectTimeout=10 "$2" "sh -c '$snippet'" 2>&1)
  fi
  rc=$?
  if [ "$rc" -ne 0 ]; then
    printf 'error: %s: %s\n' "$label" "$(printf '%s' "$out" | tail -n 1)"
    errors=$((errors + 1))
    return
  fi
  case $(printf '%s' "$out" | tail -n 1) in
    present) echo "ok: $label: the key is in ~/.ssh/authorized_keys" ;;
    added) echo "changed: $label: key added to ~/.ssh/authorized_keys" ;;
    *)
      printf 'error: %s: unexpected answer: %s\n' "$label" "$(printf '%s' "$out" | tail -n 1)"
      errors=$((errors + 1))
      ;;
  esac
}

authorize_github() {
  local have
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
}

while IFS= read -r alias; do
  alias=${alias%%#*}
  alias=${alias//[[:space:]]/}
  [ -n "$alias" ] || continue
  if [ "$alias" = github.com ]; then
    authorize_github
  elif first_time "$alias"; then
    authorize "$alias" "$alias"
  fi
done <"$list"

while IFS= read -r line; do
  line=${line%%$'\t'*}
  line=${line//[[:space:]]/}
  case $line in "" | "#"*) continue ;; esac
  if ! [[ $line =~ ^(([A-Za-z0-9._-]+)@)?([A-Za-z0-9.-]+)(:[0-9]{1,5})?$ ]]; then
    printf 'error: the Tern host list has a line that is not [user@]host[:port]: %s\n' "$(printf '%q' "$line")"
    errors=$((errors + 1))
    continue
  fi
  host=${BASH_REMATCH[3]}
  dest=${BASH_REMATCH[1]}$host
  [[ $host =~ ^[0-9a-f]{64}$ ]] && continue
  [ "$host" != "$addr" ] || continue
  if first_time "$dest"; then authorize "$dest" "$dest"; fi
done <"$tern_hosts"

authorize "this Mac"
[ "$errors" -eq 0 ] || exit 1
