#!/usr/bin/env bash
# win-sync.sh NAME USER@ADDRESS [--check]: bring the Windows host NAME (hosts/windows/NAME/) to the dotfiles, from
# this Mac, over SSH as USER@ADDRESS (the account the sync sets up; its SSH server must already take this
# Mac's key). `just win-sync` runs it; README: Windows hosts.
#
# The Mac renders a bundle (hosts/windows/win-render.py): omp's config, models and MCP servers (with the host's
# overrides), the plugin manifests, Tern's settings, the Mac's own Tern host list (minus ADDRESS) plus the Mac
# itself, by its endpoint id, with the host keys the Mac pinned, an ~/.ssh/config of the listed
# hosts, the winget packages, the skills library (as vm-sync picks it: ~/.skills-manager/skills, never the
# auto-learned managed-skills) and two secrets: ~/.omp/.env (OMP_ENV of the vault) and the host's own SSH key
# (its entry in the infra vault map WIN_SSH_KEYS; made once, the first time, and kept there, so a reinstall gets
# the same key back). The bundle goes over with scp, and hosts/windows/apply.ps1 applies it on the host, changing
# only what differs; both copies of the bundle are deleted afterwards. --check changes nothing on either side:
# the host reports drift instead, and a host with no key in the vault yet is an error.
#
# The host key of ADDRESS must be pinned in ~/.ssh/known_hosts (StrictHostKeyChecking=yes, UpdateHostKeys=no):
# the sync sends secrets, so it never trusts a key on first use.
# Needs ssh, scp, secretspec (and the vault login), jq, nix, python3, ssh-keygen and /usr/bin/tar.
# Exit: 0 applied (or no drift), 1 an error (or drift), 2 usage.
set -uo pipefail
umask 077
repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
# shellcheck source=../../infra/vm-sync-lib.sh
. "$repo/infra/vm-sync-lib.sh" || exit 1
# shellcheck source=../../infra/vault-map.sh
. "$repo/infra/vault-map.sh" || exit 1

die() {
  printf 'win-sync: %s\n' "$1" >&2
  exit 1
}
# vm-sync-lib's helpers report through sync_die.
sync_die() { die "$1"; }

usage() {
  echo "usage: win-sync.sh NAME USER@ADDRESS [--check]" >&2
  exit 2
}
[ $# -eq 2 ] || [ $# -eq 3 ] || usage
name=$1 target=$2 check=""
if [ $# -eq 3 ]; then
  [ "$3" = --check ] || usage
  check=1
fi
[[ $name =~ ^[a-z0-9][a-z0-9-]*$ ]] || die "not a host name: $(printf '%q' "$name")"
[[ $target =~ ^([A-Za-z0-9._-]+)@([A-Za-z0-9.-]+)$ ]] || die "not USER@ADDRESS: $(printf '%q' "$target")"
user=${BASH_REMATCH[1]} addr=${BASH_REMATCH[2]}
hostdir=$repo/hosts/windows/$name
[ -d "$hostdir" ] || die "no host directory hosts/windows/$name"

# The probe runs `exit 0`, a command both PowerShell and a POSIX shell know.
if ! err=$(ssh "${sync_ssh_opts[@]}" "$target" 'exit 0' 2>&1 </dev/null >/dev/null); then
  case $err in
    *"IDENTIFICATION HAS CHANGED"* | *"host key is known"* | *"Host key verification failed"*)
      die "the host key of $addr is not pinned in ~/.ssh/known_hosts, or it does not match the pinned one. win-sync sends secrets, so it never trusts a key on first use. At $name, print the key's fingerprint (ssh-keygen -lf C:\\ProgramData\\ssh\\ssh_host_ed25519_key.pub); then ssh-keygen -R $addr, connect once with ssh -o StrictHostKeyChecking=ask $target, compare the two, and run win-sync again" ;;
    *) die "cannot log in as $target: is the host up, and does its SSH server take this Mac's key (C:\\ProgramData\\ssh\\administrators_authorized_keys for an administrator)?" ;;
  esac
fi

work=$(mktemp -d "${TMPDIR:-/tmp}/win-sync.XXXXXX") || die "cannot create a temp dir"
trap 'rm -rf "$work"' EXIT
stage=$work/bundle
mkdir -p "$stage/omp" "$stage/ssh" "$stage/skills" || die "cannot create the bundle"
export SECRETSPEC_REASON="win-sync $name"

# ~/.omp/.env: the Mac's, from the root manifest.
SECRETSPEC_FILE=$repo/secretspec.toml secretspec get OMP_ENV >"$stage/omp/env" ||
  die "cannot read OMP_ENV from the vault (just openbao-login, if the login expired)"
[ -s "$stage/omp/env" ] || die "OMP_ENV in the vault is empty"

