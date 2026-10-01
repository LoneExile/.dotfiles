# testlib.sh: harness for the secret-sync tests. Sourced by *_test.sh files.
#
# One `bao server -dev` per test file, a fresh HOME / XDG_STATE_HOME per test.
# The real ~/.vault-token is never touched: servers run with
# -dev-no-store-token and a temp HOME, engines get a temp HOME, and tl_done
# fails the file when the token's hash or mtime changed. Contents are never
# read into output.
#
# A test is a function named test_*. It runs in a subshell with the helpers
# below; any failed assertion fails the test.

TL_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TL_BASH=${BASH:-bash}
TL_FAILED=0
TL_RAN=0
TL_SECRET_PREFIX=secretspec/dotfiles/default
TL_MAIN_SRV=""
TL_BAO=""

# The engine under test: SS_ENGINE (one executable, e.g. the nix wrapper) or
# materialize.sh run by the same bash that runs the tests.
if [[ -n ${SS_ENGINE:-} ]]; then
  TL_ENGINE=("$SS_ENGINE")
  TL_SHIM_OK=0 # the wrapper puts its own bao first on PATH
else
  TL_ENGINE=("$TL_BASH" "$TL_ROOT/materialize.sh")
  TL_SHIM_OK=1
fi

tl_mtime() { stat -c %Y "$1" 2>/dev/null || stat -f %m "$1"; }
tl_mode() { stat -c %a "$1" 2>/dev/null || stat -f %Lp "$1"; }

# Hash and mtime of the real token, never its content.
tl_fingerprint() {
  local f=$HOME/.vault-token
  if [[ -e $f ]]; then
    printf '%s %s\n' "$(shasum -a 256 <"$f" | cut -c1-64)" "$(tl_mtime "$f")"
  else
    echo absent
  fi
}

# srv_spawn DIR [tls]: start a dev server, write DIR/addr, DIR/token, DIR/pid.
srv_spawn() {
  local dir=$1 home tok port pid i try scheme=http cacert=""
  local -a tlsflags=()
  mkdir -p "$dir/home"
  home=$dir/home
  if [[ ${2:-} == tls ]]; then
    mkdir -p "$dir/tls"
    tlsflags=(-dev-tls "-dev-tls-cert-dir=$dir/tls")
    scheme=https
    cacert=$dir/tls/vault-ca.pem
  fi
  tok="t-$(od -An -N12 -tx1 /dev/urandom | tr -d ' \n')"
  for try in 1 2 3 4 5 6 7 8; do
    port=$((20000 + RANDOM % 30000))
    env -i HOME="$home" PATH="$PATH" "$TL_BAO" server -dev -dev-no-store-token ${tlsflags[@]+"${tlsflags[@]}"} \
      -dev-root-token-id="$tok" -dev-listen-address="127.0.0.1:$port" >"$dir/server.log" 2>&1 &
    pid=$!
    for i in $(seq 1 100); do
      kill -0 "$pid" 2>/dev/null || break
      if env -i HOME="$home" PATH="$PATH" BAO_ADDR="$scheme://127.0.0.1:$port" BAO_TOKEN="$tok" ${cacert:+BAO_CACERT="$cacert"} "$TL_BAO" token lookup >/dev/null 2>&1; then
        printf '%s://127.0.0.1:%s\n' "$scheme" "$port" >"$dir/addr"
        printf '%s\n' "$tok" >"$dir/token"
        printf '%s\n' "$pid" >"$dir/pid"
        return 0
      fi
      sleep 0.1
    done
    kill "$pid" 2>/dev/null
    wait "$pid" 2>/dev/null
  done
  return 1
}

srv_stop() {
  local pid
  pid=$(cat "$1/pid" 2>/dev/null) || return 0
  kill "$pid" 2>/dev/null
  wait "$pid" 2>/dev/null
  rm -f "$1/pid"
}

# use_srv DIR: point S_ADDR / S_TOK at that server.
use_srv() {
  S_ADDR=$(cat "$1/addr")
  S_TOK=$(cat "$1/token")
}

