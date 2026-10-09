#!/usr/bin/env bash
# Tests for home/omp/lsp-builtins-extract.sh: it reads the LSP server table that omp keeps as JavaScript
# text inside its compiled binary, and prints the command of every built-in server. The binary is a
# fixture here: a shell script that answers --version and carries the table behind binary junk.
set -uo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
# shellcheck source=../secretspec/testlib.sh
. "$ROOT/home/secretspec/testlib.sh" || exit 1
EXTRACT=$ROOT/home/omp/lsp-builtins-extract.sh
MARK='// packages/coding-agent/src/lsp/defaults.json'

# fakebin FILE VERSION-LINE BLOCK: an executable that prints VERSION-LINE for --version, followed by NUL
# bytes and junk (which must not be parsed), then BLOCK.
fakebin() {
  {
    printf '#!/bin/sh\n[ "$1" = "--version" ] && { echo "%s"; exit 0; }\nexit 0\n' "$2"
    printf '\000\001junk before\n// packages/coding-agent/src/lsp/other.json\n    "decoy": {\n      command: "decoy-before",\n'
    printf '%s' "$3"
  } >"$1"
  chmod +x "$1"
}

# A table as 18.8.6 lays it out: quoted and bare server names, nested objects with their own keys, one
# command used twice, and a later object after the table's closing brace.
table() {
  cat <<EOF
$MARK
var Azn;
var _zn = C(() => {
  Azn = {
    "rust-analyzer": {
      command: "rust-analyzer",
      args: [],
      settings: {
        "rust-analyzer": {
          command: "nested-must-not-count"
        }
      }
    },
    zls: {
      command: "zls",
      args: []
    },
    gopls: {
      command: "gopls",
      args: ["serve"]
    },
    pyright: {
      command: "pyright-langserver",
      args: ["--stdio"]
    },
    "typescript-native": {
      command: "tsc",
      args: ["--lsp", "--stdio"]
    },
    ruff2: {
      command: "zls",
      args: []
    },
    nocmd: {
      args: [],
      settings: {
        command: "nested-only",
      }
    }
  };
});
    "later": {
      command: "after-the-table",
    },
EOF
}

xr() { bash "$EXTRACT" "$@" >"$T/out" 2>"$T/err"; echo $?; }

test_prints_the_version_and_the_sorted_unique_commands() {
  fakebin "$T/omp" "omp/9.8.7" "$(table)"
  assert_rc "extract" "$(xr "$T/omp")" 0
  assert_eq "first line names the version" "# omp 9.8.7: command of every built-in LSP server, from the binary (home/omp/lsp-builtins-extract.sh)" "$(head -n 1 "$T/out")"
  assert_eq "the commands, sorted, one per line, once each" "gopls pyright-langserver rust-analyzer tsc zls " "$(tail -n +2 "$T/out" | tr '\n' ' ')"
}

test_ignores_what_is_not_a_server_of_the_table() {
  fakebin "$T/omp" "omp/9.8.7" "$(table)"
  assert_rc "extract" "$(xr "$T/omp")" 0
  assert_lacks "a command nested inside a server is not a server" "$T/out" "nested-must-not-count"
  assert_lacks "not even when the server has no command of its own" "$T/out" "nested-only"
  assert_lacks "an object after the table is not a server" "$T/out" "after-the-table"
  assert_lacks "junk before the table is not a server" "$T/out" "decoy-before"
}

test_a_table_that_is_missing_is_refused() {
  fakebin "$T/omp" "omp/9.8.7" "nothing here"$'\n'
  assert_rc "no table" "$(xr "$T/omp")" 1
  assert_has "says the table was not found" "$T/err" "table was not found"
  assert_eq "nothing on stdout" "" "$(cat "$T/out")"
}

test_a_table_without_servers_is_refused() {
  fakebin "$T/omp" "omp/9.8.7" "$MARK"$'\nvar Azn;\n  Azn = {\n  };\n'
  assert_rc "empty table" "$(xr "$T/omp")" 1
  assert_has "says it holds no server command" "$T/err" "holds no server command"
  assert_eq "nothing on stdout" "" "$(cat "$T/out")"
}

test_a_command_that_is_not_a_plain_name_is_refused() {
  fakebin "$T/omp" "omp/9.8.7" "$MARK"$'\nvar Azn;\n  Azn = {\n    odd: {\n      command: "two words",\n    }\n  };\n'
  assert_rc "odd command" "$(xr "$T/omp")" 1
  assert_has "says so" "$T/err" "not plain names"
  assert_eq "nothing on stdout" "" "$(cat "$T/out")"
}

test_usage_and_bad_inputs_exit_2() {
  assert_rc "no argument" "$(xr)" 2
  assert_rc "two arguments" "$(xr a b)" 2
  assert_rc "not a file" "$(xr "$T/nope")" 2
  assert_has "says it is not an executable file" "$T/err" "not an executable file"
  printf 'text' >"$T/plain"
  assert_rc "not executable" "$(xr "$T/plain")" 2
  assert_has "says so again" "$T/err" "not an executable file"
  fakebin "$T/odd" "something else" "$(table)"
  assert_rc "--version is not omp/<version>" "$(xr "$T/odd")" 2
  assert_has "says what it expected" "$T/err" "omp/<version>"
}

test_it_writes_nothing_but_stdout() {
  fakebin "$T/omp" "omp/9.8.7" "$(table)"
  mkdir -p "$T/work" "$T/tmpdir"
  (cd "$T/work" && TMPDIR=$T/tmpdir bash "$EXTRACT" "$T/omp" >"$T/o.out" 2>"$T/o.err")
  assert_rc "extract" "$?" 0
  assert_eq "no stderr" "" "$(cat "$T/o.err")"
  assert_eq "nothing written in the working directory" "" "$(ls -A "$T/work")"
  assert_eq "nothing written in TMPDIR" "" "$(ls -A "$T/tmpdir")"
}

tl_init_pure
tl_run_all
tl_done
