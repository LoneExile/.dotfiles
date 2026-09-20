#!/usr/bin/env bash
# Behavior tests for adopt.sh. No OmniWM, no nvim.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$ROOT/adopt.sh"
FAILS=0

pass() { printf 'ok  %s\n' "$1"; }
fail() { printf 'FAIL %s: %s\n' "$1" "$2"; FAILS=$((FAILS + 1)); }

WORK=
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

setup() {
  cleanup
  WORK=$(mktemp -d)
  mkdir -p "$WORK/repo" "$WORK/home/.config/omniwm"
  printf 'repo-bytes\n' >"$WORK/repo/settings.toml"
  export OMNIWM_REPO="$WORK/repo/settings.toml"
  export OMNIWM_DEST="$WORK/home/.config/omniwm/settings.toml"
}

run_adopt() {
  bash "$SCRIPT" "$@"
}

if [[ ! -f $SCRIPT ]]; then
  fail "adopt.sh exists" "missing $SCRIPT"
  echo "$FAILS failed"
  exit 1
fi

setup
if run_adopt --keep >/tmp/omniwm-adopt-out 2>&1; then
  if [[ -e $OMNIWM_DEST ]]; then
    fail "missing dest is no-op" "created $OMNIWM_DEST"
  else
    pass "missing dest is no-op"
  fi
else
  fail "missing dest is no-op" "exit $?"
fi

setup
ln -s "$OMNIWM_REPO" "$OMNIWM_DEST"
if run_adopt --yes >/tmp/omniwm-adopt-out 2>&1 && [[ -L $OMNIWM_DEST ]]; then
  pass "correct symlink is left alone"
else
  fail "correct symlink is left alone" "dest=$(ls -l "$OMNIWM_DEST" 2>&1)"
fi

setup
printf 'repo-bytes\n' >"$OMNIWM_DEST"
if run_adopt --keep >/tmp/omniwm-adopt-out 2>&1 && [[ -f $OMNIWM_DEST && ! -L $OMNIWM_DEST ]]; then
  pass "--keep leaves regular dest"
else
  fail "--keep leaves regular dest" "$(ls -l "$OMNIWM_DEST" 2>&1)"
fi

setup
printf 'repo-bytes\n' >"$OMNIWM_DEST"
if run_adopt --yes >/tmp/omniwm-adopt-out 2>&1 && [[ ! -e $OMNIWM_DEST ]]; then
  pass "--yes removes regular dest"
else
  fail "--yes removes regular dest" "$(ls -l "$OMNIWM_DEST" 2>&1)"
fi

setup
printf 'local-only\n' >"$OMNIWM_DEST"
if run_adopt --yes >/tmp/omniwm-adopt-out 2>&1 && [[ ! -e $OMNIWM_DEST ]]; then
  pass "--yes removes drifted regular dest"
else
  fail "--yes removes drifted regular dest" "$(ls -l "$OMNIWM_DEST" 2>&1)"
fi

setup
printf 'local-only\n' >"$OMNIWM_DEST"
if run_adopt </dev/null >/tmp/omniwm-adopt-out 2>/tmp/omniwm-adopt-err; then
  if [[ -f $OMNIWM_DEST && ! -L $OMNIWM_DEST ]]; then
    if grep -q 'regular' /tmp/omniwm-adopt-err /tmp/omniwm-adopt-out; then
      pass "non-TTY leaves regular dest and shouts"
    else
      fail "non-TTY leaves regular dest and shouts" "no shout in output: $(cat /tmp/omniwm-adopt-out /tmp/omniwm-adopt-err)"
    fi
  else
    fail "non-TTY leaves regular dest and shouts" "dest missing or symlink"
  fi
else
  fail "non-TTY leaves regular dest and shouts" "exit $?"
fi

if [[ $FAILS -eq 0 ]]; then
  echo "all passed"
  exit 0
fi
echo "$FAILS failed"
exit 1
