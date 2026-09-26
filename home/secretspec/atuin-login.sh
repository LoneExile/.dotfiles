#!/usr/bin/env bash
# Log this machine in to the self-hosted atuin sync server.
# Usage: atuin-login.sh <atuin-bin> <username>
# Activation runs this after secretspecSecrets (the key) and linkGeneration
# (Home Manager's ~/.config/atuin/config.toml, which holds sync_address).
#
# `atuin status` fails locally when logged out and asks the server
# (GET /api/v0/me) when logged in, so success means nothing to do: silent, and
# ATUIN_PASSWORD is never read. Otherwise read it from OpenBao and log in with
# `--key ""`, which reuses the synced key file without rewriting it.
# Login/network trouble warns and exits 0 so the switch finishes; the next run
# retries. A missing ATUIN_PASSWORD fails, like any missing secret.
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <atuin-bin> <username>" >&2
  exit 2
fi
atuin_bin=$1
username=$2

SECRETSPEC_BIN="${SECRETSPEC_BIN:-$HOME/.cargo/bin/secretspec}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SECRETSPEC_FILE="${SECRETSPEC_FILE:-$REPO_ROOT/secretspec.toml}"
SECRETSPEC_REASON="${SECRETSPEC_REASON:-atuin login}"

# warn title output
warn() {
  echo >&2
  echo "!!!!!!!! atuin: $1 !!!!!!!!" >&2
  printf '%s\n' "$2" | sed 's/^/  /' >&2
  echo "  Next just home retries. By hand: atuin login -u $username" >&2
  echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" >&2
  echo >&2
}

if "$atuin_bin" status >/dev/null 2>&1; then
  exit 0
fi

if ! password=$("$SECRETSPEC_BIN" -f "$SECRETSPEC_FILE" --reason "$SECRETSPEC_REASON" get -p openbao ATUIN_PASSWORD); then
  echo "error: could not resolve secret 'ATUIN_PASSWORD' from OpenBao; atuin not logged in" >&2
  echo "if unset: secretspec set -p openbao ATUIN_PASSWORD --reason \"atuin auto-login\"" >&2
  echo "if OpenBao auth expired: just openbao-login" >&2
  exit 1
fi

# The password is on argv only here: `atuin login` prompts on /dev/tty, never
# stdin. `--password=` keeps a leading '-' from parsing as a flag. stdin is
# /dev/null so a wrong key logs out and exits instead of prompting.
if ! out=$("$atuin_bin" login --username "$username" --password="$password" --key "" </dev/null 2>&1); then
  warn "login failed" "$out"
  exit 0
fi

# login exits 0 even when its key check hits a network error; status is proof.
if ! out=$("$atuin_bin" status 2>&1); then
  warn "logged in, but atuin status fails" "$out"
  exit 0
fi
echo "atuin: logged in as $username"
