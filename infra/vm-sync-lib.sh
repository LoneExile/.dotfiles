# shellcheck shell=bash
# Functions of the VM sync, sourced by vm-sync.sh and vm-deploy.sh. Needs ssh, rsync, jq, base64.
#
# What the sync is: the agent role (modules/nixos/agent-dev.nix) lists in /etc/dotfiles-agent-sync.json
# which of three things it wants (options dotfiles.agent.sync.gh, .plugins and .skills):
#   gh       the agent user's gh login: the token of this VM from the vault map VM_GH_TOKENS (no entry:
#            skipped with a notice), written to ~/.config/gh/hosts.yml over ssh stdin
#   skills   the skills of the Mac's skills library (the directories of ~/.skills-manager/skills that
#            hold a SKILL.md), each mirrored with rsync into ~/.omp/agent/skills on the VM
#   plugins  the captured omp plugin manifests: placed and installed by the VM itself (Home Manager and
#            a user service), so the sync only reports how that stands
# Everything on the VM runs as the agent user, through infra/vm-sync-remote.sh, which the Mac sends
# over ssh. The auto-learned skills (~/.omp/agent/managed-skills) are never read, copied or listed.
#
# Host keys: every connection of the sync, ssh and rsync alike, uses StrictHostKeyChecking=yes (and
# UpdateHostKeys=no, so it never writes known_hosts either): the VM's key must already be pinned, or
# the sync refuses and says how to pin it (the re-key step of the README). The sync sends a token and
# may send more secrets later, so it never trusts a key on first use. vm-install does not use this file.

sync_user=${VM_AGENT_USER:-lex}
sync_ssh_opts=(-o BatchMode=yes -o StrictHostKeyChecking=yes -o UpdateHostKeys=no -o ConnectTimeout=10)

sync_die() {
  printf 'vm-sync: %s\n' "$1" >&2
  exit 1
}

# sync_host_key_state IP USER: pinned (ssh to USER@IP works, with a key that is pinned), unpinned (no
# entry in known_hosts), changed (the entry does not match what the VM presents) or unreachable
# (anything else: down, locked at the disk prompt, login refused). The strict options mean that the
# probe pins nothing.
sync_host_key_state() {
  local ip=$1 user=$2 err
  if err=$(ssh "${sync_ssh_opts[@]}" "$user@$ip" true 2>&1 >/dev/null); then
    echo pinned
    return 0
  fi
  case $err in
    *"IDENTIFICATION HAS CHANGED"*) echo changed ;;
    *"host key is known"* | *"Host key verification failed"*) echo unpinned ;;
    *) echo unreachable ;;
  esac
}

# sync_die_host_key NAME IP: refuse, and say how to pin the key.
sync_die_host_key() {
  sync_die "the host key of $2 ($1) is not pinned in known_hosts, or it does not match the pinned one. vm-sync sends secrets, so it never trusts a key on first use. Check that $2 belongs to $1, then run the re-key step of the README (Reinstall): ssh-keygen -R $2, then connect once and compare the fingerprint (ssh -o StrictHostKeyChecking=ask root@$2), or run just vm-deploy $1, which pins the key it sees; then run vm-sync again"
}

# under_secretspec REPO NAME SCRIPT: run an infra script in the Terragrunt unit with the vault's values
# (the address and the role come out of the state and the vault; the build and the rest run outside).
under_secretspec() {
  local repo=$1 name=$2 script=$3
  (cd "$repo/infra/proxmox/vms" && SECRETSPEC_FILE="$repo/infra/secretspec.toml" SECRETSPEC_REASON="dotfiles infra" secretspec run -- bash "$repo/infra/$script" "$name")
}

# sync_remote REPO IP SUBCOMMAND [ARG...]: run vm-sync-remote.sh on the VM as the agent user. The script
# travels base64-encoded in the command, so that stdin stays free (the token goes there). The arguments
# are names, checked here: they end up inside single quotes of a command that the remote shell parses.
sync_remote() {
  local repo=$1 ip=$2 b64 cmd a
  shift 2
  b64=$(base64 <"$repo/infra/vm-sync-remote.sh" | tr -d '\n') || sync_die "cannot read infra/vm-sync-remote.sh"
  [ -n "$b64" ] || sync_die "infra/vm-sync-remote.sh is empty"
  cmd='d=$(mktemp -d) && trap '"'"'rm -rf "$d"'"'"' EXIT && printf %s '"'$b64'"' | base64 -d >"$d/r.sh" && bash "$d/r.sh"'
  for a in "$@"; do
    [[ $a =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || sync_die "not a usable argument for the VM: $(printf '%q' "$a")"
    cmd="$cmd '$a'"
  done
  ssh "${sync_ssh_opts[@]}" "$sync_user@$ip" "$cmd"
}

# sync_wait_ssh NAME IP: wait until the agent user can log in (a deploy restarts sshd and the user's
# units). A host key that is not pinned, or does not match, ends the wait at once.
sync_wait_ssh() {
  local name=$1 ip=$2 limit=${VM_SYNC_WAIT:-90} start=$SECONDS
  while :; do
    case $(sync_host_key_state "$ip" "$sync_user") in
      pinned) return 0 ;;
      unpinned | changed) sync_die_host_key "$name" "$ip" ;;
    esac
    [ $((SECONDS - start)) -lt "$limit" ] || sync_die "cannot log in as $sync_user within ${limit}s (is the VM up and unlocked, and is it the agent role?)"
    sleep "${VM_SYNC_POLL:-2}"
  done
}

