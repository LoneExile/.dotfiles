#!/usr/bin/env bash
# Tests for kv.sh against a real `bao server -dev`: shapes, error classes,
# CAS semantics, env scrubbing, byte-exactness.
set -uo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=testlib.sh
. "$ROOT/testlib.sh" || exit 1
# shellcheck source=common.sh
. "$ROOT/common.sh" || exit 1
# shellcheck source=kv.sh
. "$ROOT/kv.sh" || exit 1

kv_ready() { # in-process kv session inside the sandbox
  in_sandbox
  work_init
  kv_init
}

test_read_latest_and_version() {
  kv_ready
  seed_s T1 $'alpha\n'
  seed_s T1 $'beta\n\n'
  kv_read T1
  assert_eq "latest class" "$KV_CLASS" ok
  assert_eq "latest version" "$KV_VERSION" 2
  assert_bytes "latest bytes keep both newlines" "$KV_VALUE" $'beta\n\n'
  assert_eq "latest sha" "$KV_SHA" "$(sha_of $'beta\n\n')"
  [[ $KV_CT =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:.]+Z$ ]] && ok "created_time is RFC3339" || bad "created_time is RFC3339" "$KV_CT"
  assert_eq "no writer on a seeded version" "$KV_WRITER" ""
  kv_read T1 1
  assert_eq "v1 class" "$KV_CLASS" ok
  assert_eq "v1 version" "$KV_VERSION" 1
  assert_bytes "v1 bytes" "$KV_VALUE" $'alpha\n'
}

test_write_then_read_back_is_byte_exact() {
  kv_ready
  local i=0 v
  local -a cases=('abc' $'abc\n' $'abc\n\n' $'abc\n\n\n' $'-abc\n' $'--x=y\n\n' $'\n' $'caf\xc3\xa9 \xe2\x82\xac\n' $'a\r\nb\r\n' $'k=v\n\n\n')
  for v in "${cases[@]}"; do
    i=$((i + 1))
    printf '%s' "$v" >"$T/in.$i"
    kv_pushable "$T/in.$i" || bad "case $i pushable" "$KV_REFUSE"
    kv_write "B$i" 0 "$T/in.$i"
    assert_eq "case $i write class" "$KV_CLASS" ok
    assert_eq "case $i new version" "$KV_NEWVERSION" 1
    kv_read "B$i" "$KV_NEWVERSION"
    assert_bytes "case $i read-back" "$KV_VALUE" "$v"
    echo "B$i" >>"$TL_TMP/touched"
  done
}

test_writer_field_is_the_local_host_name() {
  kv_ready
  printf 'x' >"$T/in"
  kv_write W1 0 "$T/in"
  kv_read W1
  assert_eq "writer" "$KV_WRITER" "$(/usr/sbin/scutil --get LocalHostName)"
  echo W1 >>"$TL_TMP/touched"
}

test_missing_kinds() {
  kv_ready
  kv_read NOPE
  assert_eq "absent class" "$KV_CLASS" missing
  assert_eq "absent kind" "$KV_MISSING" absent
  assert_eq "absent version" "$KV_VERSION" 0

  seed_s DEL one
  seed_s DEL two
  ba kv delete -mount=secret "$TL_SECRET_PREFIX/DEL" >/dev/null
  kv_read DEL
  assert_eq "soft-deleted class" "$KV_CLASS" missing
  assert_eq "soft-deleted kind" "$KV_MISSING" deleted
  assert_eq "soft-deleted version is the current one" "$KV_VERSION" 2

  seed_s DES one
  seed_s DES two
  ba kv destroy -mount=secret -versions=2 "$TL_SECRET_PREFIX/DES" >/dev/null
  kv_read DES
  assert_eq "destroyed class" "$KV_CLASS" missing
  assert_eq "destroyed kind" "$KV_MISSING" destroyed
  assert_eq "destroyed version" "$KV_VERSION" 2

  seed_s EMP ''
  kv_read EMP
  assert_eq "empty value class" "$KV_CLASS" missing
  assert_eq "empty value kind" "$KV_MISSING" empty
  assert_eq "empty value version" "$KV_VERSION" 1

  printf '{"data":{"other":"x"}}' | ba write -format=json "secret/data/$TL_SECRET_PREFIX/NOV" - >/dev/null
  echo NOV >>"$TL_TMP/touched"
  kv_read NOV
  assert_eq "no value field class" "$KV_CLASS" missing
  assert_eq "no value field kind" "$KV_MISSING" no-value
}

