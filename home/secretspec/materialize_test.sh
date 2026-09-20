#!/usr/bin/env bash
# Behavior tests for materialize.sh. Uses a fake secretspec; no live vault.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$ROOT/materialize.sh"
FAILS=0

ALL_SECRETS=(
  SSH_ID_ED25519
  SSH_ID_ED25519_PUB
  SSH_ID_ED25519_OC
  SSH_ID_ED25519_OC_PUB
  SSH_ID_ED25519_UNIT_PX
  SSH_ID_CRYPT
  SSH_ID_CRYPT_PUB
  SSH_LINE_PAYMENT_GATEWAY
  SSH_LINE_PAYMENT_GATEWAY_PUB
  ATUIN_KEY
  NPMRC
  ATUIN_CONFIG
  OMP_ENV
)

pass() { printf 'ok  %s\n' "$1"; }
fail() { printf 'FAIL %s: %s\n' "$1" "$2"; FAILS=$((FAILS + 1)); }

assert_eq() {
  local label=$1 got=$2 want=$3
  if [[ $got == "$want" ]]; then
    pass "$label"
  else
    fail "$label" "got $(printf %q "$got") want $(printf %q "$want")"
  fi
}

assert_file_eq() {
  local label=$1 file=$2 want=$3
  if [[ ! -f $file ]]; then
    fail "$label" "missing $file"
    return
  fi
  local got
  got=$(cat "$file"; printf x)
  got=${got%x}
  if [[ $got == "$want" ]]; then
    pass "$label"
  else
    fail "$label" "content mismatch"
  fi
}

file_mode() { stat -f %Lp "$1"; }

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

write_fake_secretspec() {
  cat >"$SECRETSPEC_BIN" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
vault=${FAKE_VAULT:?}
cmd=
filtered=()
while [[ $# -gt 0 ]]; do
  case $1 in
    -f|--file|-p|--provider|-P|--profile|--reason|--caller|--caller-version|--caller-operation|--caller-resource)
      shift 2
      ;;
    --)
      shift
      while [[ $# -gt 0 ]]; do
        filtered+=("$1")
        shift
      done
      break
      ;;
    get|set)
      cmd=$1
      shift
      ;;
    -*)
      shift
      ;;
    *)
      filtered+=("$1")
      shift
      ;;
  esac
done
name=${filtered[0]:-}
value=${filtered[1]:-}
if [[ -z $cmd || -z $name ]]; then
  echo "fake-secretspec: missing command/name" >&2
  exit 2
fi
path="$vault/$name"
case $cmd in
  get)
    if [[ ! -f $path ]]; then
      echo "fake-secretspec: missing $name" >&2
      exit 1
    fi
    cat "$path"
    ;;
  set)
    printf '%s' "$value" >"$path"
    ;;
esac
EOF
  chmod +x "$SECRETSPEC_BIN"
}

seed_vault() {
  local n
  for n in "${ALL_SECRETS[@]}"; do
    printf 'vault-%s\n' "$n" >"$FAKE_VAULT/$n"
  done
  printf 'deadbeef\n' >"$FAKE_VAULT/ATUIN_KEY"
}

setup() {
  TEST_ROOT=$(mktemp -d)
  export HOME="$TEST_ROOT/home"
  export FAKE_VAULT="$TEST_ROOT/vault"
  export SECRETSPEC_BIN="$TEST_ROOT/fake-secretspec"
  export SECRETSPEC_FILE="$TEST_ROOT/secretspec.toml"
  export SECRETSPEC_REASON="test"
  unset XDG_STATE_HOME
  mkdir -p "$HOME" "$FAKE_VAULT"
  printf 'project = "dotfiles"\n' >"$SECRETSPEC_FILE"
  write_fake_secretspec
  seed_vault
  APPLY_OUT="$TEST_ROOT/apply.out"
}

cleanup() { rm -rf "${TEST_ROOT:-}"; }

apply() {
  bash "$SCRIPT" apply >"$APPLY_OUT" 2>&1
}

apply_fails() {
  if bash "$SCRIPT" apply >"$APPLY_OUT" 2>&1; then
    return 1
  fi
  return 0
}

state_hash() {
  tr -d ' \n' <"$HOME/.local/state/dotfiles/secretspec/$1.sha256"
}

