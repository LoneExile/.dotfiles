#!/usr/bin/env bash
# Tests for infra/vm-vault-tunnel.sh: the Mac forwards one local TCP port (8250) to the same port of the agent VM, in the foreground, for the browser step of an
# OIDC login that runs on the VM. `ssh` is a shim that logs its arguments and exits; the state and the vault are shims too (the address and the role come out of
# them, as in vm-sync). A listener that these tests start stands for "something already uses the port". Fixtures only: RFC 5737 addresses, invented names.
# The tests use a free port of their own (VM_VAULT_TUNNEL_PORT) so that a bao login or a tunnel that runs on this machine cannot fail them; one test runs the
# default and is skipped when 8250 is busy here.
set -uo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../home/secretspec/testlib.sh
. "$ROOT/home/secretspec/testlib.sh" || exit 1
for c in jq python3; do
  command -v "$c" >/dev/null || {
    echo "$c not found on PATH" >&2
    exit 2
  }
done
SCRIPT=$ROOT/infra/vm-vault-tunnel.sh
VMS='{"testvm-alpha":{"node":"n1","vmid":901,"role":"agent"},"testvm-clean":{"node":"n1","vmid":902}}'
ADDR=203.0.113.10

# busy ADDR PORT: does something accept a connection there? (the same probe as the script's, written out here on purpose: a test must not borrow the code it tests)
busy() { (exec 3<>"/dev/tcp/$1/$2") 2>/dev/null; }
# free_port: a port with nothing on 127.0.0.1 or ::1
free_port() {
  local p i
  for i in $(seq 1 50); do
    p=$((20000 + RANDOM % 30000))
    busy 127.0.0.1 "$p" || busy ::1 "$p" || {
      echo "$p"
      return 0
    }
  done
  return 1
}

# world: shims in $T/bin (secretspec, terragrunt, ssh), the log files, and a free port in $PORT.
world() {
  mkdir -p "$T/bin" "$T/store"
  printf '%s' "$VMS" >"$T/store/TF_VAR_vms"
  cat >"$T/bin/secretspec" <<'EOF'
#!/bin/sh
printf 'secretspec %s\n' "$*" >>"$STUB_CALLS"
case "$1" in run) shift; [ "$1" = -- ] && shift; TF_VAR_vms=$(cat "$STUB_DIR/TF_VAR_vms") exec "$@" ;; esac
EOF
  cat >"$T/bin/terragrunt" <<'EOF'
#!/bin/sh
printf 'terragrunt %s\n' "$*" >>"$STUB_CALLS"
printf '{"testvm-alpha":{"ip":"203.0.113.10"},"testvm-clean":{"ip":"203.0.113.11"}}'
EOF
  cat >"$T/bin/ssh" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"$STUB_SSHLOG"
exit "${STUB_SSH_RC:-0}"
EOF
  chmod +x "$T/bin/"*
  : >"$T/sshlog"
  : >"$T/calls"
  mkdir -p "$T/tmp"
  export STUB_DIR="$T/store" STUB_SSHLOG="$T/sshlog" STUB_CALLS="$T/calls" TMPDIR="$T/tmp" PATH="$T/bin:$PATH"
  PORT=$(free_port) || return 1
}
# run [NAME]: the script with the test port; stdout and stderr in $T/out and $T/err; the exit status is printed
run() { VM_VAULT_TUNNEL_PORT=$PORT bash "$SCRIPT" "${1:-testvm-alpha}" "$ROOT" >"$T/out" 2>"$T/err"; echo $?; }
ssh_calls() { grep -c '' "$T/sshlog"; }
other_calls() { grep -c '' "$T/calls"; }

# listen ADDR PORT: a TCP listener on that address, until the test ends (tl_cleanup stops every `pid` file under the temp directory)
listen() {
  local d=$T/lst-$1 i
  mkdir -p "$d"
  : >"$d/ready"
  python3 -c '
import socket, sys, time
fam = socket.AF_INET6 if ":" in sys.argv[1] else socket.AF_INET
s = socket.socket(fam)
s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
try:
    s.bind((sys.argv[1], int(sys.argv[2])))
except OSError as e:
    print("bind failed:", e, flush=True)
    sys.exit(3)
s.listen(5)
print("ready", flush=True)
time.sleep(60)
' "$1" "$2" >"$d/ready" 2>&1 &
  echo $! >"$d/pid"
  for i in $(seq 1 50); do
    grep -q . "$d/ready" && break
    sleep 0.1
  done
  grep -qx ready "$d/ready"
}

test_runs_ssh_in_the_foreground_with_exactly_these_arguments() {
  world
  assert_rc "run" "$(run)" 0
  assert_eq "exactly one ssh call" 1 "$(ssh_calls)"
  assert_eq "its arguments: strict host key, nothing written to known_hosts, no prompt, no forwarding of anything but the one port, on the loopback, and a failed bind is a failure" \
    "-o BatchMode=yes -o StrictHostKeyChecking=yes -o UpdateHostKeys=no -o ConnectTimeout=10 -N -o ExitOnForwardFailure=yes -o GatewayPorts=no -L $PORT:localhost:$PORT lex@$ADDR" "$(cat "$T/sshlog")"
}

test_the_default_port_is_8250_on_both_sides() {
  world
  if busy 127.0.0.1 8250 || busy ::1 8250; then
    skip "TCP 8250 is in use on this machine (a bao login or a tunnel runs here)"
    return 0
  fi
  RC=0
  bash "$SCRIPT" testvm-alpha "$ROOT" >"$T/out" 2>"$T/err" || RC=$?
  assert_rc "run" "$RC" 0
  assert_has "the forward is 8250 here to localhost:8250 there" "$T/sshlog" " -L 8250:localhost:8250 lex@$ADDR"
}

