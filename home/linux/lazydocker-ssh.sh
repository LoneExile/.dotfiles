#!/usr/bin/env bash
# lazydocker for a docker context that is ssh:// (the wrapper that home/linux/agent.nix puts in front of lazydocker when the jumphost
# piece is on; the @...@ names are filled in by Nix).
#
# lazydocker (0.24.2 and master) reaches an ssh:// host by `ssh -L <local socket>:/var/run/docker.sock <host> -N`. That needs socket
# forwarding, and the key that the VM uses for the jumphost is restricted to `docker system dial-stdio` (restrict: no forwarding, no
# shell, no pty), so that way is closed on purpose. The docker CLI itself talks to an ssh:// host through `ssh <host> docker system
# dial-stdio`, which that key allows. So, for an ssh:// context, this wrapper runs a local unix-socket bridge for the life of lazydocker:
# socat listens on a socket in the runtime directory and runs the same ssh command for each connection, and lazydocker is started with
# DOCKER_HOST set to that socket. Any other context, and any DOCKER_HOST of the user, go straight to lazydocker, which knows them.
# A bridge is no more than the key allows: the Docker API of that host, as the user of the key.
real=@lazydocker@
docker=@docker@
socat=@socat@
ssh=@ssh@

[ -z "${DOCKER_HOST:-}" ] || exec "$real" "$@"
# No name: the current context, DOCKER_CONTEXT first, as `docker` itself resolves it. Nothing contacts a daemon.
host=$("$docker" context inspect --format '{{.Endpoints.docker.Host}}' 2>/dev/null) || host=
case $host in
  ssh://*) ;;
  *) exec "$real" "$@" ;;
esac

wait=${LAZYDOCKER_SSH_WAIT:-8}
dir=$(mktemp -d "${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/lazydocker-ssh.XXXXXX") || {
  echo "lazydocker: cannot make a directory for the ssh bridge" >&2
  exit 1
}
bridge=
# shellcheck disable=SC2329 # run by the EXIT trap below
cleanup() {
  bridge_said
  [ -z "$bridge" ] || kill "$bridge" 2>/dev/null
  rm -rf "$dir"
}
# what socat and the ssh of the bridge said on stderr (their last lines), shown when the wrapper ends however it ends: lazydocker does not
# exit when it cannot connect, and the usual first failure is a refused key or a changed host key. A clean session says nothing here.
# shellcheck disable=SC2329 # run by cleanup, which the EXIT trap runs
bridge_said() {
  [ -s "$dir/bridge.log" ] || return 0
  echo "lazydocker: the bridge said:" >&2
  tail -n 5 "$dir/bridge.log" >&2
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM HUP

# socat splits an address at every ':' (measured: "wrong number of parameters" for ssh://host), so the colons of the URL are escaped for it
target=${host//:/\\:}
"$socat" "UNIX-LISTEN:$dir/docker.sock,mode=600,fork" "EXEC:$ssh -o BatchMode=yes -- $target docker system dial-stdio" >/dev/null 2>"$dir/bridge.log" &
bridge=$!
for _ in $(seq 1 $((wait * 10))); do
  [ -S "$dir/docker.sock" ] && break
  kill -0 "$bridge" 2>/dev/null || break
  sleep 0.1
done
if [ ! -S "$dir/docker.sock" ]; then
  echo "lazydocker: the bridge to $host did not come up (socat, then ssh $host docker system dial-stdio)" >&2
  exit 1
fi
DOCKER_HOST=unix://$dir/docker.sock "$real" "$@"
exit $?