# --- tests ---

if [[ ! -f $SCRIPT ]]; then
  echo "FAIL materialize.sh missing at $SCRIPT"
  exit 1
fi

setup
if apply; then
  assert_file_eq "new machine writes OMP_ENV" "$HOME/.omp/.env" $'vault-OMP_ENV\n'
  assert_file_eq "new machine writes npmrc" "$HOME/.npmrc" $'vault-NPMRC\n'
  got_key=$(cat "$HOME/.local/share/atuin/key"; printf x)
  got_key=${got_key%x}
  assert_eq "new machine ATUIN_KEY strips newline" "$got_key" "deadbeef"
  assert_eq "id_ed25519 mode 600" "$(file_mode "$HOME/.ssh/id_ed25519")" "600"
  assert_eq "id_ed25519.pub mode 644" "$(file_mode "$HOME/.ssh/id_ed25519.pub")" "644"
  if [[ -f $HOME/.local/state/dotfiles/secretspec/OMP_ENV.sha256 ]]; then
    pass "new machine records last-sync"
  else
    fail "new machine records last-sync" "missing hash file"
  fi
else
  fail "new machine apply" "$(cat "$APPLY_OUT")"
fi
cleanup

setup
mkdir -p "$HOME/.omp"
printf 'vault-OMP_ENV\n' >"$HOME/.omp/.env"
chmod 600 "$HOME/.omp/.env"
if apply; then
  if grep -q 'pull OMP_ENV' "$APPLY_OUT"; then
    fail "equal missing last-sync does not pull" "output: $(cat "$APPLY_OUT")"
  else
    pass "equal missing last-sync does not pull"
  fi
  if [[ -f $HOME/.local/state/dotfiles/secretspec/OMP_ENV.sha256 ]]; then
    want=$(sha256_file "$HOME/.omp/.env")
    got=$(state_hash OMP_ENV)
    assert_eq "equal missing last-sync writes hash" "$got" "$want"
  else
    fail "equal missing last-sync writes hash" "missing"
  fi
  assert_file_eq "equal missing last-sync keeps dest" "$HOME/.omp/.env" $'vault-OMP_ENV\n'
else
  fail "equal missing last-sync apply" "$(cat "$APPLY_OUT")"
fi
cleanup

setup
mkdir -p "$HOME/.omp"
printf 'local-only\n' >"$HOME/.omp/.env"
vault_before=$(cat "$FAKE_VAULT/OMP_ENV"; printf x); vault_before=${vault_before%x}
if apply; then
  assert_file_eq "bootstrap drift keeps dest" "$HOME/.omp/.env" $'local-only\n'
  vault_after=$(cat "$FAKE_VAULT/OMP_ENV"; printf x); vault_after=${vault_after%x}
  assert_eq "bootstrap drift does not set vault" "$vault_after" "$vault_before"
  if [[ -f $HOME/.local/state/dotfiles/secretspec/OMP_ENV.sha256 ]]; then
    fail "bootstrap drift does not record hash" "hash written too early"
  else
    pass "bootstrap drift does not record hash"
  fi
  if grep -q 'local drifted OMP_ENV' "$APPLY_OUT"; then
    pass "bootstrap drift prints hint"
  else
    fail "bootstrap drift prints hint" "$(cat "$APPLY_OUT")"
  fi
else
  fail "bootstrap drift apply" "$(cat "$APPLY_OUT")"
fi
cleanup


setup
apply >/dev/null
printf 'local-omp\n' >"$HOME/.omp/.env"
vault_before=$(cat "$FAKE_VAULT/OMP_ENV"; printf x); vault_before=${vault_before%x}
if apply; then
  assert_file_eq "local-newer apply keeps dest" "$HOME/.omp/.env" $'local-omp\n'
  vault_after=$(cat "$FAKE_VAULT/OMP_ENV"; printf x); vault_after=${vault_after%x}
  assert_eq "local-newer apply does not set vault" "$vault_after" "$vault_before"
  if grep -q 'local drifted OMP_ENV' "$APPLY_OUT"; then
    pass "local-newer prints hint"
  else
    fail "local-newer prints hint" "$(cat "$APPLY_OUT")"
  fi
else
  fail "local-newer apply" "$(cat "$APPLY_OUT")"
fi
cleanup

