#!/usr/bin/env bash
# Tests for home/omp/mason-capture.sh: it reads the Mason install of this Mac (a receipt per package, and
# the Mason registry for the package categories) and writes the names of the packages that the agent VM
# should install: the language servers of Mason's LSP category that omp 18.8.6 can start from PATH alone
# (the command of one of the package's executables is one of omp's built-in servers), minus the skip
# list. Names only. Fixtures, plus checks of the committed lists against each other and one re-capture with the committed built-ins and skip list.
set -uo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
# shellcheck source=../secretspec/testlib.sh
. "$ROOT/home/secretspec/testlib.sh" || exit 1
CAP=$ROOT/home/omp/mason-capture.sh

command -v jq >/dev/null || {
  echo "jq not found on PATH" >&2
  exit 2
}

# mkpkg MASON NAME BINS-JSON [DIRNAME]: a receipt as Mason 2 writes it (links.bin maps executable names).
mkpkg() {
  local d=${4:-$2}
  mkdir -p "$1/packages/$d"
  printf '{"source":{"type":"registry+v1","id":"pkg:npm/some-thing@1.0.0"},"schema_version":"2.0","links":{"bin":%s,"opt":{},"share":{}},"name":"%s","install_options":{"force":false}}\n' "$3" "$2" >"$1/packages/$d/mason-receipt.json"
}
# mkreg MASON NAME:CATEGORY,CATEGORY...[:SCHEME]: the registry file (a JSON array of packages, 600 in reality); SCHEME is
# the package source (pkg:SCHEME/...), npm when left out.
mkreg() {
  local m=$1
  shift
  mkdir -p "$m/registries/github/mason-org/mason-registry"
  printf '%s\n' "$@" | jq -R 'split(":") | {name: .[0], categories: (.[1] | split(",")), description: "x", source: {id: ("pkg:" + (.[2] // "npm") + "/x@1")}}' | jq -s . >"$m/registries/github/mason-org/mason-registry/registry.json"
}

# The Mac as it is: servers that omp has, one that omp has under another letter case, one that omp does not
# have, a linter with an LSP mode, tools of other categories, a package that is on the skip list, and a
# directory with no receipt (an unfinished install).
mkmason() { # mkmason DIR
  local m=$1
  mkpkg "$m" gopls '{"gopls":"gopls"}'
  mkpkg "$m" pyright '{"pyright":"npm:pyright","pyright-langserver":"npm:pyright-langserver"}'
  mkpkg "$m" bash-language-server '{"bash-language-server":"npm:bash-language-server"}'
  mkpkg "$m" ruff '{"ruff":"ruff-x/ruff"}'
  mkpkg "$m" html-lsp '{"vscode-html-language-server":"npm:vscode-html-language-server"}'
  mkpkg "$m" elixir-ls '{"elixir-ls":"x","elixir-ls-debugger":"y"}'
  mkpkg "$m" omnisharp '{"OmniSharp":"dotnet:libexec/OmniSharp.dll"}'
  mkpkg "$m" htmx-lsp '{"htmx-lsp":"cargo:htmx-lsp"}'
  mkpkg "$m" prettier '{"prettier":"npm:prettier"}'
  mkpkg "$m" gopls-debug '{"gopls":"golang:gopls"}'
  mkpkg "$m" nobins '{}'
  mkpkg "$m" ab '{"tool-b":"x"}'
  mkpkg "$m" a-c '{"tool-a":"x"}'
  mkdir -p "$m/packages/unfinished/node_modules"
  mkreg "$m" "gopls:LSP" "pyright:LSP" "bash-language-server:LSP" "ruff:Linter,Formatter,LSP" "html-lsp:LSP" "elixir-ls:LSP,DAP" "omnisharp:LSP" "htmx-lsp:LSP" "prettier:Formatter" "gopls-debug:DAP" "nobins:LSP" "unfinished:LSP" "ab:LSP" "a-c:LSP"
}
mkbuiltins() { # mkbuiltins FILE
  cat >"$1" <<'EOF'
# omp 9.9.9: command of every built-in LSP server, from the binary (home/omp/lsp-builtins-extract.sh)
bash-language-server
elixir-ls
gopls
omnisharp
prettier
pyright-langserver
ruff
tool-a
tool-b
vscode-html-language-server
EOF
}
mkskip() { # mkskip FILE
  cat >"$1" <<'EOF'
# package  reason
elixir-ls  the Elixir runtime is not on the VM
EOF
}
# fixtures: the Mason dir, builtins file, skip file and destination of one test
setup() {
  M=$T/mason
  B=$T/builtins.txt
  S=$T/skip.txt
  D=$T/out/mason-lsp.txt
  mkmason "$M"
  mkbuiltins "$B"
  mkskip "$S"
  mkdir -p "$T/out"
}
# The receipts are read in the glob order of the shell. bash 5.3's GLOBSORT=-name reverses it, so that only the
# script's own sort puts the names in byte order; with an older bash the order stays and the test cannot tell.
GLOBDIR=$(mktemp -d "${TMPDIR:-/tmp}/glob.XXXXXX")
mkdir -p "$GLOBDIR/x1" "$GLOBDIR/x2"
REVERSE=no
[ "$(cd "$GLOBDIR" && bash -c 'GLOBSORT=-name; for f in x*; do printf "%s " "$f"; done' 2>/dev/null)" = "x2 x1 " ] && REVERSE=yes
rm -rf "$GLOBDIR"
cap() {
  if [ "$REVERSE" = yes ]; then
    bash -c 'GLOBSORT=-name; . "$0" "$@"' "$CAP" "$@" >"$T/out.txt" 2>"$T/err.txt"
  else
    bash "$CAP" "$@" >"$T/out.txt" 2>"$T/err.txt"
  fi
  echo $?
}
run() { cap "$M" "$B" "$S" "$D"; }

