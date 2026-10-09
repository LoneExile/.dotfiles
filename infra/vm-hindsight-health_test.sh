#!/usr/bin/env bash
# Tests for infra/vm-hindsight-health.py: the check that vm-sync runs on the Mac before it pushes
# a Hindsight key to a VM (GET <url>/health with the bearer key: 200 or no push). The server is a
# real local HTTPS server (python's ssl, a throwaway self-signed certificate for 127.0.0.1, trusted
# through SSL_CERT_FILE), so the script's own TLS, header and redirect handling is what runs.
# Fixtures only: a fixture key, loopback.
set -uo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../home/secretspec/testlib.sh
. "$ROOT/home/secretspec/testlib.sh" || exit 1

for c in openssl python3; do
  command -v "$c" >/dev/null || {
    echo "$c not found on PATH" >&2
    exit 2
  }
done

CHECK=$ROOT/infra/vm-hindsight-health.py
KEY=fixture0hstoken0123456789abcdefABCD
OTHER=fixture0hstoken0other0123456789ABCD

# start_server: an HTTPS server on 127.0.0.1 in $T/srv; sets URL. Mode (a file): ok (default), redirect, error.
start_server() {
  local i
  mkdir -p "$T/srv"
  printf '%s' "$KEY" >"$T/srv/want"
  cat >"$T/srv/san.cnf" <<'EOF'
[req]
distinguished_name=dn
x509_extensions=v3
prompt=no
[dn]
CN=localhost
[v3]
subjectAltName=DNS:localhost,IP:127.0.0.1
EOF
  cat >"$T/srv/server.py" <<'EOF'
import hashlib, http.server, os, ssl, sys, time
d = sys.argv[1]
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        mode = open(d + "/mode").read().strip() if os.path.exists(d + "/mode") else "ok"
        auth = self.headers.get("Authorization", "")
        with open(d + "/server.log", "a") as f:
            f.write("GET %s auth=%s\n" % (self.requestline.split(" ")[1], hashlib.sha256(auth.encode()).hexdigest()[:12]))
        if mode == "redirect":
            self.send_response(302)
            self.send_header("Location", "https://127.0.0.1:%d/health" % self.server.server_port)
            self.end_headers()
            return
        if mode == "error":
            self.send_response(500)
            self.end_headers()
            return
        want = open(d + "/want").read().strip()
        self.send_response(200 if auth == "Bearer " + want else 401)
        self.end_headers()
        self.wfile.write(b"{}")
    def log_message(self, *a):
        pass
ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
ctx.load_cert_chain(d + "/c.pem", d + "/k.pem")
srv = http.server.HTTPServer(("127.0.0.1", 0), H)
srv.socket = ctx.wrap_socket(srv.socket, server_side=True)
open(d + "/port", "w").write(str(srv.server_port))
srv.timeout = 1
end = time.time() + 120
while time.time() < end:
    srv.handle_request()
EOF
  openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes -keyout "$T/srv/k.pem" -out "$T/srv/c.pem" -days 2 -config "$T/srv/san.cnf" >/dev/null 2>&1
  : >"$T/srv/server.log"
  python3 "$T/srv/server.py" "$T/srv" >"$T/srv/stdout" 2>&1 &
  echo $! >"$T/srv/pid"
  for i in $(seq 1 100); do
    [ -s "$T/srv/port" ] && break
    sleep 0.1
  done
  URL=https://127.0.0.1:$(cat "$T/srv/port" 2>/dev/null || echo 1)
}

# hc URL KEY: the check with URL and KEY on stdin, the server's certificate trusted.
hc() {
  printf '%s\n%s\n' "$1" "$2" | SSL_CERT_FILE="$T/srv/c.pem" SSL_CERT_DIR="" python3 "$CHECK" >"$T/out" 2>"$T/err"
  echo $?
}

test_answer_200_for_the_right_key_passes_and_the_request_is_a_bearer_get_of_health() {
  start_server
  assert_rc "check" "$(hc "$URL" "$KEY")" 0
  assert_eq "one request" 1 "$(wc -l <"$T/srv/server.log" | tr -d ' ')"
  assert_has "a GET of /health with the bearer key" "$T/srv/server.log" "GET /health auth=$(printf 'Bearer %s' "$KEY" | shasum -a 256 | cut -c1-12)"
  assert_lacks "the key is not in stdout" "$T/out" "$KEY"
  assert_lacks "the key is not in stderr" "$T/err" "$KEY"
}

test_a_trailing_slash_or_a_path_prefix_gives_one_health_path() {
  start_server
  assert_rc "trailing slash" "$(hc "$URL/" "$KEY")" 0
  assert_rc "path prefix" "$(hc "$URL/api" "$KEY")" 0
  assert_has "no double slash" "$T/srv/server.log" "GET /health auth="
  assert_has "prefix kept" "$T/srv/server.log" "GET /api/health auth="
  assert_lacks "never //health" "$T/srv/server.log" "GET //health"
}

