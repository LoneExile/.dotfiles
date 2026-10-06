#!/usr/bin/env bash
# Tests for infra/leak-check.sh. Fixtures only: RFC 5737 addresses, a locally administered MAC.
set -uo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../home/secretspec/testlib.sh
. "$ROOT/home/secretspec/testlib.sh" || exit 1

fixture_env() {
  export TF_VAR_proxmox_endpoint='https://203.0.113.9:8006/'
  export TF_VAR_proxmox_api_token='fixture@pve!probe=0d6c1c2e-0000-4000-8000-000000000001'
  export TF_VAR_tofu_state_passphrase='fixture0passphrase0123456789abcdef'
  export TF_VAR_vms='{"testvm-alpha":{"node":"n1","vmid":901,"mac":"02:00:5E:10:00:01","ipv4_cidr":"203.0.113.10/24","gateway":"203.0.113.1","dns":["198.51.100.53"],"cores":2,"memory_mb":2048,"disk_gb":20}}'
}
fresh_repo() {
  git init -q "$T/r"
  printf 'clean\n' >"$T/r/a.txt"
  git -C "$T/r" add a.txt
}
track() { # track FILE CONTENT
  printf '%s\n' "$2" >"$T/r/$1"
  git -C "$T/r" add "$1"
}
check() { (cd "$T/r" && bash "$ROOT/infra/leak-check.sh") >"$T/out" 2>"$T/err"; echo $?; }
# shim_grep BODY: a PATH directory whose grep runs BODY instead of the real one.
shim_grep() {
  mkdir -p "$T/shim"
  printf '#!/bin/sh\n%s\n' "$1" >"$T/shim/grep"
  chmod +x "$T/shim/grep"
}
check_shimmed() { (cd "$T/r" && PATH="$T/shim:$PATH" bash "$ROOT/infra/leak-check.sh") >"$T/out" 2>"$T/err"; echo $?; }

test_clean_tree_passes() {
  fixture_env
  fresh_repo
  assert_rc "clean tree" "$(check)" 0
  assert_has "reports no leaks" "$T/out" "no leaks"
}

test_tracked_ipv4_fails_with_path_only() {
  fixture_env
  fresh_repo
  track leak.txt 'host 203.0.113.10'
  assert_rc "tracked ipv4" "$(check)" 1
  assert_has "names the path" "$T/out" "LEAK in leak.txt"
  assert_lacks "stdout hides the value" "$T/out" "203.0.113.10"
  assert_lacks "stderr hides the value" "$T/err" "203.0.113.10"
}

test_ipv4_matches_whole_words_only() {
  fixture_env
  fresh_repo
  track x.txt '203.0.113.100'
  assert_rc "longer address is not a hit" "$(check)" 0
}

test_mac_matches_any_case() {
  fixture_env
  fresh_repo
  track m.txt '02:00:5e:10:00:01'
  assert_rc "lowercase mac" "$(check)" 1
}

test_token_id_and_secret_are_checked() {
  fixture_env
  fresh_repo
  track t.txt 'fixture@pve!probe'
  assert_rc "token id" "$(check)" 1
  rm -rf "$T/r"
  fresh_repo
  track t.txt '0d6c1c2e-0000-4000-8000-000000000001'
  assert_rc "token secret" "$(check)" 1
}

test_endpoint_host_and_passphrase_are_checked() {
  fixture_env
  fresh_repo
  track e.txt '203.0.113.9'
  assert_rc "endpoint host" "$(check)" 1
  rm -rf "$T/r"
  fresh_repo
  track e.txt 'fixture0passphrase0123456789abcdef'
  assert_rc "passphrase" "$(check)" 1
}

test_vm_name_is_checked() {
  fixture_env
  fresh_repo
  track n.txt 'testvm-alpha'
  assert_rc "vm name" "$(check)" 1
}

test_untracked_is_ignored_staged_is_checked() {
  fixture_env
  fresh_repo
  printf 'testvm-alpha\n' >"$T/r/u.txt"
  assert_rc "untracked file" "$(check)" 0
  git -C "$T/r" add u.txt
  assert_rc "staged file" "$(check)" 1
}

test_short_value_aborts_naming_the_field() {
  fixture_env
  export TF_VAR_vms='{"db":{"node":"n1","vmid":902,"mac":"02:00:5E:10:00:02","ipv4_cidr":"203.0.113.11/24","gateway":"203.0.113.1"}}'
  fresh_repo
  assert_rc "short vm name" "$(check)" 2
  assert_has "names the field" "$T/err" "vm name"
  assert_has "says why" "$T/err" "shorter than 4"
  assert_lacks "does not echo the value" "$T/err" "db"
}

test_missing_env_fails_closed() {
  fixture_env
  unset TF_VAR_vms
  fresh_repo
  assert_rc "missing env" "$(check)" 2
  assert_has "names the variable" "$T/err" "TF_VAR_vms"
  assert_lacks "no success line" "$T/out" "no leaks"
}

test_positive_control_failure_exits_3() {
  fixture_env
  fresh_repo
  shim_grep 'exit 1'
  assert_rc "control cannot hit" "$(check_shimmed)" 3
  assert_has "names the control" "$T/err" "positive control"
  assert_lacks "no success line" "$T/out" "no leaks"
  assert_lacks "no value in stderr" "$T/err" "203.0.113"
}

test_grep_stderr_exits_3() {
  fixture_env
  fresh_repo
  # Delegate the positive control (its file is named "control") to the real grep,
  # so only the scan call fails and prints to stderr.
  shim_grep "case \"\$*\" in */control*) exec '$(command -v grep)' \"\$@\" ;; esac; echo 'grep: boom' >&2; exit 1"
  assert_rc "grep error" "$(check_shimmed)" 3
  assert_has "names the grep error" "$T/err" "grep reported an error"
  assert_lacks "not the control branch" "$T/err" "positive control"
  assert_lacks "no success line" "$T/out" "no leaks"
}

tl_init_pure
tl_run_all
tl_done