test_pruned_and_deleted_versions_in_metadata() {
  kv_ready
  ba kv metadata put -mount=secret -max-versions=3 "$TL_SECRET_PREFIX/PR" >/dev/null
  local i
  for i in 1 2 3 4 5; do seed_s PR "v$i"; done
  kv_read PR 1
  assert_eq "pruned version reads as missing" "$KV_CLASS" missing
  kv_read PR 3
  assert_eq "retained version reads" "$KV_CLASS" ok
  kv_meta PR
  assert_eq "meta class" "$KV_CLASS" ok
  assert_eq "current_version" "$KV_CUR" 5
  assert_eq "live versions newest first" "$(kv_meta_live_versions | tr '\n' ' ')" "5 4 3 "
  assert_eq "pruned version has no created_time" "$(kv_meta_ct 1)" ""
  assert_eq "retained version has a created_time" "$([[ -n $(kv_meta_ct 4) ]] && echo yes)" yes

  seed_s DV one
  seed_s DV two
  seed_s DV three
  ba kv delete -mount=secret -versions=2 "$TL_SECRET_PREFIX/DV" >/dev/null
  ba kv destroy -mount=secret -versions=1 "$TL_SECRET_PREFIX/DV" >/dev/null
  kv_meta_reset
  kv_meta DV
  assert_eq "deleted and destroyed versions are not live" "$(kv_meta_live_versions | tr '\n' ' ')" "3 "
  assert_eq "deleted version keeps its created_time" "$([[ -n $(kv_meta_ct 2) ]] && echo yes)" yes
  kv_meta NOPE
  assert_eq "meta of a missing path" "$KV_CLASS" missing
}

test_cas_semantics() {
  kv_ready
  printf 'one' >"$T/a"
  printf 'two' >"$T/b"
  printf 'three' >"$T/c"
  echo CAS >>"$TL_TMP/touched"
  kv_write CAS 0 "$T/a"
  assert_eq "create with cas 0" "$KV_CLASS/$KV_NEWVERSION" ok/1
  kv_write CAS 0 "$T/b"
  assert_eq "cas 0 on an existing path" "$KV_CLASS" cas
  kv_write CAS 5 "$T/b"
  assert_eq "stale cas" "$KV_CLASS" cas
  kv_write CAS 1 "$T/b"
  assert_eq "cas = current version" "$KV_CLASS/$KV_NEWVERSION" ok/2

  ba kv delete -mount=secret "$TL_SECRET_PREFIX/CAS" >/dev/null
  kv_write CAS 0 "$T/c"
  assert_eq "soft-deleted: cas 0 fails" "$KV_CLASS" cas
  kv_write CAS 2 "$T/c"
  assert_eq "soft-deleted: cas = current_version works" "$KV_CLASS/$KV_NEWVERSION" ok/3

  ba kv destroy -mount=secret -versions=3 "$TL_SECRET_PREFIX/CAS" >/dev/null
  kv_write CAS 0 "$T/a"
  assert_eq "destroyed: cas 0 fails" "$KV_CLASS" cas
  kv_write CAS 3 "$T/a"
  assert_eq "destroyed: cas = current_version works" "$KV_CLASS/$KV_NEWVERSION" ok/4

  ba kv metadata delete -mount=secret "$TL_SECRET_PREFIX/CAS" >/dev/null
  kv_write CAS 4 "$T/b"
  assert_eq "metadata deleted: old cas fails" "$KV_CLASS" cas
  kv_write CAS 0 "$T/b"
  assert_eq "metadata deleted: cas 0 restarts at version 1" "$KV_CLASS/$KV_NEWVERSION" ok/1
}

test_cas_required_rejects_plain_writes_but_not_ours() {
  kv_ready
  printf 'one' >"$T/a"
  echo CR >>"$TL_TMP/touched"
  kv_write CR 0 "$T/a"
  ba kv metadata patch -mount=secret -cas-required=true "$TL_SECRET_PREFIX/CR" >/dev/null
  printf '{"data":{"value":"plain"}}' | ba write -format=json "secret/data/$TL_SECRET_PREFIX/CR" - >"$T/o" 2>"$T/e"
  assert_rc "plain write under cas_required" "$?" 2
  assert_has "plain write error text" "$T/e" "check-and-set parameter required"
  kv_classify 2 "$T/e"
  assert_eq "that error classifies as cas" "$KV_CLASS" cas
  kv_write CR 1 "$T/a"
  assert_eq "our write carries cas" "$KV_CLASS/$KV_NEWVERSION" ok/2
}

