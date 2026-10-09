#!/usr/bin/env bash
# Tests for the scripts that deploy a VM's role: infra/vm-install.sh and infra/vm-deploy.sh run for
# real, with shims in place of secretspec, terragrunt, ssh, ssh-keygen -R's host and nix. The shims
# record what the scripts ask of them, so the tests see which flake attribute each VM gets.
# Fixtures only: RFC 5737 addresses, a locally administered MAC, invented names.
set -uo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../home/secretspec/testlib.sh
. "$ROOT/home/secretspec/testlib.sh" || exit 1

BASE='{"testvm-alpha":{"node":"n1","vmid":901,"mac":"02:00:5E:10:00:01","ipv4_cidr":"203.0.113.10/24","gateway":"203.0.113.1","dns":["198.51.100.53"],"cores":2,"memory_mb":2048,"disk_gb":20}}'
with_role() { printf '%s' "$1" | jq -c --arg n "$2" --argjson r "$3" '.[$n].role = $r'; }
# The real ssh-keygen, found before a shim directory is put in front of it (shims runs twice in a test).
REAL_KEYGEN=$(command -v ssh-keygen)

# shims VMS-JSON: PATH directory $T/bin with a vault of files ($T/store), the vms JSON in it, and
# shims that log their arguments:
#   secretspec get|set KEY, run -- CMD...   the file-backed vault; `run` exports TF_VAR_vms first
#   terragrunt output -json vms             the `vms` output a state would hold (ip and role)
#   ssh                                     succeeds (the debian@ login check); the agent sync config
#                                           it is asked for says: nothing to sync (vm-sync_test.sh covers the sync)
#   nix                                     logs its arguments to $T/nix.log (and, for nixos-anywhere,
#                                           the file names of its --extra-files tree)
shims() {
  mkdir -p "$T/bin" "$T/store"
  printf '%s' "$1" >"$T/store/TF_VAR_vms"
  printf '{}' >"$T/store/VM_LUKS_KEYS"
  printf '{}' >"$T/store/VM_INITRD_HOST_KEYS"
  cat >"$T/bin/secretspec" <<'EOF'
#!/bin/sh
case "$1" in
  get) cat "$STUB_DIR/$2" ;;
  set) d=$(cat); [ -n "$d" ] || exit 1; printf '%s' "$d" >"$STUB_DIR/$2" ;;
  run) shift; [ "$1" = -- ] && shift; TF_VAR_vms=$(cat "$STUB_DIR/TF_VAR_vms") exec "$@" ;;
esac
EOF
  cat >"$T/bin/terragrunt" <<'EOF'
#!/bin/sh
[ "${STUB_STATE_DOWN:-0}" = 0 ] || { echo "state store unreachable" >&2; exit 1; }
src="$STUB_DIR/TF_VAR_vms.state"; [ -f "$src" ] || src="$STUB_DIR/TF_VAR_vms"
jq -c 'map_values({ip: (.ipv4_cidr | split("/")[0]), node: .node, vmid: .vmid, role: (.role // "clean")})' "$src"
EOF
  cat >"$T/bin/ssh" <<'EOF'
#!/bin/sh
for a; do last=$a; done
case "$last" in "cat "*dotfiles-agent-sync.json*) echo '{"gh":false,"plugins":false,"skills":false}' ;; esac
exit 0
EOF
  # ssh-keygen -R edits the known_hosts of the passwd home, not $HOME: never let a test reach it.
  # (the real binary was looked up before any shim directory was on PATH)
  cat >"$T/bin/ssh-keygen" <<EOF
#!/bin/sh
[ "\$1" = -R ] && exit "\${STUB_KEYGEN_R_RC:-0}"
exec "$REAL_KEYGEN" "\$@"
EOF
  cat >"$T/bin/nix" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"$STUB_LOG"
prev=
for a in "$@"; do
  if [ "$prev" = --extra-files ]; then (cd "$a" && find . -type f | sort >>"$STUB_LOG.files"); fi
  prev=$a
done
exit 0
EOF
  chmod +x "$T/bin/"*
  : >"$T/nix.log"
  export STUB_DIR="$T/store" STUB_LOG="$T/nix.log" PATH="$T/bin:$PATH"
}

# deploy NAME: run vm-deploy.sh the way the justfile does; prints the exit status.
deploy() { (cd "$ROOT" && bash "$ROOT/infra/vm-deploy.sh" "$1" "$ROOT") >"$T/out" 2>"$T/err"; echo $?; }

# install NAME: run vm-install.sh with the environment `secretspec run` would give it; prints the
# exit status.
install() {
  rm -f "$T/key" "$T/key.pub"
  ssh-keygen -q -t ed25519 -N '' -C fixture -f "$T/key" >/dev/null
  (
    cd "$ROOT" || exit 99
    export TF_VAR_ssh_authorized_keys
    TF_VAR_ssh_authorized_keys=$(cat "$T/key.pub")
    export TF_VAR_vms VM_LUKS_KEYS VM_INITRD_HOST_KEYS
    TF_VAR_vms=$(cat "$T/store/TF_VAR_vms")
    VM_LUKS_KEYS=$(cat "$T/store/VM_LUKS_KEYS")
    VM_INITRD_HOST_KEYS=$(cat "$T/store/VM_INITRD_HOST_KEYS")
    # vm-install.sh reads the address from the unit directory's terragrunt output.
    bash "$ROOT/infra/vm-install.sh" "$1" "$ROOT"
  ) >"$T/out" 2>"$T/err"
  echo $?
}

