#!/usr/bin/env bash
# Capture the names of the Mason language servers that the agent VMs install, from this Mac's Mason.
#
#   mason-capture.sh <mason dir> <omp built-ins> <skip list> <destination file>
#
# A package is captured when
#   - its receipt (<mason dir>/packages/<name>/mason-receipt.json: Mason writes it when an install is
#     finished) is there, and the Mason registry (<mason dir>/registries/github/mason-org/mason-registry/
#     registry.json) lists it in the LSP category (formatters, linters, debuggers are not LSP), and
#   - one of the executables it links is, letter for letter, the command of a built-in server of omp
#     (<omp built-ins>: home/omp/lsp-builtins.txt, made by lsp-builtins-extract.sh), because omp starts
#     such a server when its command is on PATH, which is all that pi-mason-bridge provides, and
#   - it is not in the skip list (<skip list>: home/omp/mason-lsp-skip.txt, `<package>  <reason>` per line,
#     the reason being why it is left out).
# The destination gets the package names, sorted, one per line, and nothing else: no version, no path.
# Mason installs the registry's current version of a package on the VM, like mise's `latest`.
#
# Every name that is read or written is checked to be a plain package name (lowercase letters, digits,
# dot, underscore, dash; not starting with dot or dash): the names end up as arguments of a command on
# the VMs, and in a public repository. Nothing is written until every check passes; what was left out,
# and why, is printed. Needs jq.
#
# Exit: 0 captured, 1 a check failed (nothing written), 2 usage or a missing input.
set -uo pipefail

die() { # die CODE MESSAGE
  printf 'mason-capture: %s\n' "$2" >&2
  exit "$1"
}