test_writes_the_sorted_names_of_the_lsp_packages_that_omp_has() {
  setup
  assert_rc "capture" "$(run)" 0
  assert_bytes "names only, sorted bytewise (a dash before a letter), one per line" "$D" $'a-c\nab\nbash-language-server\ngopls\nhtml-lsp\npyright\nruff\n'
  assert_eq "file mode 644" 644 "$(tl_mode "$D")"
  assert_has "says how many it kept" "$T/out.txt" "kept 7 packages"
}

test_the_receipts_are_read_in_reverse_order_where_bash_can_do_that() {
  if [ "$REVERSE" != yes ]; then
    skip "this bash has no GLOBSORT: the sort of the names cannot be told apart from the glob order"
    return
  fi
  setup
  assert_eq "the glob order of the capture runs is the reverse of the byte order" "ab a-c " "$(cd "$M/packages" && bash -c 'GLOBSORT=-name; for d in a*; do printf "%s " "$d"; done')"
}

test_a_package_matches_by_any_of_its_executables() {
  setup
  assert_rc "capture" "$(run)" 0
  assert_has "pyright is in by its langserver executable" "$D" "pyright"
  assert_has "html-lsp is in by an executable whose name differs from the package's" "$D" "html-lsp"
}

test_packages_outside_the_lsp_category_are_left_out_even_when_an_executable_matches() {
  setup
  mkreg "$M" "gopls:LSP" "prettier:Formatter" "pyright:LSP" "bash-language-server:LSP" "ruff:LSP" "html-lsp:LSP"
  mkpkg "$M" prettier '{"prettier":"npm:prettier"}'
  assert_rc "capture" "$(run)" 0
  assert_lacks "the formatter is not in" "$D" "prettier"
  assert_lacks "a DAP package is not in" "$D" "gopls-debug"
}

test_the_skip_list_wins_and_says_why() {
  setup
  assert_rc "capture" "$(run)" 0
  assert_lacks "elixir-ls is not in although omp has it" "$D" "elixir-ls"
  assert_has "says it skipped it and why" "$T/out.txt" "skipped: elixir-ls (the Elixir runtime is not on the VM)"
}

test_a_name_that_differs_only_in_letter_case_does_not_match() {
  setup
  assert_rc "capture" "$(run)" 0
  assert_lacks "omnisharp is not in: omp looks for omnisharp, Mason links OmniSharp" "$D" "omnisharp"
  assert_has "says it is not used and what it links" "$T/out.txt" "not used: omnisharp (LSP, links OmniSharp: no omp built-in server has that command)"
}

test_an_lsp_package_omp_does_not_have_is_reported_not_used() {
  setup
  assert_rc "capture" "$(run)" 0
  assert_lacks "htmx-lsp is not in" "$D" "htmx-lsp"
  assert_has "says so" "$T/out.txt" "not used: htmx-lsp (LSP, links htmx-lsp: no omp built-in server has that command)"
  assert_has "a package with no executables is named too" "$T/out.txt" "not used: nobins (LSP, links nothing: no omp built-in server has that command)"
}

test_an_unfinished_install_is_ignored() {
  setup
  assert_rc "capture" "$(run)" 0
  assert_lacks "no receipt, not in" "$D" "unfinished"
  assert_lacks "and not reported either" "$T/out.txt" "unfinished"
}

test_a_second_run_gives_the_same_bytes_and_replaces_an_older_copy() {
  setup
  printf 'old\n' >"$D"
  assert_rc "first" "$(run)" 0
  local before
  before=$(shasum -a 256 <"$D")
  assert_rc "second" "$(run)" 0
  assert_eq "same bytes" "$before" "$(shasum -a 256 <"$D")"
  assert_lacks "the old content is gone" "$D" "old"
}

