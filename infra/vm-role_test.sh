#!/usr/bin/env bash
# Tests for the per-VM role: the `role` field of TF_VAR_vms (infra/proxmox/vms/variables.tf and
# outputs.tf, run through a real `tofu plan` and `tofu apply` in a scratch copy, local state, no
# provider and no network) and infra/vm-config.sh, which turns the role into a flake attribute.
# Fixtures only: RFC 5737 addresses, a locally administered MAC, invented names.
set -uo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../home/secretspec/testlib.sh
. "$ROOT/home/secretspec/testlib.sh" || exit 1

UNIT=$ROOT/infra/proxmox/vms
BASE='{"testvm-alpha":{"node":"n1","vmid":901,"mac":"02:00:5E:10:00:01","ipv4_cidr":"203.0.113.10/24","gateway":"203.0.113.1","dns":["198.51.100.53"],"cores":2,"memory_mb":2048,"disk_gb":20}}'

# with_role JSON NAME ROLE-AS-JSON: the map with the entry's role set to that JSON value.
with_role() { printf '%s' "$1" | jq -c --arg n "$2" --argjson r "$3" '.[$n].role = $r'; }

command -v tofu >/dev/null || {
  echo "tofu not found on PATH" >&2
  exit 2
}
command -v jq >/dev/null || {
  echo "jq not found on PATH" >&2
  exit 2
}

# tf_apply VMS-JSON: copy the unit's variables and outputs into a scratch directory (no provider,
# no backend: nothing leaves the machine), then plan and apply with TF_VAR_vms = VMS-JSON.
# Prints the exit status of the first failing step (0 when both worked). Logs: $T/plan.log,
# $T/apply.log. The other variables get dummies: this test is about `vms`.
tf_apply() {
  mkdir -p "$T/tf"
  cp "$UNIT/variables.tf" "$UNIT/outputs.tf" "$T/tf/"
  local rc=0
  (
    cd "$T/tf" || exit 99
    export TF_IN_AUTOMATION=1 TF_DATA_DIR=$T/tf/.tofu
    export TF_VAR_image_datastore=d TF_VAR_vm_datastore=v TF_VAR_network_bridge=b TF_VAR_ssh_authorized_keys=k
    export TF_VAR_vms=$1
    tofu init -input=false -no-color >"$T/init.log" 2>&1 || exit 98
    tofu plan -input=false -no-color >"$T/plan.log" 2>&1 || exit 1
    tofu apply -input=false -no-color -auto-approve >"$T/apply.log" 2>&1 || exit 2
  ) || rc=$?
  echo "$rc"
}
tf_out() { (cd "$T/tf" && TF_DATA_DIR=$T/tf/.tofu tofu output -json vms 2>/dev/null); }

test_no_role_means_clean() {
  assert_rc "apply" "$(tf_apply "$BASE")" 0
  assert_eq "role in the output" clean "$(tf_out | jq -r '.["testvm-alpha"].role')"
}

test_role_agent_and_clean_reach_the_output() {
  assert_rc "apply agent" "$(tf_apply "$(with_role "$BASE" testvm-alpha '"agent"')")" 0
  assert_eq "agent" agent "$(tf_out | jq -r '.["testvm-alpha"].role')"
  rm -rf "$T/tf"
  assert_rc "apply clean" "$(tf_apply "$(with_role "$BASE" testvm-alpha '"clean"')")" 0
  assert_eq "clean" clean "$(tf_out | jq -r '.["testvm-alpha"].role')"
}

test_null_role_is_the_default() {
  assert_rc "apply" "$(tf_apply "$(with_role "$BASE" testvm-alpha null)")" 0
  assert_eq "null becomes clean" clean "$(tf_out | jq -r '.["testvm-alpha"].role')"
}

test_the_role_changes_no_other_output_field() {
  assert_rc "apply without" "$(tf_apply "$BASE")" 0
  local plain
  plain=$(tf_out | jq -cS 'map_values(del(.role))')
  rm -rf "$T/tf"
  assert_rc "apply with" "$(tf_apply "$(with_role "$BASE" testvm-alpha '"agent"')")" 0
  assert_eq "ip, node, vmid unchanged" "$plain" "$(tf_out | jq -cS 'map_values(del(.role))')"
}

