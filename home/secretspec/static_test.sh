#!/usr/bin/env bash
# Static guards on the engine's own files.
set -uo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=testlib.sh
. "$ROOT/testlib.sh" || exit 1

# engine_scripts: the scripts the nix wrapper must ship.
engine_scripts() {
  local f
  for f in "$ROOT"/*.sh; do
    case $(basename "$f") in
      *_test.sh | testlib*.sh | atuin-login.sh | contract-check.sh) ;;
      *) basename "$f" ;;
    esac
  done
}
CLI_PATTERN='SECRETSPEC_BIN|secretspec (get|set|delete|--version)|[.]cargo/bin/secretspec'

test_the_engine_never_calls_the_secretspec_cli() {
  local f hits=0
  for f in $(engine_scripts); do
    if grep -nE "$CLI_PATTERN" "$ROOT/$f" >>"$T/hits"; then hits=$((hits + 1)); fi
  done
  assert_eq "engine scripts using the CLI" "$hits" 0
  # Positive control: the pattern does match the scripts that keep the CLI.
  grep -qE "$CLI_PATTERN" "$ROOT/atuin-login.sh" && ok "positive control: atuin-login.sh matches" || bad "positive control" "pattern missed atuin-login.sh"
  grep -qE "$CLI_PATTERN" "$ROOT/contract-check.sh" && ok "positive control: contract-check.sh matches" || bad "positive control" "pattern missed contract-check.sh"
}

test_the_wrapper_ships_exactly_the_scripts_the_engine_sources() {
  local sourced shipped on_disk
  sourced=$({
    echo materialize.sh
    sed -n 's/^for lib in \(.*\); do$/\1/p' "$ROOT/materialize.sh" | tr ' ' '\n' | sed 's/$/.sh/'
  } | sort)
  shipped=$(grep -o '\./[a-z-]*\.sh' "$ROOT/package.nix" | sed 's|^\./||' | sort)
  on_disk=$(engine_scripts | sort)
  assert_eq "package.nix ships what materialize.sh sources" "$shipped" "$sourced"
  assert_eq "no engine script is left out of both" "$on_disk" "$sourced"
}

tl_init_pure
tl_run_all
tl_done
