#!/usr/bin/env bash
# Print the command of every built-in LSP server of an omp binary, one per line, sorted, to stdout:
#
#   lsp-builtins-extract.sh <omp binary>  >home/omp/lsp-builtins.txt
#
# omp 18.8.6 has no command that lists them. Its server table (packages/coding-agent/src/lsp/defaults.json)
# is plain JavaScript text inside the compiled binary, behind a comment that names the source file, one
# object per server: `<name>: {` at four spaces, then `command: "<command>",` at six. omp starts a server
# when that command is on PATH (an exact, case-sensitive name) and one of the server's root markers is in
# the project directory. `just mason-capture` (home/omp/mason-capture.sh) reads the result to keep only
# the Mason servers that omp can start from PATH alone. Run this again when omp is bumped
# (modules/nixos/agent-dev/omp.nix): mason-capture_test.sh fails while the version in the first line of
# home/omp/lsp-builtins.txt differs from the one that omp.nix pins.
#
# The first line is `# omp <version>: ...`, the version being what `<omp binary> --version` prints. Needs
# grep, tail, head and awk; runs the binary only for that version.
# Exit: 0 printed, 1 the table was not found or is empty, 2 usage or a missing input.
set -uo pipefail

die() { # die CODE MESSAGE
  printf 'lsp-builtins-extract: %s\n' "$2" >&2
  exit "$1"
}

[ $# -eq 1 ] || die 2 "usage: lsp-builtins-extract.sh <omp binary>"
bin=$1
[ -f "$bin" ] && [ -x "$bin" ] || die 2 "not an executable file: $bin"

marker='// packages/coding-agent/src/lsp/defaults.json'
version=$("$bin" --version 2>/dev/null | head -n 1)
[[ $version =~ ^omp/([0-9]+\.[0-9]+\.[0-9]+)$ ]] || die 2 "$bin --version did not print omp/<version>"
version=${BASH_REMATCH[1]}

# byte offset of the comment (the first one: the table comes once)
offset=$(LC_ALL=C grep -a -b -o -F -- "$marker" "$bin" | head -n 1 | cut -d: -f1)
[[ $offset =~ ^[0-9]+$ ]] || die 1 "the LSP server table was not found in $bin (its source comment is gone: look at the new layout)"

# 64 KB past the comment hold the whole table (14 KB in 18.8.6); the awk stops at its closing brace
commands=$(tail -c "+$((offset + 1))" "$bin" 2>/dev/null | head -c 65536 | LC_ALL=C awk '
  /^  \};$/ { exit }
  /^    ("[^"]+"|[A-Za-z0-9_-]+): \{$/ { server = 1; next }
  server && /^      command: "[^"]+",$/ {
    c = $0
    sub(/^      command: "/, "", c)
    sub(/",$/, "", c)
    print c
    server = 0
  }
' | LC_ALL=C sort -u)
[ -n "$commands" ] || die 1 "the LSP server table in $bin holds no server command (the layout changed)"
bad=$(printf '%s\n' "$commands" | grep -Evc '^[A-Za-z0-9][A-Za-z0-9._-]*$' || true)
[ "$bad" -eq 0 ] || die 1 "the table holds $bad command names that are not plain names"

printf '# omp %s: command of every built-in LSP server, from the binary (home/omp/lsp-builtins-extract.sh)\n' "$version"
printf '%s\n' "$commands"
