#!/usr/bin/env bash
# Runs every secret-sync test file in this directory. `just test-secrets` calls it.
# Needs bao, jq and python3 on PATH. Starts one `bao server -dev` per file, with
# -dev-no-store-token, so the real ~/.vault-token is never written.
set -uo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
self=$(basename "${BASH_SOURCE[0]}")

missing=0
for b in bao jq python3; do
  if ! command -v "$b" >/dev/null 2>&1; then
    echo "error: $b not found on PATH" >&2
    missing=1
  fi
done
[[ $missing -eq 0 ]] || exit 2

rc=0
for f in "$ROOT"/*_test.sh; do
  [[ $(basename "$f") == "$self" ]] && continue
  echo "===== $(basename "$f")"
  "${BASH:-bash}" "$f" || rc=1
done
if [[ $rc -eq 0 ]]; then echo "ALL SECRET TESTS PASSED"; else echo "SECRET TESTS FAILED"; fi
exit "$rc"