test_pushable_refuses_empty_and_non_utf8() {
  kv_ready
  : >"$T/empty"
  kv_pushable "$T/empty" && bad "empty is refused" || assert_eq "empty is refused" "$KV_REFUSE" empty
  printf 'a\xffb\n' >"$T/ff"
  kv_pushable "$T/ff" && bad "0xff is refused" || assert_eq "0xff is refused" "$KV_REFUSE" not-utf8
  printf '\xc3\x28' >"$T/c3"
  kv_pushable "$T/c3" && bad "bad sequence is refused" || assert_eq "bad sequence is refused" "$KV_REFUSE" not-utf8
  printf 'a\x00b\n' >"$T/nul"
  kv_pushable "$T/nul" && ok "NUL byte survives" || bad "NUL byte survives" "$KV_REFUSE"
  printf '\n' >"$T/nl"
  kv_pushable "$T/nl" && ok "a lone newline is pushable" || bad "a lone newline is pushable" "$KV_REFUSE"
}

# Error texts. Captured live from bao 2.6.2 and 2.7.0: 403, sealed (503), both
# check-and-set errors, connection refused, no such host, deadline exceeded,
# x509, and http-to-https in both directions. Captured from a fake HTTP server
# (bao's own `Code: NNN. Errors:` layout): 401, 429, 500, 502, 504. The "network
# is unreachable" line is the standard Go error text, not captured.
test_classify_table() {
  kv_ready
  local n=0 want rc text
  while IFS='|' read -r want rc text; do
    n=$((n + 1))
    printf '%b' "$text" >"$T/err.$n"
    kv_classify "$rc" "$T/err.$n"
    assert_eq "classify #$n ($want)" "$KV_CLASS" "$want"
  done <<'EOF'
ok|0|
missing|2|No value found at secret/data/secretspec/dotfiles/default/NOPE\n
missing|2|No value found at secret/metadata/secretspec/dotfiles/default/NOPE\n
soft|2|Error making API request.\n\nURL: PUT http://x/v1/secret/metadata/p\nCode: 404. Raw Message:\n
soft|2|Error making API request.\n\nURL: GET http://x/v1/secret/data/p\nCode: 404. Raw Message:\n
hard|2|Error making API request.\n\nURL: GET http://x/v1/sys/internal/ui/mounts/secret\nCode: 403. Errors:\n\n* permission denied\n
hard|2|Error making API request.\n\nURL: GET http://x/v1/sys/internal/ui/mounts/secret\nCode: 401. Errors:\n\n* missing client token\n
hard|2|Get "https://h/v1/sys/internal/ui/mounts/secret": tls: failed to verify certificate: x509: certificate is not trusted\n
hard|2|Get "https://h/v1/x": x509: certificate has expired or is not yet valid\n
cas|2|Error writing data to secret/data/p: Error making API request.\n\nURL: PUT http://x/v1/secret/data/p\nCode: 400. Errors:\n\n* check-and-set parameter did not match the current version\n
cas|2|Code: 400. Errors:\n\n* check-and-set parameter required for this call\n
soft|2|Error making API request.\n\nURL: GET http://x/v1/sys/internal/ui/mounts/secret\nCode: 503. Errors:\n\n* Vault is sealed\n
soft|2|Code: 500. Errors:\n\n* internal error\n
soft|2|Code: 502. Errors:\n\n* bad gateway\n
soft|2|Code: 504. Errors:\n\n* gateway timeout\n
soft|2|Code: 429. Errors:\n\n* rate limited\n
soft|2|Get "http://127.0.0.1:1/v1/sys/internal/ui/mounts/secret": dial tcp 127.0.0.1:1: connect: connection refused\n
soft|2|Get "https://nonexistent.invalid/v1/x": dial tcp: lookup nonexistent.invalid: no such host\n
soft|2|Get "http://10.255.255.1:8200/v1/x": dial tcp 10.255.255.1:8200: connect: network is unreachable\n
soft|2|context deadline exceeded\n
soft|2|Get "https://h/v1/x": http: server gave HTTP response to HTTPS client\n
soft|2|Code: 400. Raw Message:\n\nClient sent an HTTP request to an HTTPS server.\n
soft|2|Code: 400. Errors:\n\n* some other 400 without the cas marker\n
soft|1|something unexpected\n
EOF
}