# sync_skill_names SRC: the names of the skill directories of the library SRC, one per line: real
# directories (not links, not hidden) that hold a SKILL.md. Exits when SRC or anything chosen is part
# of the auto-learned store, or when nothing is found.
sync_skill_names() {
  local src=$1 real lc d base resolved names=""
  [ -d "$src" ] || sync_die "no skills library at $src"
  real=$(cd "$src" && pwd -P)
  lc=$(printf '%s' "$real" | tr '[:upper:]' '[:lower:]')
  case $lc in
    *managed-skills*) sync_die "refusing to sync from $real: the managed-skills store (auto-learned notes) never leaves this Mac" ;;
  esac
  for d in "$src"/*/; do
    [ -d "$d" ] || continue
    d=${d%/}
    base=${d##*/}
    [ ! -L "$d" ] || continue
    [ -f "$d/SKILL.md" ] || continue
    resolved=$(cd "$d" && pwd -P | tr '[:upper:]' '[:lower:]')
    case $resolved in
      *managed-skills*) sync_die "refusing to sync $base: it is part of the managed-skills store" ;;
    esac
    if [[ ! $base =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
      printf 'vm-sync: skipping the directory %s of the library: not a usable name\n' "$(printf '%q' "$base")" >&2
      continue
    fi
    names=$names$base$'\n'
  done
  [ -n "$names" ] || sync_die "no skills found in $src (directories with a SKILL.md); nothing to sync"
  printf '%s' "$names"
}

# vm_sync NAME REPO IP: gh login and skills, as far as the VM's options ask for them.
vm_sync() {
  local name=$1 repo=$2 ip=$3 cfg cfgpath on token names n count=0
  cfgpath=${VM_SYNC_CONFIG_PATH:-/etc/dotfiles-agent-sync.json}
  sync_wait_ssh "$name" "$ip"
  cfg=$(ssh "${sync_ssh_opts[@]}" "$sync_user@$ip" "cat $cfgpath") || sync_die "cannot read $cfgpath on the VM (deploy the agent role first)"
  printf '%s' "$cfg" | jq -e 'type == "object"' >/dev/null 2>&1 || sync_die "$cfgpath on the VM is not a JSON object (dotfiles-agent-sync)"

  on=$(printf '%s' "$cfg" | jq -r '.gh // false')
  if [ "$on" = true ]; then
    token=$(SECRETSPEC_FILE="$repo/infra/secretspec.toml" SECRETSPEC_REASON="dotfiles infra" bash "$repo/infra/vm-gh-token.sh" "$name") || exit 1
    if [ -z "$token" ]; then
      echo "vm-sync: gh: no token for $name in VM_GH_TOKENS: skipped (see the README to store one)"
    else
      printf '%s' "$token" | sync_remote "$repo" "$ip" gh || sync_die "could not write the gh login on the VM"
    fi
    token=""
  fi

  on=$(printf '%s' "$cfg" | jq -r '.skills // false')
  if [ "$on" = true ]; then
    local src=${SYNC_SKILLS_SRC:-$HOME/.skills-manager/skills}
    names=$(sync_skill_names "$src") || exit 1
    # shellcheck disable=SC2086
    sync_remote "$repo" "$ip" skills-prepare $names || sync_die "the VM refused the skill names (see above)"
    for n in $names; do
      # Inside each named directory the VM copy becomes exactly the Mac's (--delete). Nothing else in
      # ~/.omp/agent/skills is named, so nothing else is touched. Links that point out of a skill are not sent.
      rsync -rlpt --delete --safe-links --no-owner --no-group --chmod=u+rwX \
        -e "ssh ${sync_ssh_opts[*]}" "$src/$n/" "$sync_user@$ip:.omp/agent/skills/$n/" || sync_die "rsync of the skill $n failed"
      count=$((count + 1))
    done
    echo "vm-sync: skills: $count mirrored into ~/.omp/agent/skills"
  fi

  on=$(printf '%s' "$cfg" | jq -r '.plugins // false')
  if [ "$on" = true ]; then
    sync_remote "$repo" "$ip" plugins-status || true
  fi
}

# vm_unsync NAME REPO IP: before the VM leaves the agent role, remove from the agent user's home exactly
# what the sync placed. No user on the VM: nothing to do. A user that cannot be cleaned stops the deploy.
vm_unsync() {
  local name=$1 repo=$2 ip=$3 rc=0
  case $(sync_host_key_state "$ip" root) in
    unpinned | changed) sync_die_host_key "$name" "$ip" ;;
  esac
  ssh "${sync_ssh_opts[@]}" "root@$ip" "id -u $sync_user" >/dev/null 2>&1 || rc=$?
  case $rc in
    0) ;;
    255) sync_die "cannot reach $name as root to look for the user $sync_user" ;;
    *)
      echo "vm-sync: $sync_user does not exist on $name: nothing to remove"
      return 0
      ;;
  esac
  sync_remote "$repo" "$ip" unsync || sync_die "could not remove what vm-sync placed in the home of $sync_user: not changing the role (fix the cause above, then deploy again)"
}