flake_of() { sed -n 's/.*--flake \([^ ]*\).*/\1/p' "$T/nix.log"; }

test_deploy_uses_the_clean_configuration_by_default() {
  shims "$BASE"
  assert_rc "deploy" "$(deploy testvm-alpha)" 0
  assert_eq "flake attribute" ".#proxmox-guest" "$(flake_of)"
  assert_has "target and build host" "$T/nix.log" "--target-host root@203.0.113.10 --build-host root@203.0.113.10"
  assert_has "says which configuration" "$T/out" "proxmox-guest"
}

test_deploy_uses_the_agent_configuration_for_the_agent_role() {
  shims "$(with_role "$BASE" testvm-alpha '"agent"')"
  assert_rc "deploy" "$(deploy testvm-alpha)" 0
  assert_eq "flake attribute" ".#proxmox-agent" "$(flake_of)"
  assert_has "says which configuration" "$T/out" "proxmox-agent"
}

test_deploy_follows_the_vault_not_the_state() {
  # The state's output still says clean (nobody ran infra-apply since the flip): the vault wins.
  shims "$(with_role "$BASE" testvm-alpha '"agent"')"
  printf '%s' "$BASE" >"$T/store/TF_VAR_vms.state"
  assert_eq "the state output says clean" clean "$(terragrunt output -json vms | jq -r '.["testvm-alpha"].role')"
  assert_rc "deploy" "$(deploy testvm-alpha)" 0
  assert_eq "flake attribute" ".#proxmox-agent" "$(flake_of)"
}

test_deploy_stops_before_nix_on_a_bad_role_or_vm_or_state() {
  shims "$(with_role "$BASE" testvm-alpha '"Agent"')"
  assert_rc "bad role" "$(deploy testvm-alpha)" 1
  assert_eq "nix not run" "" "$(cat "$T/nix.log")"
  shims "$BASE"
  assert_rc "no such VM" "$(deploy testvm-zulu)" 1
  assert_eq "nix not run (no VM)" "" "$(cat "$T/nix.log")"
  assert_rc "state unreachable" "$(STUB_STATE_DOWN=1 deploy testvm-alpha)" 1
  assert_has "says the state" "$T/err" "could not read the VM list from the state"
  assert_eq "nix not run (state)" "" "$(cat "$T/nix.log")"
}

test_deploy_takes_two_arguments() {
  shims "$BASE"
  assert_rc "none" "$( (cd "$ROOT" && bash "$ROOT/infra/vm-deploy.sh") >"$T/out" 2>"$T/err"; echo $?)" 2
  assert_rc "one" "$( (cd "$ROOT" && bash "$ROOT/infra/vm-deploy.sh" testvm-alpha) >"$T/out" 2>"$T/err"; echo $?)" 2
}

test_install_uses_the_clean_configuration_by_default() {
  shims "$BASE"
  assert_rc "install" "$(install testvm-alpha)" 0
  assert_has "flake" "$T/nix.log" "--flake $ROOT#proxmox-guest "
  assert_lacks "not the agent" "$T/nix.log" "proxmox-agent"
  assert_has "installs over debian@" "$T/nix.log" "--target-host debian@203.0.113.10"
}

test_install_uses_the_agent_configuration_for_the_agent_role() {
  shims "$(with_role "$BASE" testvm-alpha '"agent"')"
  assert_rc "install" "$(install testvm-alpha)" 0
  assert_has "flake" "$T/nix.log" "--flake $ROOT#proxmox-agent "
  assert_lacks "not the clean one" "$T/nix.log" "proxmox-guest"
}

test_install_stops_before_formatting_on_a_bad_role() {
  shims "$(with_role "$BASE" testvm-alpha '"agnt"')"
  assert_rc "install" "$(install testvm-alpha)" 1
  assert_has "names the role" "$T/err" "role"
  assert_eq "nix not run" "" "$(cat "$T/nix.log")"
  assert_eq "no passphrase generated" "{}" "$(cat "$T/store/VM_LUKS_KEYS")"
  assert_eq "no host key pinned" "{}" "$(cat "$T/store/VM_INITRD_HOST_KEYS")"
}

# `ssh-keygen -R` refuses to edit a known_hosts that has one malformed line (seen live: it exits 1
# for every host). The install is finished by then, so that must be a warning, not a failure.
test_install_survives_a_known_hosts_that_ssh_keygen_cannot_edit() {
  shims "$BASE"
  assert_rc "install" "$(STUB_KEYGEN_R_RC=1 install testvm-alpha)" 0
  assert_has "says how to clear the host key" "$T/err" "ssh-keygen -R"
  assert_has "still says the VM is installed" "$T/out" "is installed"
}

test_install_stages_the_same_files_for_every_role() {
  shims "$BASE"
  assert_rc "install clean" "$(install testvm-alpha)" 0
  sort "$T/nix.log.files" >"$T/files.clean"
  shims "$(with_role "$BASE" testvm-alpha '"agent"')"
  rm -f "$T/nix.log.files"
  assert_rc "install agent" "$(install testvm-alpha)" 0
  sort "$T/nix.log.files" >"$T/files.agent"
  assert_eq "same staged files (the user's keys are seeded on the VM, not shipped)" "$(cat "$T/files.clean")" "$(cat "$T/files.agent")"
  assert_has "root's keys" "$T/files.agent" "./root/.ssh/authorized_keys"
  assert_has "hostname" "$T/files.agent" "./etc/hostname"
}

tl_init_pure
tl_run_all
tl_done