# A 404 that is not OpenBao's "No value found at" (a gateway with no route, a
# wrong host) is not an answer from the vault. Only the metadata patch of
# enforce-cas, which prints a bare 404 for a missing path, opts in.
test_a_404_from_something_else_is_not_missing() {
  kv_ready
  printf 'Error making API request.\n\nURL: PUT http://x/v1/secret/metadata/p\nCode: 404. Raw Message:\n' >"$T/err.patch"
  kv_classify 2 "$T/err.patch"
  assert_eq "bare 404 by default" "$KV_CLASS" soft
  kv_classify 2 "$T/err.patch" 404=missing
  assert_eq "bare 404 when the caller opts in" "$KV_CLASS" missing
  printf 'Code: 503. Errors:\n\n* Vault is sealed\n' >"$T/err.sealed"
  kv_classify 2 "$T/err.sealed" 404=missing
  assert_eq "opt-in does not change other classes" "$KV_CLASS" soft
  srv404_spawn "$T/s404"
  SECRETSPEC_SYNC_ADDR=$(cat "$T/s404/addr")
  kv_init
  kv_read NOPE
  assert_eq "read class" "$KV_CLASS" soft
  assert_eq "read leaves no missing kind" "$KV_MISSING" ""
  kv_meta NOPE
  assert_eq "metadata class" "$KV_CLASS" soft
  SECRETSPEC_SYNC_ADDR=$S_ADDR
  kv_init
  kv_enforce_cas NO-SUCH-PATH
  assert_eq "enforce-cas on a real vault's missing path" "$KV_CLASS" missing
}

test_bad_token_is_hard() {
  kv_ready
  VAULT_TOKEN=bogus
  kv_init
  kv_read NOPE
  assert_eq "read class" "$KV_CLASS" hard
  assert_has "read error mentions the code" <(printf '%s' "$KV_ERR") "403"
  printf 'x' >"$T/in"
  kv_write NOPE 0 "$T/in"
  assert_eq "write class" "$KV_CLASS" hard
}

test_sealed_vault_is_soft() {
  kv_ready
  srv_spawn "$T/sealed"
  use_srv "$T/sealed"
  SECRETSPEC_SYNC_ADDR=$S_ADDR VAULT_TOKEN=$S_TOK
  kv_init
  ba operator seal >/dev/null
  kv_read X
  assert_eq "read class" "$KV_CLASS" soft
  assert_has "read error" <(printf '%s' "$KV_ERR") "sealed"
  printf 'x' >"$T/in"
  kv_write X 0 "$T/in"
  assert_eq "write class" "$KV_CLASS" soft
  kv_meta X
  assert_eq "metadata class" "$KV_CLASS" soft
  srv_stop "$T/sealed"
}

test_killed_server_is_soft() {
  kv_ready
  srv_spawn "$T/dead"
  use_srv "$T/dead"
  SECRETSPEC_SYNC_ADDR=$S_ADDR VAULT_TOKEN=$S_TOK
  kv_init
  kill -9 "$(cat "$T/dead/pid")"
  wait "$(cat "$T/dead/pid")" 2>/dev/null
  kv_read X
  assert_eq "read class" "$KV_CLASS" soft
  assert_has "read error" <(printf '%s' "$KV_ERR") "connection refused"
}

test_hanging_server_times_out_soft() {
  kv_ready
  python3 - "$T/port" <<'PY' &
import socket, sys, time
s = socket.socket()
s.bind(("127.0.0.1", 0))
s.listen(5)
open(sys.argv[1], "w").write(str(s.getsockname()[1]))
conns = []
while True:
    conns.append(s.accept()[0])
PY
  local hang=$!
  local i
  for i in $(seq 1 50); do [[ -s $T/port ]] && break; sleep 0.1; done
  SECRETSPEC_SYNC_ADDR=http://127.0.0.1:$(cat "$T/port") SECRETSPEC_SYNC_TIMEOUT=1s
  kv_init
  local t0=$SECONDS
  kv_read X
  local took=$((SECONDS - t0))
  kill "$hang" 2>/dev/null
  wait "$hang" 2>/dev/null
  assert_eq "class" "$KV_CLASS" soft
  [[ $took -le 5 ]] && ok "gave up after the timeout (${took}s)" || bad "timeout" "took ${took}s"
}