test_answer_401_fails_and_says_the_status_without_the_key() {
  start_server
  assert_rc "wrong key" "$(hc "$URL" "$OTHER")" 1
  assert_has "says 401" "$T/err" "401"
  assert_lacks "stderr hides the wrong key" "$T/err" "$OTHER"
  assert_lacks "stdout hides the wrong key" "$T/out" "$OTHER"
  assert_lacks "stderr hides the right key" "$T/err" "$KEY"
}

test_other_answers_fail() {
  start_server
  printf 'error' >"$T/srv/mode"
  assert_rc "500" "$(hc "$URL" "$KEY")" 1
  assert_has "says 500" "$T/err" "500"
}

test_a_redirect_is_not_followed_and_fails() {
  start_server
  printf 'redirect' >"$T/srv/mode"
  assert_rc "redirect" "$(hc "$URL" "$KEY")" 1
  assert_has "says 302" "$T/err" "302"
  assert_eq "the key was sent once, to the first address only" 1 "$(wc -l <"$T/srv/server.log" | tr -d ' ')"
}

test_an_unreachable_gate_fails_without_the_key() {
  start_server
  local port=$(cat "$T/srv/port")
  kill "$(cat "$T/srv/pid")" 2>/dev/null
  sleep 1.5
  assert_rc "connection refused" "$(hc "https://127.0.0.1:$port" "$KEY")" 1
  assert_has "says it could not reach the gate" "$T/err" "could not reach"
  assert_lacks "stderr hides the key" "$T/err" "$KEY"
}

test_a_certificate_that_is_not_trusted_fails_before_the_key_is_sent() {
  start_server
  # no SSL_CERT_FILE: the system store does not know the throwaway certificate
  printf '%s\n%s\n' "$URL" "$KEY" | SSL_CERT_FILE="" SSL_CERT_DIR="" python3 "$CHECK" >"$T/out" 2>"$T/err"
  assert_eq "check fails" 1 "$?"
  assert_has "says it could not reach the gate" "$T/err" "could not reach"
  assert_eq "no request reached the server" 0 "$(wc -l <"$T/srv/server.log" | tr -d ' ')"
}

test_a_proxy_in_the_environment_is_not_used() {
  start_server
  printf '%s\n%s\n' "$URL" "$KEY" | HTTPS_PROXY=http://127.0.0.1:9 https_proxy=http://127.0.0.1:9 ALL_PROXY=http://127.0.0.1:9 SSL_CERT_FILE="$T/srv/c.pem" SSL_CERT_DIR="" python3 "$CHECK" >"$T/out" 2>"$T/err"
  assert_eq "check passes" 0 "$?"
  assert_eq "the request went to the server itself" 1 "$(wc -l <"$T/srv/server.log" | tr -d ' ')"
}

test_a_url_that_is_not_https_is_refused_and_nothing_is_sent() {
  start_server
  assert_rc "http" "$(hc "http://127.0.0.1:$(cat "$T/srv/port")" "$KEY")" 2
  assert_rc "file" "$(hc "file:///etc/hosts" "$KEY")" 2
  assert_rc "no scheme" "$(hc "127.0.0.1" "$KEY")" 2
  assert_eq "nothing reached the server" 0 "$(wc -l <"$T/srv/server.log" | tr -d ' ')"
}

test_a_malformed_stdin_is_refused_and_nothing_is_sent() {
  start_server
  assert_rc "short key" "$(hc "$URL" "short")" 2
  assert_rc "key with a space" "$(hc "$URL" "has space in it 0123456789abcdef")" 2
  printf '%s\n' "$URL" | python3 "$CHECK" >"$T/out" 2>"$T/err"
  assert_eq "one line only" 2 "$?"
  printf '%s\n%s\nextra\n' "$URL" "$KEY" | python3 "$CHECK" >"$T/out" 2>"$T/err"
  assert_eq "three lines" 2 "$?"
  assert_eq "nothing reached the server" 0 "$(wc -l <"$T/srv/server.log" | tr -d ' ')"
}

test_the_check_takes_no_arguments() {
  start_server
  printf '%s\n%s\n' "$URL" "$KEY" | SSL_CERT_FILE="$T/srv/c.pem" SSL_CERT_DIR="" python3 "$CHECK" "$URL" >"$T/out" 2>"$T/err"
  assert_eq "an argument is refused (the URL and the key never go on a command line)" 2 "$?"
  assert_eq "nothing reached the server" 0 "$(wc -l <"$T/srv/server.log" | tr -d ' ')"
}

tl_init_pure
tl_run_all
tl_done