setup
apply >/dev/null
printf 'vault-omp-v2\n' >"$FAKE_VAULT/OMP_ENV"
if apply; then
  assert_file_eq "vault-newer apply pulls dest" "$HOME/.omp/.env" $'vault-omp-v2\n'
  if grep -q 'pull OMP_ENV' "$APPLY_OUT"; then
    pass "vault-newer prints pull"
  else
    fail "vault-newer prints pull" "$(cat "$APPLY_OUT")"
  fi
  want=$(sha256_file "$HOME/.omp/.env")
  got=$(state_hash OMP_ENV)
  assert_eq "vault-newer updates last-sync" "$got" "$want"
else
  fail "vault-newer apply" "$(cat "$APPLY_OUT")"
fi
cleanup

setup
apply >/dev/null
printf 'local-omp\n' >"$HOME/.omp/.env"
printf 'vault-omp-other\n' >"$FAKE_VAULT/OMP_ENV"
if apply_fails; then
  assert_file_eq "conflict keeps local dest" "$HOME/.omp/.env" $'local-omp\n'
  vault_after=$(cat "$FAKE_VAULT/OMP_ENV"; printf x); vault_after=${vault_after%x}
  assert_eq "conflict does not set vault" "$vault_after" $'vault-omp-other\n'
  if grep -q 'conflict OMP_ENV' "$APPLY_OUT"; then
    pass "conflict prints name"
  else
    fail "conflict prints name" "$(cat "$APPLY_OUT")"
  fi
else
  fail "conflict apply exits non-zero" "apply succeeded: $(cat "$APPLY_OUT")"
fi
cleanup

setup
apply >/dev/null
if apply; then
  if grep -q 'pull ATUIN_KEY' "$APPLY_OUT"; then
    fail "ATUIN_KEY newline is not a false pull" "$(cat "$APPLY_OUT")"
  else
    pass "ATUIN_KEY newline is not a false pull"
  fi
  got_key=$(cat "$HOME/.local/share/atuin/key"; printf x)
  got_key=${got_key%x}
  assert_eq "ATUIN_KEY stays stripped" "$got_key" "deadbeef"
else
  fail "ATUIN_KEY second apply" "$(cat "$APPLY_OUT")"
fi
cleanup

setup
rm -f "$FAKE_VAULT/NPMRC"
if apply_fails; then
  if grep -q "could not resolve secret 'NPMRC'" "$APPLY_OUT"; then
    pass "missing vault secret fails"
  else
    fail "missing vault secret fails" "$(cat "$APPLY_OUT")"
  fi
else
  fail "missing vault secret fails" "apply succeeded"
fi
cleanup

setup
if apply_fails </dev/null && grep -q 'TTY' "$APPLY_OUT"; then
  : # apply should ignore stdin; this is the sync check below
fi
if bash "$SCRIPT" sync </dev/null >"$APPLY_OUT" 2>&1; then
  fail "sync requires TTY" "succeeded"
else
  if grep -qi 'TTY' "$APPLY_OUT"; then
    pass "sync requires TTY"
  else
    fail "sync requires TTY" "$(cat "$APPLY_OUT")"
  fi
fi
cleanup

setup
mkdir -p "$TEST_ROOT/bin"
printf '%s\n' '#!/bin/sh' 'echo "awk: command not found" >&2' 'exit 127' >"$TEST_ROOT/bin/awk"
chmod +x "$TEST_ROOT/bin/awk"
export PATH="$TEST_ROOT/bin:$PATH"
if apply; then
  assert_file_eq "apply without awk writes OMP_ENV" "$HOME/.omp/.env" $'vault-OMP_ENV\n'
  got=$(state_hash OMP_ENV)
  if [[ ${#got} -eq 64 ]]; then
    pass "apply without awk records hash"
  else
    fail "apply without awk records hash" "got ${got:-empty}"
  fi
  if grep -q 'awk: command not found' "$APPLY_OUT"; then
    fail "apply without awk does not call awk" "$(cat "$APPLY_OUT")"
  else
    pass "apply without awk does not call awk"
  fi
else
  fail "apply without awk" "$(cat "$APPLY_OUT")"
fi
cleanup

if [[ $FAILS -ne 0 ]]; then
  echo "$FAILS failed"
  exit 1
fi
echo "all passed"