test_tls_failure_is_hard() {
  kv_ready
  srv_spawn "$T/tls" tls
  use_srv "$T/tls"
  SECRETSPEC_SYNC_ADDR=$S_ADDR VAULT_TOKEN=$S_TOK
  kv_init
  kv_read X
  assert_eq "untrusted certificate" "$KV_CLASS" hard
  assert_has "error text" <(printf '%s' "$KV_ERR") "x509"
}

test_stray_environment_cannot_redirect_a_call() {
  kv_ready
  seed_s ENVT value
  export BAO_NAMESPACE=ns1 VAULT_NAMESPACE=ns1 BAO_WRAP_TTL=60s VAULT_WRAP_TTL=60s
  export BAO_CACERT=/nonexistent VAULT_CACERT=/nonexistent BAO_CAPATH=/nonexistent
  export BAO_PROXY_ADDR=http://127.0.0.1:1 BAO_HTTP_PROXY=http://127.0.0.1:1
  export BAO_ADDR=http://127.0.0.1:1 VAULT_ADDR=http://127.0.0.1:1 BAO_TOKEN=bogus
  # Positive control: the same environment breaks an unscrubbed call.
  "$TL_BAO" kv get -format=json -mount=secret "$TL_SECRET_PREFIX/ENVT" >/dev/null 2>&1
  [[ $? -ne 0 ]] && ok "positive control: unscrubbed call fails" || bad "positive control" "unscrubbed call succeeded"
  kv_read ENVT
  assert_eq "scrubbed read class" "$KV_CLASS" ok
  assert_bytes "scrubbed read value" "$KV_VALUE" value
  kv_meta ENVT
  assert_eq "scrubbed metadata class" "$KV_CLASS" ok
}

test_token_sources_and_precedence() {
  kv_ready
  seed_s TOK value
  local good=$S_TOK
  printf '%s\n' "$good" >"$T_HOME/.vault-token"
  VAULT_TOKEN=bogus
  kv_init
  kv_read TOK
  assert_eq "VAULT_TOKEN wins over the token file" "$KV_CLASS" hard
  unset VAULT_TOKEN
  kv_init
  kv_read TOK
  assert_eq "token file used when VAULT_TOKEN is unset" "$KV_CLASS" ok
  VAULT_TOKEN=$good
  printf 'bogus\n' >"$T_HOME/.vault-token"
  kv_init
  kv_read TOK
  assert_eq "good VAULT_TOKEN beats a bad file" "$KV_CLASS" ok
  unset VAULT_TOKEN
  rm -f "$T_HOME/.vault-token"
  kv_init
  kv_read TOK
  assert_eq "no token at all" "$KV_CLASS" hard
  assert_has "says how to fix it" <(printf '%s' "$KV_ERR") "openbao-login"
}

test_no_value_in_argv() {
  kv_ready
  [[ $TL_SHIM_OK -eq 1 ]] || {
    skip "bao shim is bypassed under SS_ENGINE"
    return 0
  }
  local plant="PLANT-$RANDOM-$RANDOM-secret"
  printf '%s\n' "$plant" >"$T/in"
  kv_pushable "$T/in"
  kv_write ARGV 0 "$T/in"
  kv_read ARGV 1
  echo ARGV >>"$TL_TMP/touched"
  assert_eq "value round trip" "$KV_CLASS" ok
  assert_lacks "value never appears in a bao argv" "$T/bao.log" "$plant"
  assert_lacks "token never appears in a bao argv" "$T/bao.log" "$S_TOK"
  # Positive control: the log does catch a value passed in argv.
  bao kv put -mount=secret leak/x "v=$plant" >/dev/null 2>&1
  assert_has "positive control: argv log sees a leaky call" "$T/bao.log" "$plant"
  ba kv metadata delete -mount=secret leak/x >/dev/null 2>&1
}

tl_init
tl_run_all
tl_done