test_each_vm_keeps_its_own_role() {
  local two
  two=$(printf '%s' "$BASE" | jq -c '. + {"testvm-bravo": (.["testvm-alpha"] | .vmid = 902 | .mac = "02:00:5E:10:00:02" | .ipv4_cidr = "203.0.113.11/24" | .role = "agent")}')
  assert_rc "apply" "$(tf_apply "$two")" 0
  assert_eq "alpha" clean "$(tf_out | jq -r '.["testvm-alpha"].role')"
  assert_eq "bravo" agent "$(tf_out | jq -r '.["testvm-bravo"].role')"
}

test_other_roles_are_refused_at_plan_time() {
  local r
  for r in '""' '"Agent"' '"agent "' '"root"' '"CLEAN"' 'true' '7' '["agent"]'; do
    assert_rc "plan refuses $r" "$(tf_apply "$(with_role "$BASE" testvm-alpha "$r")")" 1
    rm -rf "$T/tf"
  done
  tf_apply "$(with_role "$BASE" testvm-alpha '"root"')" >/dev/null
  assert_has "the message names the role" "$T/plan.log" "role"
  assert_has "the message lists the roles" "$T/plan.log" "clean or agent"
}

# ---- infra/vm-config.sh -------------------------------------------------------------------

# config VMS-JSON NAME: print the exit status; stdout in $T/out, stderr in $T/err.
config() {
  TF_VAR_vms=$1 bash "$ROOT/infra/vm-config.sh" "${@:2}" >"$T/out" 2>"$T/err"
  echo $?
}

test_config_maps_the_role_to_a_flake_attribute() {
  assert_rc "no role" "$(config "$BASE" testvm-alpha)" 0
  assert_eq "clean is the default" proxmox-guest "$(cat "$T/out")"
  assert_rc "clean" "$(config "$(with_role "$BASE" testvm-alpha '"clean"')" testvm-alpha)" 0
  assert_eq "clean" proxmox-guest "$(cat "$T/out")"
  assert_rc "null" "$(config "$(with_role "$BASE" testvm-alpha null)" testvm-alpha)" 0
  assert_eq "null is clean" proxmox-guest "$(cat "$T/out")"
  assert_rc "agent" "$(config "$(with_role "$BASE" testvm-alpha '"agent"')" testvm-alpha)" 0
  assert_eq "agent" proxmox-agent "$(cat "$T/out")"
}

test_config_reads_the_named_entry() {
  local two
  two=$(printf '%s' "$BASE" | jq -c '. + {"testvm-bravo": (.["testvm-alpha"] | .role = "agent")}')
  assert_rc "alpha" "$(config "$two" testvm-alpha)" 0
  assert_eq "alpha" proxmox-guest "$(cat "$T/out")"
  assert_rc "bravo" "$(config "$two" testvm-bravo)" 0
  assert_eq "bravo" proxmox-agent "$(cat "$T/out")"
}

test_config_refuses_other_roles_without_echoing_them() {
  local r
  for r in '"Agent"' '""' '"root"' 'true' '7' '["agent"]' '{"a":1}'; do
    assert_rc "refuses $r" "$(config "$(with_role "$BASE" testvm-alpha "$r")" testvm-alpha)" 1
    assert_has "names the field" "$T/err" "role"
    assert_eq "prints no attribute" "" "$(cat "$T/out")"
  done
  assert_rc "a secret-looking role" "$(config "$(with_role "$BASE" testvm-alpha '"hunter2-secret"')" testvm-alpha)" 1
  assert_lacks "the value is not echoed" "$T/err" hunter2
}

test_config_refuses_a_missing_vm_or_a_bad_map() {
  assert_rc "no such VM" "$(config "$BASE" testvm-zulu)" 1
  assert_has "says so" "$T/err" "no VM named testvm-zulu"
  assert_rc "not JSON" "$(config 'not json' testvm-alpha)" 1
  assert_rc "an array" "$(config '[1]' testvm-alpha)" 1
  assert_rc "an entry that is not an object" "$(config '{"testvm-alpha":"x"}' testvm-alpha)" 1
  assert_rc "empty map" "$(config '{}' testvm-alpha)" 1
  assert_eq "prints nothing" "" "$(cat "$T/out")"
}

test_config_needs_the_environment_and_one_argument() {
  assert_rc "empty TF_VAR_vms" "$(config '' testvm-alpha)" 1
  assert_has "says how to run it" "$T/err" "secretspec"
  assert_rc "no argument" "$(TF_VAR_vms=$BASE bash "$ROOT/infra/vm-config.sh" >"$T/out" 2>"$T/err"; echo $?)" 2
  assert_rc "two arguments" "$(config "$BASE" a b)" 2
}

tl_init_pure
tl_run_all
tl_done