tl_cleanup() {
  local p
  if [[ -n ${TL_TMP:-} && -d $TL_TMP ]]; then
    for p in $(find "$TL_TMP" -name pid -type f 2>/dev/null); do
      kill "$(cat "$p")" 2>/dev/null || true
    done
    rm -rf "$TL_TMP"
  fi
}

tl_init() {
  TL_BAO=$(command -v bao) || {
    echo "bao not found on PATH" >&2
    exit 2
  }
  command -v jq >/dev/null || {
    echo "jq not found on PATH" >&2
    exit 2
  }
  TL_FP_BEFORE=$(tl_fingerprint)
  TL_TMP=$(mktemp -d "${TMPDIR:-/tmp}/ss-test.XXXXXX")
  trap tl_cleanup EXIT
  srv_spawn "$TL_TMP/srv" || {
    echo "could not start bao server -dev" >&2
    exit 2
  }
  TL_MAIN_SRV=$TL_TMP/srv
  use_srv "$TL_MAIN_SRV"
  : >"$TL_TMP/touched"
}

# tl_init_pure: for test files that never talk to a vault (no server).
tl_init_pure() {
  TL_FP_BEFORE=$(tl_fingerprint)
  TL_TMP=$(mktemp -d "${TMPDIR:-/tmp}/ss-test.XXXXXX")
  trap tl_cleanup EXIT
  : >"$TL_TMP/touched"
}

# ba ARGS...: bao as an admin client of the current server, scrubbed env.
ba() {
  env -i HOME="$TL_TMP/admin-home" PATH="$PATH" BAO_ADDR="$S_ADDR" BAO_TOKEN="$S_TOK" "$TL_BAO" "$@"
}

# tl_begin NAME: new sandbox for one test; forget what earlier tests seeded.
tl_begin() {
  local n pids
  mkdir -p "$TL_TMP/admin-home"
  if [[ -n $TL_MAIN_SRV ]]; then
    use_srv "$TL_MAIN_SRV"
    pids=""
    for n in $(sort -u "$TL_TMP/touched"); do
      ba kv metadata delete -mount=secret "$TL_SECRET_PREFIX/$n" >/dev/null 2>&1 &
      pids="$pids $!"
    done
    # Wait for these jobs only: a bare `wait` would also wait for the server.
    # shellcheck disable=SC2086
    [[ -z $pids ]] || wait $pids
  fi
  : >"$TL_TMP/touched"
  T=$(mktemp -d "$TL_TMP/t.XXXXXX")
  T_HOME=$T/home
  T_STATE=$T/state
  T_SHIM=$T/shim
  mkdir -p "$T_HOME" "$T/tmp" "$T_SHIM"
  # bao shim: logs every call's arguments, then runs the real bao.
  printf '#!/bin/sh\nprintf "%%s\\n" "$*" >>"%s/bao.log"\nexec "%s" "$@"\n' "$T" "$TL_BAO" >"$T_SHIM/bao"
  chmod +x "$T_SHIM/bao"
  : >"$T/bao.log"
  ENGINE_ENV=()
}

ok() { printf '  ok   %s\n' "$1"; }
bad() {
  printf '  FAIL %s%s\n' "$1" "${2:+: $2}"
  T_FAIL=1
}
skip() { printf '  skip %s\n' "$1"; }

