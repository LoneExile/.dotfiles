# testlib_engine.sh: fixtures for tests that run the whole engine (apply, sync).
# Sourced after testlib.sh.

NAMES=$(awk '{print $1}' <<<"$TL_TABLE")
STATE_REL=dotfiles/secretspec

# seed_all: every secret at v1 = "v-NAME", with the same bytes on disk.
seed_all() {
  local n pids=""
  for n in $NAMES; do
    seed_s "$n" "v-$n" &
    pids="$pids $!"
    lput "$(rel_of "$n")" "v-$n" "$(mode_of "$n")"
  done
  # shellcheck disable=SC2086
  wait $pids
}
# reseed NAME BYTES: a new vault version and the same bytes on disk.
reseed() {
  seed_s "$1" "$2"
  lput "$(rel_of "$1")" "$2" "$(mode_of "$1")"
}
# settle: run apply once so every secret has a base record (all in sync).
settle() {
  engine apply
  assert_rc "settle run" "$RC" 0
}
file_of() { printf '%s/%s' "$T_HOME" "$(rel_of "$1")"; }
state_file() { printf '%s/%s/%s' "$T_STATE" "$STATE_REL" "$1"; }
base_version() { jq -r .version "$(state_file "$1.base.json")" 2>/dev/null; }
vault_writes() { grep -cE '^(write|kv put|kv delete|kv destroy|kv undelete|kv metadata (put|patch|delete)) ' "$T/bao.log" || true; }

# tty_engine ANSWERS ARGS...: run the engine on a pseudo-terminal with ANSWERS
# typed ahead (\n is Enter, \004 is end of input). Sets RC (124 = timed out). The
# whole terminal transcript, stderr included, is in $T/out.
tty_engine() {
  local answers=$1
  shift
  printf '%b' "$answers" >"$T/answers"
  RC=0
  python3 "$TL_ROOT/tty_drive.py" "$T/answers" "${TTY_TIMEOUT:-120}" \
    env -i HOME="$T_HOME" PATH="$T_SHIM:$PATH" XDG_STATE_HOME="$T_STATE" TMPDIR="$T/tmp" TERM=dumb TZ=UTC \
    SECRETSPEC_SYNC_ADDR="$S_ADDR" VAULT_TOKEN="$S_TOK" ${ENGINE_ENV[@]+"${ENGINE_ENV[@]}"} \
    "${TL_ENGINE[@]}" "$@" >"$T/out" 2>"$T/err" || RC=$?
}

# nvim_stub: an nvim that records each call under $T/nvim.call.N (argv, and for
# every file argument its path, mode, directory mode and content at that moment)
# and appends the text of $T/nvim.edit, when present, to the first file.
nvim_stub() {
  cat >"$T_SHIM/nvim" <<'EOF'
#!/usr/bin/env bash
T=__T__
n=1
while [[ -d $T/nvim.call.$n ]]; do n=$((n + 1)); done
call=$T/nvim.call.$n
mkdir -p "$call"
printf '%s\n' "$@" >"$call/argv"
files=()
seen=0
for a in "$@"; do
  if [[ $seen == 1 ]]; then files+=("$a"); fi
  if [[ $a == -- ]]; then seen=1; fi
done
i=0
for f in "${files[@]}"; do
  i=$((i + 1))
  cp "$f" "$call/file$i"
  { stat -c %a "$f" 2>/dev/null || stat -f %Lp "$f"; } >"$call/mode$i"
  { stat -c %a "$(dirname "$f")" 2>/dev/null || stat -f %Lp "$(dirname "$f")"; } >"$call/dirmode$i"
  printf '%s\n' "$f" >"$call/path$i"
done
if [[ -f $T/nvim.edit ]]; then cat "$T/nvim.edit" >>"${files[0]}"; fi
exit 0
EOF
  sed -i.bak "s|__T__|$T|" "$T_SHIM/nvim"
  rm -f "$T_SHIM/nvim.bak"
  chmod +x "$T_SHIM/nvim"
}
nvim_calls() { find "$T" -maxdepth 1 -name 'nvim.call.*' -type d | wc -l | tr -d ' '; }

# shim_race NAME VALUE: another writer slips a write for NAME in front of the
# first write the engine sends, so the engine's check-and-set must fail.
shim_race() {
  cat >"$T_SHIM/bao" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >>"$T/bao.log"
if [ "\$1" = write ] && [ ! -f "$T/raced" ]; then
  : >"$T/raced"
  printf '{"data":{"value":"$2"}}' | env BAO_ADDR="$S_ADDR" BAO_TOKEN="$S_TOK" "$TL_BAO" write -format=json "secret/data/$TL_SECRET_PREFIX/$1" - >/dev/null
fi
exec "$TL_BAO" "\$@"
EOF
  chmod +x "$T_SHIM/bao"
}

# shim_work_modes: every bao call first records the mode of each file in the
# engine's scratch directories ($T/tmp/dotfiles-secrets.*) into $T/modes.log as
# "NAME MODE", so a test can see what is on disk while a call is in flight.
shim_work_modes() {
  cat >"$T_SHIM/bao" <<EOF
#!/bin/sh
printf '%s\\n' "\$*" >>"$T/bao.log"
for f in "$T"/tmp/dotfiles-secrets.*/*; do
  [ -f "\$f" ] || continue
  m=\$(stat -f %Lp "\$f" 2>/dev/null || stat -c %a "\$f")
  echo "\$(basename "\$f") \$m" >>"$T/modes.log"
done
exec "$TL_BAO" "\$@"
EOF
  chmod +x "$T_SHIM/bao"
  : >"$T/modes.log"
}

# shim_corrupt_readback: reads of a specific version (the read-back after a
# push) come back with an extra byte.
shim_corrupt_readback() {
  cat >"$T_SHIM/bao" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >>"$T/bao.log"
case "\$*" in
  *"kv get"*-version=*) "$TL_BAO" "\$@" | jq '.data.data.value += "X"' ;;
  *) exec "$TL_BAO" "\$@" ;;
esac
EOF
  chmod +x "$T_SHIM/bao"
}
