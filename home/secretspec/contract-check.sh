#!/usr/bin/env bash
# Contract check (spec §6, risk R1): the secretspec CLI still reads the value
# this engine reads, so the KV layout (path, field `value`) has not drifted.
# Read-only. One line of output; exit 1 only on drift.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SECRETSPEC_BIN="${SECRETSPEC_BIN:-$HOME/.cargo/bin/secretspec}"
SECRETSPEC_FILE="${SECRETSPEC_FILE:-$REPO_ROOT/secretspec.toml}"
NAME=SSH_ID_ED25519_PUB

# shellcheck source=common.sh
. "$SCRIPT_DIR/common.sh"
# shellcheck source=kv.sh
. "$SCRIPT_DIR/kv.sh"

if [[ ! -x $SECRETSPEC_BIN ]]; then
  echo "contract: skipped (secretspec is not installed)"
  exit 0
fi
require_bins
work_init
kv_init
kv_read "$NAME"
if [[ $KV_CLASS != ok ]]; then
  echo "contract: skipped (OpenBao: ${KV_ERR:-$KV_CLASS})"
  exit 0
fi
if ! cli=$("$SECRETSPEC_BIN" -f "$SECRETSPEC_FILE" --reason "secretspec status contract check" get -p openbao "$NAME"); then
  echo "contract: DRIFT (secretspec get $NAME failed)"
  exit 1
fi
# Command substitution drops trailing newlines on both sides, so a CLI that
# appends one (< 0.21) still matches.
want=$(<"$KV_VALUE")
if [[ $cli == "$want" ]]; then
  echo "contract: ok (secretspec get $NAME equals the stored value)"
else
  echo "contract: DRIFT (secretspec get $NAME differs from the stored value)"
  exit 1
fi