test_a_package_whose_source_the_install_has_no_tool_for_is_refused_and_named() {
  setup
  printf 'previous\n' >"$D"
  printf '%s\n' tool-py >>"$B"
  mkpkg "$M" pylsp '{"tool-py":"x"}'
  mkreg "$M" "gopls:LSP:golang" "pyright:LSP:npm" "bash-language-server:LSP:github" "ruff:LSP:github" "html-lsp:LSP:npm" "pylsp:LSP:pypi" "ab:LSP:cargo" "a-c:LSP:npm"
  assert_rc "a pypi package" "$(run)" 1
  assert_has "names the package" "$T/err.txt" "pylsp"
  assert_has "names its source" "$T/err.txt" "pkg:pypi"
  assert_has "says where to go on" "$T/err.txt" "skip list, or add its tools to toolPackages"
  assert_bytes "the destination is untouched" "$D" $'previous\n'
  printf 'pylsp  needs python and its venv, which the install service does not have\n' >>"$S"
  assert_rc "once it is on the skip list" "$(run)" 0
  assert_lacks "it is left out" "$D" "pylsp"
}

test_a_receipt_whose_name_is_not_its_directory_is_refused() {
  setup
  mkpkg "$M" gopls '{"gopls":"gopls"}' other-dir
  mkdir -p "$(dirname "$D")"
  printf 'previous\n' >"$D"
  assert_rc "capture" "$(run)" 1
  assert_has "names the directory" "$T/err.txt" "other-dir"
  assert_bytes "the destination is untouched" "$D" $'previous\n'
}

test_a_name_that_is_not_a_plain_package_name_is_refused() {
  setup
  printf 'previous\n' >"$D"
  mkpkg "$M" 'Evil Name; rm -rf ~' '{"gopls":"gopls"}' 'Evil Name; rm -rf ~'
  assert_rc "bad directory name" "$(run)" 1
  assert_has "says what a plain name is" "$T/err.txt" "not a plain package name"
  assert_bytes "the destination is untouched" "$D" $'previous\n'
  rm -rf "$M/packages/Evil Name; rm -rf ~"
  mkpkg "$M" 'a/../b' '{"gopls":"gopls"}' good-dir
  assert_rc "bad name in a receipt" "$(run)" 1
  assert_bytes "the destination is untouched again" "$D" $'previous\n'
  rm -rf "$M/packages/good-dir"
  mkpkg "$M" '-rf' '{"gopls":"gopls"}' -rf
  assert_rc "a name that starts with a dash" "$(run)" 1
}

test_a_receipt_that_is_not_json_or_has_odd_links_is_refused() {
  setup
  printf 'previous\n' >"$D"
  printf 'not json' >"$M/packages/gopls/mason-receipt.json"
  assert_rc "not json" "$(run)" 1
  assert_has "names the package" "$T/err.txt" "gopls"
  assert_bytes "the destination is untouched" "$D" $'previous\n'
  mkpkg "$M" gopls '"a string"'
  assert_rc "links.bin is not an object" "$(run)" 1
  assert_bytes "the destination is untouched again" "$D" $'previous\n'
}

test_a_registry_that_is_not_a_list_of_packages_is_refused() {
  setup
  printf '{"name":"x"}' >"$M/registries/github/mason-org/mason-registry/registry.json"
  assert_rc "an object" "$(run)" 1
  assert_has "says so" "$T/err.txt" "is not a list of packages"
}

test_an_empty_result_is_refused_and_writes_nothing() {
  setup
  printf 'previous\n' >"$D"
  printf 'nothing-matches\n' >"$B"
  assert_rc "no server matches" "$(run)" 1
  assert_has "says why" "$T/err.txt" "no package"
  assert_bytes "the destination is untouched" "$D" $'previous\n'
}

test_the_lists_are_checked_for_plain_names_and_reasons() {
  setup
  printf 'previous\n' >"$D"
  printf 'gopls\nbad name\n' >"$B"
  assert_rc "builtins line with a space" "$(run)" 1
  assert_has "names the file" "$T/err.txt" "$(basename "$B")"
  mkbuiltins "$B"
  printf 'elixir-ls\n' >"$S"
  assert_rc "a skip line without a reason" "$(run)" 1
  assert_has "says a reason is missing" "$T/err.txt" "reason"
  printf 'Bad_Name  because\n' >"$S"
  assert_rc "an uppercase skip name" "$(run)" 1
  assert_bytes "the destination is untouched" "$D" $'previous\n'
}