test_one_line_says_what_to_do_and_the_address_is_never_printed_or_written() {
  world
  assert_rc "run" "$(run)" 0
  assert_eq "one line in all (stdout and stderr together)" 1 "$(cat "$T/out" "$T/err" | grep -c '')"
  assert_has "it names the command to run on the VM" "$T/out" 'just vault-login'
  assert_has "it says the URL is opened in this Mac's browser" "$T/out" "browser"
  assert_has "it names the VM" "$T/out" "testvm-alpha"
  assert_has "it names the port" "$T/out" "$PORT"
  assert_lacks "stdout never holds the address" "$T/out" "$ADDR"
  assert_lacks "stderr never holds the address" "$T/err" "$ADDR"
  assert_eq "no file is left in the temp directory" 0 "$(find "$T/tmp" -type f | grep -c '')"
}

test_the_exit_status_is_the_one_of_ssh() {
  world
  export STUB_SSH_RC=255
  assert_rc "ssh fails (host key not pinned, VM down, port not bindable)" "$(run)" 255
  export STUB_SSH_RC=3
  assert_rc "any other status" "$(run)" 3
}

test_a_port_in_use_on_127_0_0_1_is_refused_before_anything_else() {
  world
  listen 127.0.0.1 "$PORT" || { bad "could not start a listener" "$(cat "$T/lst-127.0.0.1/ready")"; return 0; }
  assert_rc "run" "$(run)" 1
  assert_has "says why" "$T/err" "already in use"
  assert_has "names the port" "$T/err" "$PORT"
  assert_eq "ssh was not started" 0 "$(ssh_calls)"
  assert_eq "neither the state nor the vault was asked" 0 "$(other_calls)"
}

test_a_port_in_use_on_the_ipv6_loopback_is_refused_too() {
  world
  if ! listen ::1 "$PORT"; then
    skip "cannot listen on ::1 here ($(cat "$T/lst-::1/ready"))"
    return 0
  fi
  assert_rc "run" "$(run)" 1
  assert_has "says why" "$T/err" "already in use"
  assert_eq "ssh was not started" 0 "$(ssh_calls)"
}

test_once_the_listener_is_gone_the_tunnel_starts() {
  world
  listen 127.0.0.1 "$PORT" || { bad "could not start a listener"; return 0; }
  assert_rc "refused while it listens" "$(run)" 1
  kill "$(cat "$T/lst-127.0.0.1/pid")" 2>/dev/null
  wait "$(cat "$T/lst-127.0.0.1/pid")" 2>/dev/null
  assert_rc "starts after it is gone" "$(run)" 0
  assert_eq "ssh ran once" 1 "$(ssh_calls)"
}

test_a_vm_of_the_clean_role_is_refused() {
  world
  assert_rc "run" "$(run testvm-clean)" 1
  assert_has "says why" "$T/err" "clean"
  assert_eq "ssh was not started" 0 "$(ssh_calls)"
}

test_an_unknown_vm_is_refused() {
  world
  assert_rc "run" "$(run nosuchvm)" 1
  assert_eq "ssh was not started" 0 "$(ssh_calls)"
}

test_the_agent_user_is_the_one_of_the_other_recipes() {
  world
  assert_rc "run with VM_AGENT_USER" "$(VM_AGENT_USER=agentx run)" 0
  assert_has "that user is the login" "$T/sshlog" " agentx@$ADDR"
}

test_bad_arguments_start_nothing() {
  world
  RC=0
  bash "$SCRIPT" >"$T/out" 2>"$T/err" || RC=$?
  assert_rc "no argument" "$RC" 2
  assert_has "usage" "$T/err" "usage"
  RC=0
  bash "$SCRIPT" testvm-alpha >"$T/out" 2>"$T/err" || RC=$?
  assert_rc "no repo" "$RC" 2
  local n p
  for n in 'bad name' '-x' 'a;b' '../x' ''; do
    RC=0
    VM_VAULT_TUNNEL_PORT=$PORT bash "$SCRIPT" "$n" "$ROOT" >"$T/out" 2>"$T/err" || RC=$?
    assert_rc "name $(printf %q "$n")" "$RC" 1
  done
  for p in abc 0 70000 '8250 ' '-1' '08250'; do
    RC=0
    VM_VAULT_TUNNEL_PORT=$p bash "$SCRIPT" testvm-alpha "$ROOT" >"$T/out" 2>"$T/err" || RC=$?
    assert_rc "port $(printf %q "$p")" "$RC" 1
  done
  assert_eq "ssh was never started" 0 "$(ssh_calls)"
  assert_eq "neither the state nor the vault was asked" 0 "$(other_calls)"
}

test_the_justfile_recipe_and_the_test_list_name_the_script() {
  assert_has "the recipe calls the script with the VM name and the repo" "$ROOT/justfile" 'vm-vault-tunnel.sh" {{quote(name)}} "{{justfile_directory()}}"'
  assert_has "the recipe is named vm-vault-tunnel and takes the VM name" "$ROOT/justfile" 'vm-vault-tunnel name:'
  assert_has "just test-infra runs this file" "$ROOT/justfile" 'bash infra/vm-vault-tunnel_test.sh'
}

tl_init_pure
tl_run_all
tl_done