assert_eq() {
  if [[ $2 == "$3" ]]; then ok "$1"; else bad "$1" "got $(printf %q "$2") want $(printf %q "$3")"; fi
}
assert_rc() { assert_eq "$1 (exit status)" "$2" "$3"; }
assert_has() { # label file needle
  if grep -qF -- "$3" "$2"; then ok "$1"; else bad "$1" "missing $(printf %q "$3") in $(basename "$2"): $(head -c 300 "$2" | tr '\n' '|')"; fi
}
assert_lacks() {
  if grep -qF -- "$3" "$2"; then bad "$1" "found $(printf %q "$3") in $(basename "$2")"; else ok "$1"; fi
}
# assert_bytes LABEL FILE WANT: FILE holds exactly the bytes of WANT.
assert_bytes() {
  printf '%s' "$3" >"$T/want.bytes"
  if [[ -f $2 ]] && cmp -s "$2" "$T/want.bytes"; then
    ok "$1"
  elif [[ ! -f $2 ]]; then
    bad "$1" "missing file $2"
  else
    bad "$1" "got $(wc -c <"$2" | tr -d ' ') bytes, want $(wc -c <"$T/want.bytes" | tr -d ' ')"
  fi
}
assert_absent() { if [[ ! -e $2 && ! -L $2 ]]; then ok "$1"; else bad "$1" "exists: $2"; fi; }

sha_of() { printf '%s' "$1" | shasum -a 256 | cut -c1-64; }

# seed NAME: write STDIN as a new version (exact bytes, no writer field).
seed() {
  jq -Rs '{data:{value:.}}' | ba write -format=json "secret/data/$TL_SECRET_PREFIX/$1" - >/dev/null || echo "seed failed: $1" >&2
  echo "$1" >>"$TL_TMP/touched"
}
seed_s() { printf '%s' "$2" | seed "$1"; } # seed_s NAME 'bytes'

vmeta() { ba kv metadata get -format=json -mount=secret "$TL_SECRET_PREFIX/$1"; }
vver() { vmeta "$1" | jq -r .data.current_version; }
# vget NAME [VERSION]: file path holding the stored bytes.
vget() {
  local f="$T/vget.$1.${2:-latest}"
  ba kv get -format=json -mount=secret ${2:+-version="$2"} "$TL_SECRET_PREFIX/$1" | jq -j '.data.data.value' >"$f"
  printf '%s' "$f"
}
# vcount: number of versions listed for NAME (0 when the path is gone).
vcount() { vmeta "$1" 2>/dev/null | jq -r '.data.versions | length' 2>/dev/null || echo 0; }

# lput REL BYTES [MODE]: create $T_HOME/REL.
lput() {
  mkdir -p "$(dirname "$T_HOME/$1")"
  printf '%s' "$2" >"$T_HOME/$1"
  chmod "${3:-600}" "$T_HOME/$1"
}

# sandbox_run CMD...: run CMD in the sandbox environment, stdin from /dev/null.
# Sets RC; output in $T/out and $T/err. ENGINE_ENV holds extra NAME=value pairs.
sandbox_run() {
  RC=0
  env -i HOME="$T_HOME" PATH="$T_SHIM:$PATH" XDG_STATE_HOME="$T_STATE" TMPDIR="$T/tmp" TERM=dumb TZ=UTC \
    SECRETSPEC_SYNC_ADDR="$S_ADDR" VAULT_TOKEN="$S_TOK" ${ENGINE_ENV[@]+"${ENGINE_ENV[@]}"} \
    "$@" >"$T/out" 2>"$T/err" </dev/null || RC=$?
}
# engine ARGS...: run the engine under test in the sandbox. Every `apply` run gets
# an awk that fails with 127 in front of PATH: the Home Manager activation PATH
# has no awk, so apply must never need one. (A test that sets PATH itself in
# ENGINE_ENV keeps full control of it.) status and sync may use awk.
engine() {
  local e has=0
  local -a saved=()
  if [[ -n ${ENGINE_ENV[*]+x} ]]; then saved=("${ENGINE_ENV[@]}"); fi
  if [[ ${1:-} == apply ]]; then
    for e in ${ENGINE_ENV[@]+"${ENGINE_ENV[@]}"}; do
      if [[ $e == PATH=* ]]; then has=1; fi
    done
    if ((!has)); then
      mkdir -p "$T/noawk"
      printf '#!/bin/sh\necho "awk: command not found (apply must not use awk)" >&2\nexit 127\n' >"$T/noawk/awk"
      chmod +x "$T/noawk/awk"
      ENGINE_ENV=(${ENGINE_ENV[@]+"${ENGINE_ENV[@]}"} "PATH=$T/noawk:$T_SHIM:$PATH")
    fi
  fi
  sandbox_run "${TL_ENGINE[@]}" "$@"
  ENGINE_ENV=(${saved[@]+"${saved[@]}"})
}