test_missing_inputs_exit_2() {
  setup
  assert_rc "no arguments" "$(cap)" 2
  assert_rc "three arguments" "$(cap "$M" "$B" "$S")" 2
  assert_rc "no Mason dir" "$(cap "$T/none" "$B" "$S" "$D")" 2
  assert_rc "no builtins file" "$(cap "$M" "$T/none" "$S" "$D")" 2
  assert_rc "no skip file" "$(cap "$M" "$B" "$T/none" "$D")" 2
  rm -rf "$M/registries"
  assert_rc "no registry" "$(run)" 2
  assert_has "says how to get one" "$T/err.txt" "registry"
  setup
  rm -rf "$M/packages"
  assert_rc "no packages" "$(run)" 2
  assert_absent "nothing written" "$D"
}

test_a_packages_directory_with_no_receipt_at_all_exits_2() {
  setup
  rm -rf "$M/packages"
  mkdir -p "$M/packages/unfinished/node_modules"
  assert_rc "only an unfinished install" "$(run)" 2
  assert_has "says there is no installed package" "$T/err.txt" "no installed Mason package"
  assert_absent "nothing written" "$D"
}

test_it_writes_only_the_destination() {
  setup
  mkdir -p "$T/work" "$T/tmpdir"
  (cd "$T/work" && TMPDIR=$T/tmpdir bash "$CAP" "$M" "$B" "$S" "$D" >/dev/null 2>&1)
  assert_rc "capture" "$?" 0
  assert_eq "nothing in the working directory" "" "$(ls -A "$T/work")"
  assert_eq "no temporary file is left" "" "$(ls -A "$T/tmpdir")"
  assert_eq "the Mason dir is read only: no file changed" "" "$(find "$M" -newer "$B" -type f | head -n 1)"
}

# astro-language-server is on the committed skip list: omp sends no typescript.tsdk, so the server cannot start in
# omp. A re-capture with the committed built-ins and skip list must keep it out, whatever Mason has installed.
test_astro_stays_out_of_a_recapture_with_the_committed_lists() {
  setup
  mkpkg "$M" astro-language-server '{"astro-ls":"npm:astro-ls"}'
  mkreg "$M" "gopls:LSP" "astro-language-server:LSP"
  assert_rc "capture with the committed lists" "$(cap "$M" "$ROOT/home/omp/lsp-builtins.txt" "$ROOT/home/omp/mason-lsp-skip.txt" "$D")" 0
  assert_lacks "astro is not in the result" "$D" "astro-language-server"
  assert_has "the capture says it skipped it and why" "$T/out.txt" "skipped: astro-language-server (omp sends no typescript.tsdk"
  assert_has "gopls, which is not skipped, is in" "$D" "gopls"
  # the control: the same fixture without the skip line does capture it (so that the check above can fail)
  printf '# package  reason\n' >"$S"
  assert_rc "capture with an empty skip list" "$(cap "$M" "$ROOT/home/omp/lsp-builtins.txt" "$S" "$D")" 0
  assert_has "without the skip line astro is captured" "$D" "astro-language-server"
}

# The committed files, against each other.
test_the_committed_lists_agree() {
  local list=$ROOT/home/omp/mason-lsp.txt skip=$ROOT/home/omp/mason-lsp-skip.txt builtins=$ROOT/home/omp/lsp-builtins.txt omp=$ROOT/modules/nixos/agent-dev/omp.nix
  assert_eq "the captured list holds plain names only" 0 "$(grep -Evc '^[a-z0-9][a-z0-9._-]*$' "$list")"
  assert_eq "it is sorted and has no duplicate" "" "$(LC_ALL=C sort -c -u "$list" 2>&1)"
  assert_eq "it is not empty" yes "$([ -s "$list" ] && echo yes)"
  assert_eq "no skipped package is in it" "" "$(grep -v '^#' "$skip" | awk 'NF { print $1 }' | LC_ALL=C sort | LC_ALL=C join - "$list")"
  assert_eq "every skipped package is explained in the README" "" "$(grep -v '^#' "$skip" | awk 'NF { print $1 }' | while read -r n; do grep -qF "\`$n\`" "$ROOT/README.md" || echo "$n"; done)"
  assert_eq "every package of the list is named in the README" "" "$(while read -r n; do grep -qF "\`$n\`" "$ROOT/README.md" || echo "$n"; done <"$list")"
  local want have
  want=$(sed -n 's/^  version = "\([0-9][0-9.]*\)";$/\1/p' "$omp")
  have=$(sed -n '1s/^# omp \([0-9][0-9.]*\): .*$/\1/p' "$builtins")
  assert_eq "the built-in server list is the one of the pinned omp (re-run lsp-builtins-extract.sh after a bump)" "$want" "$have"
}

tl_init_pure
tl_run_all
tl_done
