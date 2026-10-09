#!/usr/bin/env bash
# Tests for home/linux/lazydocker-ssh.sh: lazydocker for a docker context that is ssh://. lazydocker (0.24 and master) reaches an ssh://
# host with `ssh -L <local socket>:/var/run/docker.sock host -N`, which needs socket forwarding, and the key of the jumphost is
# restricted to `docker system dial-stdio` (no forwarding). So for an ssh:// context the wrapper runs a local unix-socket bridge made
# of socat around `ssh <host> docker system dial-stdio` (the stream the docker CLI itself uses), points lazydocker at that socket,
# and removes the bridge when lazydocker ends. Everything else goes straight to lazydocker.
# docker, socat, ssh and lazydocker are shims: no daemon, no network, no ssh.
set -uo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
# shellcheck source=../secretspec/testlib.sh
. "$ROOT/home/secretspec/testlib.sh" || exit 1
SCRIPT=$ROOT/home/linux/lazydocker-ssh.sh
PY3=$(command -v python3) || {
  echo "python3 not found: the socat shim makes a unix socket with it" >&2
  exit 2
}

# mkworld CONTEXT-HOST|none: the shims in $T/bin, the wrapper with its placeholders filled in at $T/lazydocker
#   docker            `context inspect --format ... ` prints $T/ctx-host (or fails when it says none)
#   socat             logs its arguments, makes the socket that its first argument names (UNIX-LISTEN:<path>,...) and stays up
#   lazydocker (real) logs DOCKER_HOST, DOCKER_CONTEXT and the arguments, whether the bridge is up, and exits with $FAKE_LD_RC
mkworld() {
  mkdir -p "$T/bin"
  # a short runtime directory: a unix socket path is limited to 104 bytes on macOS, and $T is longer than that
  RUN=$(mktemp -d /tmp/ldrun.XXXXXX)
  printf '%s' "$1" >"$T/ctx-host"
  cat >"$T/bin/docker" <<EOF
#!/bin/sh
printf 'docker %s\n' "\$*" >>"$T/calls.log"
[ "\$1 \$2" = "context inspect" ] || exit 99
[ "\$(cat "$T/ctx-host")" != none ] || { echo "no such context" >&2; exit 1; }
cat "$T/ctx-host"
EOF
  cat >"$T/bin/socat" <<EOF
#!/bin/sh
printf 'socat %s\n' "\$*" >>"$T/calls.log"
printf '%s\n' "\$\$" >"$T/socat.pid"
[ -z "\${FAKE_SOCAT_SAYS:-}" ] || echo "\$FAKE_SOCAT_SAYS" >&2
sock=\${1#UNIX-LISTEN:}
sock=\${sock%%,*}
[ "\${FAKE_SOCAT_NO_SOCKET:-}" = 1 ] && exec sleep 30
printf 'dirmode %s\n' "\$("$PY3" -c 'import os, sys; print(oct(os.stat(os.path.dirname(sys.argv[1])).st_mode & 0o777)[2:])' "\$sock")" >>"$T/calls.log"
exec "$PY3" -c 'import socket, sys, time
s = socket.socket(socket.AF_UNIX); s.bind(sys.argv[1]); s.listen(1); time.sleep(30)' "\$sock"
EOF
  cat >"$T/bin/ssh" <<EOF
#!/bin/sh
printf 'ssh %s\n' "\$*" >>"$T/calls.log"
exit 99
EOF
  cat >"$T/bin/lazydocker-real" <<EOF
#!/bin/sh
printf 'lazydocker DOCKER_HOST=%s DOCKER_CONTEXT=%s ARGS=%s\n' "\${DOCKER_HOST-unset}" "\${DOCKER_CONTEXT-unset}" "\$*" >>"$T/calls.log"
case "\${DOCKER_HOST-}" in unix://$RUN/*) [ -S "\${DOCKER_HOST#unix://}" ] && echo "bridge up" >>"$T/calls.log" || echo "bridge MISSING" >>"$T/calls.log" ;; esac
exit "\${FAKE_LD_RC:-0}"
EOF
  chmod +x "$T/bin/"*
  sed -e "s#@lazydocker@#$T/bin/lazydocker-real#" -e "s#@docker@#$T/bin/docker#" -e "s#@socat@#$T/bin/socat#" -e "s#@ssh@#$T/bin/ssh#" "$SCRIPT" >"$T/lazydocker"
  : >"$T/calls.log"
}
# run [ENV...] -- ARGS...: the wrapper, with a runtime directory of its own; prints the exit status
wrap() {
  local -a envs=()
  while [ $# -gt 0 ] && [ "$1" != -- ]; do
    envs+=("$1")
    shift
  done
  shift
  env -u DOCKER_HOST -u DOCKER_CONTEXT XDG_RUNTIME_DIR="$RUN" LAZYDOCKER_SSH_WAIT=3 ${envs[@]+"${envs[@]}"} bash "$T/lazydocker" "$@" >"$T/out" 2>"$T/err"
  echo $?
}
bye() { rm -rf "$RUN"; }
bridge_dirs() { find "$RUN" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' '; }
alive() { [ -f "$T/socat.pid" ] && kill -0 "$(cat "$T/socat.pid")" 2>/dev/null && echo yes || echo no; }

test_a_local_context_goes_straight_to_lazydocker() {
  mkworld unix:///run/user/1000/docker.sock
  assert_rc "wrap" "$(wrap -- --debug)" 0
  assert_eq "docker was asked for the context, then lazydocker ran as it is" "docker context inspect --format {{.Endpoints.docker.Host}}
lazydocker DOCKER_HOST=unset DOCKER_CONTEXT=unset ARGS=--debug" "$(cat "$T/calls.log")"
  bye
}

test_a_docker_host_of_the_user_is_lazydockers_business() {
  mkworld ssh://jumphost_server
  assert_rc "wrap" "$(wrap DOCKER_HOST=unix:///elsewhere.sock -- )" 0
  assert_eq "no question, no bridge" "lazydocker DOCKER_HOST=unix:///elsewhere.sock DOCKER_CONTEXT=unset ARGS=" "$(cat "$T/calls.log")"
  bye
}

test_an_ssh_context_gets_a_bridge_and_lazydocker_a_socket_and_both_are_cleaned_up() {
  mkworld ssh://jumphost_server
  assert_rc "wrap" "$(wrap -- --config)" 0
  assert_has "socat listens on a socket in the runtime directory, for connections that fork" "$T/calls.log" "socat UNIX-LISTEN:$RUN/lazydocker-ssh."
  local exec_arg
  exec_arg=$(grep -o 'EXEC:.*' "$T/calls.log" | head -n 1)
  # socat splits an address at every ':' that is not escaped (real socat: "wrong number of parameters" for a plain ssh://host)
  assert_eq "no colon of the ssh:// host is left unescaped in the EXEC command line" 0 "$(python3 -c 'import re,sys; print(len(re.findall(r"(?<!\\):", sys.argv[1])))' "${exec_arg#EXEC:}")"
  assert_has "the bridge directory is mode 700 (nobody else reaches the socket)" "$T/calls.log" "dirmode 700"
  assert_has "mode 600, fork" "$T/calls.log" "/docker.sock,mode=600,fork"
  assert_has "each connection runs ssh to the host, which runs dial-stdio (the stream of the docker CLI)" "$T/calls.log" "EXEC:$T/bin/ssh -o BatchMode=yes -- ssh\\://jumphost_server docker system dial-stdio"
  assert_has "lazydocker got the socket" "$T/calls.log" "lazydocker DOCKER_HOST=unix://$RUN/lazydocker-ssh."
  assert_has "its arguments" "$T/calls.log" "ARGS=--config"
  assert_has "the socket was up when it started" "$T/calls.log" "bridge up"
  assert_eq "the bridge directory is gone" 0 "$(bridge_dirs)"
  assert_eq "socat is gone" no "$(alive)"
  assert_eq "ssh itself was not run by the wrapper" 0 "$(grep -c '^ssh ' "$T/calls.log")"
  bye
}

test_the_context_of_the_environment_is_the_one_asked_about() {
  mkworld ssh://jumphost_server
  assert_rc "wrap" "$(wrap DOCKER_CONTEXT=jumphost -- )" 0
  assert_has "docker context inspect has no name: it takes DOCKER_CONTEXT and the current context itself" "$T/calls.log" "docker context inspect --format {{.Endpoints.docker.Host}}"
  assert_has "DOCKER_CONTEXT reaches lazydocker unchanged" "$T/calls.log" "DOCKER_CONTEXT=jumphost"
  bye
}

test_lazydockers_exit_status_comes_back_and_the_bridge_is_cleaned_up_then_too() {
  mkworld ssh://jumphost_server
  assert_rc "wrap" "$(wrap FAKE_LD_RC=7 -- )" 7
  assert_eq "the bridge directory is gone" 0 "$(bridge_dirs)"
  assert_eq "socat is gone" no "$(alive)"
  bye
}

test_an_unknown_context_goes_to_lazydocker_which_says_so() {
  mkworld none
  assert_rc "wrap" "$(wrap -- )" 0
  assert_eq "no bridge" 0 "$(grep -c '^socat' "$T/calls.log")"
  assert_has "lazydocker ran" "$T/calls.log" "lazydocker DOCKER_HOST=unset"
  bye
}

test_what_the_bridge_said_is_shown_at_the_end_whatever_the_status_and_nothing_when_it_said_nothing() {
  mkworld ssh://jumphost_server
  assert_rc "lazydocker fails" "$(wrap FAKE_LD_RC=3 FAKE_SOCAT_SAYS='Permission denied (publickey).' -- )" 3
  assert_has "the bridge's words are shown" "$T/err" "Permission denied (publickey)."
  assert_has "and said to be the bridge's" "$T/err" "the bridge said"
  assert_rc "lazydocker ends well" "$(wrap FAKE_SOCAT_SAYS='Host key verification failed.' -- )" 0
  assert_has "the words are shown too (lazydocker does not exit when it cannot connect)" "$T/err" "Host key verification failed."
  assert_rc "the bridge said nothing" "$(wrap -- )" 0
  assert_lacks "nothing is shown" "$T/err" "the bridge said"
  assert_rc "no bridge" "$(wrap FAKE_SOCAT_NO_SOCKET=1 FAKE_SOCAT_SAYS='Network is unreachable.' -- )" 1
  assert_has "words of a bridge that never came up are shown" "$T/err" "Network is unreachable."
  bye
}

test_a_bridge_that_never_comes_up_is_an_error_and_leaves_nothing() {
  mkworld ssh://jumphost_server
  assert_rc "wrap" "$(wrap FAKE_SOCAT_NO_SOCKET=1 -- )" 1
  assert_has "says what failed" "$T/err" "bridge"
  assert_eq "lazydocker never ran" 0 "$(grep -c '^lazydocker' "$T/calls.log")"
  assert_eq "the bridge directory is gone" 0 "$(bridge_dirs)"
  bye
}

tl_init_pure
tl_run_all
tl_done