# The host's own SSH key: the infra manifest, never materialized on the Mac.
export SECRETSPEC_FILE=$repo/infra/secretspec.toml
key=$(map_get WIN_SSH_KEYS "$name") || die "cannot read WIN_SSH_KEYS from the vault (seed it with {})"
if [ -z "$key" ]; then
  [ -z "$check" ] || die "no SSH key for $name in the vault map WIN_SSH_KEYS yet: run win-sync without --check, which makes one"
  ssh-keygen -q -t ed25519 -N '' -C "$user@$name" -f "$work/newkey" </dev/null >/dev/null || die "ssh-keygen could not make a key"
  key=$(cat "$work/newkey") || die "cannot read the new key"
  map_put WIN_SSH_KEYS "$name" "$key"
  echo "win-sync: made an SSH key for $name and stored it in the vault map WIN_SSH_KEYS"
fi
unset SECRETSPEC_FILE
printf '%s\n' "$key" >"$stage/ssh/id_ed25519"
key=""
ssh-keygen -y -f "$stage/ssh/id_ed25519" >"$stage/ssh/id_ed25519.pub" 2>/dev/null ||
  die "the SSH key of $name in WIN_SSH_KEYS is not a usable private key"

darwin=$(hostname | cut -d. -f1)
nix eval --json "$repo#darwinConfigurations.$darwin.config.home-manager.users.$(id -un).programs.ssh.settings" \
  >"$work/ssh-settings.json" 2>"$work/nix.err" || die "nix eval of the Mac's SSH settings failed: $(tail -n 3 "$work/nix.err")"
# This Mac's own Tern identity: the Windows host reaches it by endpoint id, through the relay, on any network.
tern_bin=$(command -v tern || echo /Applications/Tern.app/Contents/MacOS/tern)
eid=$("$tern_bin" remote host-key --user 2>/dev/null | jq -r '.endpoint_id // empty' 2>/dev/null)
[[ $eid =~ ^[0-9a-f]{64}$ ]] || die "cannot read this Mac's Tern endpoint id (tern remote host-key --user)"
mac_line="$(id -un)@$eid"$'\t'"$(hostname -s)"
tern_dir=${WIN_SYNC_TERN_DIR:-$HOME/Library/Application Support/Tern}
python3 "$repo/hosts/windows/win-render.py" "$repo" "$name" "$stage" "$work/ssh-settings.json" "$tern_dir" "$addr" "$mac_line" || exit 1

src=${SYNC_SKILLS_SRC:-$HOME/.skills-manager/skills}
names=$(sync_skill_names "$src") || exit 1
for n in $names; do
  cp -Rp "$src/$n" "$stage/skills/$n" || die "cannot copy the skill $n"
done
# Windows' tar cannot make symbolic links for this user; vm-sync leaves out the ones that leave a skill, too.
while IFS= read -r l; do
  printf 'win-sync: leaving out the symbolic link %s\n' "${l#"$stage/skills/"}" >&2
  rm -f "$l"
done < <(find "$stage/skills" -type l)
# shellcheck disable=SC2086 # one skill name per line
printf '%s\n' $names >"$stage/skills.txt"
cp "$repo/hosts/windows/apply.ps1" "$stage/apply.ps1" || die "cannot copy apply.ps1"

COPYFILE_DISABLE=1 /usr/bin/tar --no-mac-metadata --no-xattrs -czf "$work/bundle.tgz" -C "$stage" . ||
  die "cannot pack the bundle"
rm -rf "$stage"

remote=dotfiles-win-sync-$$-$RANDOM
scp -q "${sync_ssh_opts[@]}" "$work/bundle.tgz" "$target:$remote.tgz" </dev/null || die "scp of the bundle to $target failed"
flag=""
[ -z "$check" ] || flag=" -Check"
# PowerShell on the host: unpack into %TEMP%, run apply.ps1, then delete both copies whatever happened.
ps="\$ErrorActionPreference='Continue'; \$t=Join-Path \$env:USERPROFILE '$remote.tgz'; \$d=Join-Path \$env:TEMP '$remote'; \$rc=1; try { New-Item -ItemType Directory -Force \$d | Out-Null; tar.exe -xzf \$t -C \$d; if (\$LASTEXITCODE -ne 0) { throw 'tar could not unpack the bundle' }; Remove-Item -Force \$t; powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File (Join-Path \$d 'apply.ps1') -Bundle \$d$flag; \$rc=\$LASTEXITCODE } catch { Write-Output ('error: ' + \$_.Exception.Message) } finally { Remove-Item -Recurse -Force -LiteralPath \$d,\$t -ErrorAction SilentlyContinue }; exit \$rc"
# shellcheck disable=SC2029 # $ps is built here on purpose; the host's PowerShell parses it
ssh "${sync_ssh_opts[@]}" "$target" "$ps" </dev/null
exit $?
