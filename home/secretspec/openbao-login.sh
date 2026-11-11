#!/usr/bin/env bash
# Keycloak SSO login to https://openbao.home.0dl.me, writing ~/.vault-token.
#
# macOS Local Network privacy blocks third-party binaries (bao) from 10.0.10.0/24
# and returns "no route to host" with no prompt. /usr/bin/ssh is exempt. When the
# direct dial is refused, forward 443 through pxc_root and a loopback CONNECT
# proxy so the HTTP Host and TLS name stay openbao.home.0dl.me.
set -euo pipefail

ADDR=https://openbao.home.0dl.me
SSH_HOST=${OPENBAO_LOGIN_SSH:-pxc_root}
REMOTE_HOST=10.0.10.212
REMOTE_PORT=443

err=$(mktemp)
ssh_pid=
proxy_pid=
proxy_py=

cleanup() {
  [[ -n $ssh_pid ]] && kill "$ssh_pid" 2>/dev/null || true
  [[ -n $proxy_pid ]] && kill "$proxy_pid" 2>/dev/null || true
  [[ -n $proxy_py ]] && rm -f "$proxy_py"
  rm -f "$err"
}
trap cleanup EXIT

if BAO_ADDR=$ADDR bao status >/dev/null 2>"$err"; then
  BAO_ADDR=$ADDR bao login -method=oidc -path=oidc
  exit 0
fi

if ! grep -q "no route to host" "$err"; then
  cat "$err" >&2
  exit 1
fi

echo "bao cannot dial ${REMOTE_HOST} from this app. Forwarding via ${SSH_HOST}." >&2

fwd_port=$(/usr/bin/python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1]); s.close()')
proxy_port=$(/usr/bin/python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1]); s.close()')

/usr/bin/ssh -N \
  -o ExitOnForwardFailure=yes \
  -o BatchMode=yes \
  -o ServerAliveInterval=30 \
  -o ConnectTimeout=8 \
  -L "127.0.0.1:${fwd_port}:${REMOTE_HOST}:${REMOTE_PORT}" \
  "$SSH_HOST" &
ssh_pid=$!

ready=0
for _ in $(seq 1 50); do
  if /usr/bin/nc -z -G 1 127.0.0.1 "$fwd_port" 2>/dev/null; then
    ready=1
    break
  fi
  if ! kill -0 "$ssh_pid" 2>/dev/null; then
    echo "ssh forward to ${SSH_HOST} exited before it listened" >&2
    exit 1
  fi
  sleep 0.1
done
[[ $ready -eq 1 ]] || { echo "ssh forward to ${SSH_HOST} did not listen" >&2; exit 1; }

proxy_py=$(mktemp)
cat >"$proxy_py" << 'PY'
import select, socket, sys, threading

listen_port = int(sys.argv[1])
upstream_port = int(sys.argv[2])
allowed = {("openbao.home.0dl.me", "443"), ("10.0.10.212", "443")}

def relay(client):
    up = None
    try:
        data = b""
        client.settimeout(15)
        while b"\r\n\r\n" not in data:
            chunk = client.recv(4096)
            if not chunk:
                return
            data += chunk
            if len(data) > 8192:
                return
        line = data.split(b"\r\n", 1)[0].decode("ascii", "replace")
        parts = line.split()
        if len(parts) < 2 or parts[0] != "CONNECT":
            client.sendall(b"HTTP/1.1 405 Method Not Allowed\r\nContent-Length: 0\r\n\r\n")
            return
        host, sep, port = parts[1].rpartition(":")
        if not sep or (host, port) not in allowed:
            client.sendall(b"HTTP/1.1 403 Forbidden\r\nContent-Length: 0\r\n\r\n")
            return
        up = socket.create_connection(("127.0.0.1", upstream_port), timeout=10)
        client.sendall(b"HTTP/1.1 200 Connection Established\r\n\r\n")
        rest = data.split(b"\r\n\r\n", 1)[1]
        if rest:
            up.sendall(rest)
        client.settimeout(None)
        up.settimeout(None)
        pair = [client, up]
        while True:
            ready, _, _ = select.select(pair, [], [], 120)
            if not ready:
                return
            for sock in ready:
                other = up if sock is client else client
                buf = sock.recv(65536)
                if not buf:
                    return
                other.sendall(buf)
    except Exception:
        return
    finally:
        for sock in (client, up):
            if sock is not None:
                try:
                    sock.close()
                except Exception:
                    pass

srv = socket.socket()
srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
srv.bind(("127.0.0.1", listen_port))
srv.listen(16)
while True:
    conn, _ = srv.accept()
    threading.Thread(target=relay, args=(conn,), daemon=True).start()
PY

/usr/bin/python3 "$proxy_py" "$proxy_port" "$fwd_port" &
proxy_pid=$!

ready=0
for _ in $(seq 1 50); do
  if /usr/bin/nc -z -G 1 127.0.0.1 "$proxy_port" 2>/dev/null; then
    ready=1
    break
  fi
  sleep 0.1
done
[[ $ready -eq 1 ]] || { echo "local proxy did not listen" >&2; exit 1; }

if ! HTTPS_PROXY="http://127.0.0.1:${proxy_port}" \
  NO_PROXY="127.0.0.1,localhost,::1" \
  BAO_ADDR=$ADDR \
  bao status >/dev/null; then
  echo "forwarded OpenBao status failed" >&2
  exit 1
fi

HTTPS_PROXY="http://127.0.0.1:${proxy_port}" \
  NO_PROXY="127.0.0.1,localhost,::1" \
  BAO_ADDR=$ADDR \
  bao login -method=oidc -path=oidc