# The 14 secrets as NAME PATH-FROM-HOME MODE. materialize.sh holds the real
# table; a test keeps this copy honest.
TL_TABLE='SSH_ID_ED25519 .ssh/id_ed25519 600
SSH_ID_ED25519_PUB .ssh/id_ed25519.pub 644
SSH_ID_ED25519_OC .ssh/id_ed25519.oc 600
SSH_ID_ED25519_OC_PUB .ssh/id_ed25519.oc.pub 644
SSH_ID_ED25519_UNIT_PX .ssh/id_ed25519_unit_px 600
SSH_ID_CRYPT .ssh/id_crypt 600
SSH_ID_CRYPT_PUB .ssh/id_crypt.pub 644
SSH_LINE_PAYMENT_GATEWAY .ssh/line-payment-gateway 600
SSH_LINE_PAYMENT_GATEWAY_PUB .ssh/line-payment-gateway.pub 644
ATUIN_KEY .local/share/atuin/key 600
NPMRC .npmrc 600
ATUIN_AI_TOKEN .config/atuin/ai-token 600
OMP_ENV .omp/.env 600
TOFU_BACKBONE_CLUSTER_PASS .config/tofu/backbone-cluster.pass 600'
rel_of() { awk -v n="$1" '$1 == n { print $2 }' <<<"$TL_TABLE"; }
mode_of() { awk -v n="$1" '$1 == n { print $3 }' <<<"$TL_TABLE"; }

# Fixtures for the Mac's own state.
put_base() { # put_base NAME VERSION SHA CREATED_TIME
  local d=$T_STATE/dotfiles/secretspec
  mkdir -p "$d"
  chmod 700 "$d"
  jq -nc --argjson v "$2" --arg s "$3" --arg c "$4" '{version: $v, sha256: $s, created_time: $c}' >"$d/$1.base.json"
}
put_legacy() { # put_legacy NAME SHA
  local d=$T_STATE/dotfiles/secretspec
  mkdir -p "$d"
  chmod 700 "$d"
  printf '%s\n' "$2" >"$d/$1.sha256"
}
# vct NAME VERSION: created_time the vault gave that version.
vct() { vmeta "$1" | jq -r --arg v "$2" '.data.versions[$v].created_time'; }

# in_sandbox: export what the in-process tests need to source the scripts.
in_sandbox() {
  export HOME=$T_HOME XDG_STATE_HOME=$T_STATE TMPDIR=$T/tmp TZ=UTC
  export SECRETSPEC_SYNC_ADDR=$S_ADDR VAULT_TOKEN=$S_TOK
  PATH=$T_SHIM:$PATH
}

tl_run_all() {
  local fn
  for fn in $(declare -F | awk '{print $3}' | grep '^test_' || true); do
    if [[ -n ${TL_ONLY:-} && $fn != "$TL_ONLY" ]]; then continue; fi
    TL_RAN=$((TL_RAN + 1))
    tl_begin
    echo "== $fn"
    if (
      set +e
      T_FAIL=0
      "$fn"
      [[ $T_FAIL -eq 0 ]]
    ); then
      echo "PASS $fn"
    else
      echo "FAIL $fn"
      TL_FAILED=$((TL_FAILED + 1))
    fi
  done
}

tl_done() {
  local after
  after=$(tl_fingerprint)
  if [[ $after == "$TL_FP_BEFORE" ]]; then
    echo "ok   real ~/.vault-token unchanged"
  else
    echo "FAIL real ~/.vault-token changed (hash or mtime)"
    TL_FAILED=$((TL_FAILED + 1))
  fi
  echo "$TL_RAN tests, $TL_FAILED failed"
  [[ $TL_FAILED -eq 0 ]]
}