[ $# -eq 4 ] || die 2 "usage: mason-capture.sh <mason dir> <omp built-ins> <skip list> <destination file>"
mason=$1
builtins=$2
skiplist=$3
dest=$4
registry=$mason/registries/github/mason-org/mason-registry/registry.json
[ -d "$mason/packages" ] || die 2 "no Mason packages directory: $mason/packages"
[ -f "$builtins" ] || die 2 "no such file: $builtins"
[ -f "$skiplist" ] || die 2 "no such file: $skiplist"
[ -d "$(dirname "$dest")" ] || die 2 "no such directory: $(dirname "$dest")"
[ -f "$registry" ] || die 2 "no Mason registry at $registry (open Neovim once, or run :MasonUpdate)"
command -v jq >/dev/null || die 2 "jq not found on PATH"

pkg_re='^[a-z0-9][a-z0-9._-]*$'
cmd_re='^[A-Za-z0-9][A-Za-z0-9._-]*$'
work=$(mktemp -d "${TMPDIR:-/tmp}/mason-capture.XXXXXX") || die 2 "cannot create a temporary directory"
trap 'rm -rf "$work"' EXIT

bad=0
finding() { # finding MESSAGE
  printf 'mason-capture: %s\n' "$1" >&2
  bad=1
}

# The built-in commands: names, `#` comment lines and blank lines.
n=0
: >"$work/builtins.txt"
while IFS= read -r line || [ -n "$line" ]; do
  n=$((n + 1))
  line=${line%%$'\r'}
  [[ $line =~ ^[[:space:]]*(#.*)?$ ]] && continue
  if [[ $line =~ $cmd_re ]]; then
    printf '%s\n' "$line" >>"$work/builtins.txt"
  else
    finding "$(basename "$builtins") line $n is not a plain command name"
  fi
done <"$builtins"

# The skip list: `<package>  <reason>`.
n=0
: >"$work/skip.tsv"
while IFS= read -r line || [ -n "$line" ]; do
  n=$((n + 1))
  line=${line%%$'\r'}
  [[ $line =~ ^[[:space:]]*(#.*)?$ ]] && continue
  name=${line%%[[:space:]]*}
  reason=${line#"$name"}
  reason=${reason#"${reason%%[![:space:]]*}"}
  reason=${reason%"${reason##*[![:space:]]}"}
  if ! [[ $name =~ $pkg_re ]]; then
    finding "$(basename "$skiplist") line $n: $(printf '%q' "$name") is not a plain package name"
  elif ! [[ $reason =~ ^[[:print:]]+$ ]]; then
    finding "$(basename "$skiplist") line $n: $name has no reason (or one with an unprintable character)"
  else
    printf '%s\t%s\n' "$name" "$reason" >>"$work/skip.tsv"
  fi
done <"$skiplist"

# The registry: a list of packages that have a name.
jq -e 'type == "array" and all(.[]; type == "object" and (.name | type) == "string")' "$registry" >/dev/null 2>&1 ||
  finding "the Mason registry $registry is not a list of packages"

# One receipt per installed package: the directory name is the package name, the receipt says the same, and
# links.bin lists the executables the package puts on PATH (anything else in the receipt is not read).
: >"$work/receipts.tsv"
count=0
for receipt in "$mason"/packages/*/mason-receipt.json; do
  [ -f "$receipt" ] || continue
  count=$((count + 1))
  dir=${receipt%/mason-receipt.json}
  dir=${dir##*/}
  if ! [[ $dir =~ $pkg_re ]]; then
    finding "$(printf '%q' "$dir") in $mason/packages is not a plain package name"
    continue
  fi
  row=$(jq -r --arg d "$dir" 'select(.name == $d) | [.name, ((.links.bin // {}) | keys | map(select(test("^[A-Za-z0-9][A-Za-z0-9._+-]*$"))) | join(" "))] | @tsv' "$receipt" 2>/dev/null) || row=""
  if [ -z "$row" ]; then
    finding "the receipt of $dir is not valid, or names another package"
    continue
  fi
  printf '%s\n' "$row" >>"$work/receipts.tsv"
done
[ "$count" -gt 0 ] || die 2 "no installed Mason package (no receipt) in $mason/packages"
[ "$bad" -eq 0 ] || die 1 "refused: nothing was written (see above)"

# Join the receipts with the registry's categories, the built-ins and the skip list in one pass.
# The install service's PATH has the tools of these package sources (pkg:<source>/...) and no others: keep this in
# step with toolPackages in modules/nixos/agent-dev.nix.
covered="npm golang cargo github"
jq -n -r --arg covered "$covered" --slurpfile reg "$registry" --rawfile rec "$work/receipts.tsv" --rawfile bi "$work/builtins.txt" --rawfile sk "$work/skip.tsv" '
  ($reg[0] | map({key: .name, value: ((.categories // []) | if type == "array" then . else [] end)}) | from_entries) as $cat
  | ($reg[0] | map({key: .name, value: ((.source.id? // "") | if type == "string" then ltrimstr("pkg:") | split("/")[0] else "" end)}) | from_entries) as $src
  | ($covered | split(" ")) as $covered
  | ($bi | split("\n") | map(select(length > 0))) as $builtins
  | ($sk | split("\n") | map(select(length > 0) | split("\t")) | map({key: .[0], value: .[1]}) | from_entries) as $skip
  | $rec | split("\n") | map(select(length > 0) | split("\t"))[]
  | .[0] as $n
  | ((.[1] // "") | split(" ") | map(select(length > 0))) as $bins
  | if $skip[$n] != null then "SKIP\t\($n)\t\($skip[$n])"
    elif ((($cat[$n] // []) | any(. == "LSP")) | not) then empty
    elif ($bins | any(. as $b | $builtins | any(. == $b))) then
      if ($covered | any(. == $src[$n])) then "KEEP\t\($n)" else "NEEDS\t\($n)\t\($src[$n])" end
    else "NOTUSED\t\($n)\t\(if ($bins | length) == 0 then "nothing" else ($bins | join(" ")) end)"
    end' >"$work/verdicts.tsv" 2>"$work/jq.err" || die 1 "the join of receipts and registry failed: $(head -n 1 "$work/jq.err")"

: >"$work/names"
while IFS=$'\t' read -r kind name rest; do
  case $kind in
    KEEP) printf '%s\n' "$name" >>"$work/names" ;;
    SKIP) printf 'skipped: %s (%s)\n' "$name" "$rest" ;;
    NEEDS) finding "$name installs from pkg:$rest, which the install service's PATH has no tool for: put it on the skip list, or add its tools to toolPackages (modules/nixos/agent-dev.nix) and to the list in infra/roles-check.sh" ;;
    NOTUSED) printf 'not used: %s (LSP, links %s: no omp built-in server has that command)\n' "$name" "$rest" ;;
  esac
done <"$work/verdicts.tsv"
[ "$bad" -eq 0 ] || die 1 "refused: nothing was written (see above)"

LC_ALL=C sort "$work/names" >"$work/out"
[ -s "$work/out" ] || die 1 "no package of the Mason install is a language server that omp can start from PATH (nothing was written)"

tmp=$(mktemp "$dest.XXXXXX") || die 2 "cannot create a file next to $dest"
trap 'rm -rf "$work" "$tmp"' EXIT
cat "$work/out" >"$tmp" && chmod 644 "$tmp" && mv -f "$tmp" "$dest" || die 2 "cannot write $dest"
printf 'kept %s packages -> %s\n' "$(wc -l <"$work/out" | tr -d ' ')" "$dest"
