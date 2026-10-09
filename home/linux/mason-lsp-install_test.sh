#!/usr/bin/env bash
# Tests for home/linux/mason-lsp-install.sh: the user service of the agent role that installs the Mason
# language servers of home/omp/mason-lsp.txt with headless MasonInstall, only for what is missing and
# only when the list is new. `nvim` is a shim that logs how it was called and writes the receipt that
# Mason writes when an install is finished.
set -uo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
# shellcheck source=../secretspec/testlib.sh
. "$ROOT/home/secretspec/testlib.sh" || exit 1
SCRIPT=$ROOT/home/linux/mason-lsp-install.sh
WANT1=$(printf 'one' | shasum -a 256 | cut -c1-64)
WANT2=$(printf 'two' | shasum -a 256 | cut -c1-64)

MASON() { echo "$T_HOME/.local/share/nvim/mason"; }
STAMP() { echo "$T_HOME/.local/state/dotfiles/mason-lsp.stamp"; }
NVIM() { echo "$T/bin/nvim"; }
INIT() { echo "$T/init.lua"; }

# nvim shim. It logs the arguments, the working directory and the variables that keep the install's
# caches (npm, go, cargo) out of the home; STUB_FAIL (names) exit 1 without a receipt; STUB_LIE (names) exit 0 without
# one; STUB_RC1 (names) exit 1 after the receipt; STUB_SLEEP seconds are spent after it; every other name gets its receipt. It leaves a read-only module cache and a file in each cache
# directory behind, as go and npm do.
mknvim() {
  mkdir -p "$T/bin"
  : >"$(INIT)"
  cat >"$(NVIM)" <<'EOF'
#!/bin/sh
printf '%s|%s|%s|%s|%s|%s|%s|%s\n' "$*" "$PWD" "${XDG_CONFIG_HOME:-}" "${XDG_CACHE_HOME:-}" "${npm_config_cache:-}" "${GOPATH:-}" "${GOFLAGS:-}" "${CARGO_HOME:-}" >>"$STUB_LOG"
name=""
for a in "$@"; do
  case $a in "+MasonInstall "*) name=${a#+MasonInstall } ;; esac
done
[ -n "$name" ] || exit 64
mkdir -p "$XDG_CACHE_HOME/go-build" "$npm_config_cache/_logs" "$GOPATH/pkg/mod/x" "$CARGO_HOME/registry"
[ -e "$CARGO_HOME/registry/index" ] || : >"$CARGO_HOME/registry/index"
[ -e "$GOPATH/pkg/mod/x/file" ] || : >"$GOPATH/pkg/mod/x/file"
[ -e "$XDG_CACHE_HOME/go-build/a" ] || : >"$XDG_CACHE_HOME/go-build/a"
[ -e "$npm_config_cache/_logs/log" ] || : >"$npm_config_cache/_logs/log"
chmod -R a-w "$GOPATH/pkg"
for f in $STUB_FAIL; do [ "$f" != "$name" ] || exit 1; done
for f in $STUB_LIE; do [ "$f" != "$name" ] || exit 0; done
d=${XDG_DATA_HOME:-$HOME/.local/share}/nvim/mason/packages/$name
mkdir -p "$d"
printf '{"name":"%s"}\n' "$name" >"$d/mason-receipt.json"
for f in $STUB_RC1; do [ "$f" != "$name" ] || exit 1; done
[ -z "${STUB_SLEEP:-}" ] || { printf 'sleeping\n' >>"$STUB_LOG.sleep"; sleep "$STUB_SLEEP"; }
exit 0
EOF
  chmod +x "$(NVIM)"
  : >"$T/nvim.log"
}
# run WANT NAMES...: the service's ExecStart; prints the exit status.
run() {
  local want=$1
  shift
  HOME=$T_HOME STUB_LOG="$T/nvim.log" bash "$SCRIPT" "$want" "$(NVIM)" "$(INIT)" "$@" >"$T/out" 2>"$T/err"
  echo $?
}
calls() { wc -l <"$T/nvim.log" | tr -d ' '; }
# installed NAME...: which of the names have a receipt, in the order given, as one line.
installed() {
  local n out=""
  for n in "$@"; do [ -f "$(MASON)/packages/$n/mason-receipt.json" ] && out="$out$n "; done
  echo "${out% }"
}
# fakeinstalled NAME...: receipts that were there before the service ran.
fakeinstalled() {
  local n
  for n in "$@"; do
    mkdir -p "$(MASON)/packages/$n"
    printf '{"name":"%s"}\n' "$n" >"$(MASON)/packages/$n/mason-receipt.json"
  done
}

test_installs_each_missing_package_with_its_own_headless_masoninstall() {
  mknvim
  assert_rc "run" "$(run "$WANT1" gopls pyright marksman)" 0
  assert_eq "three calls, one per package, in the order of the list" 3 "$(calls)"
  local work=$T_HOME/.cache/dotfiles/mason-lsp-install
  assert_eq "headless, the store's init file, no shada, no plugins, one name, quit; every cache in the work directory" "--headless -u $(INIT) -i NONE --noplugin +MasonInstall gopls +qa|$work|$work/config|$work/cache|$work/npm|$work/go|-modcacherw|$work/cargo
--headless -u $(INIT) -i NONE --noplugin +MasonInstall pyright +qa|$work|$work/config|$work/cache|$work/npm|$work/go|-modcacherw|$work/cargo
--headless -u $(INIT) -i NONE --noplugin +MasonInstall marksman +qa|$work|$work/config|$work/cache|$work/npm|$work/go|-modcacherw|$work/cargo" "$(cat "$T/nvim.log")"
  assert_eq "all three are installed" "gopls pyright marksman" "$(installed gopls pyright marksman)"
  assert_eq "the stamp is the wanted hash" "$WANT1" "$(cat "$(STAMP)")"
  assert_has "says it installed" "$T/out" "installed"
}

test_only_what_is_missing_is_installed() {
  mknvim
  fakeinstalled gopls
  assert_rc "run" "$(run "$WANT1" gopls pyright)" 0
  assert_eq "one call" 1 "$(calls)"
  assert_has "for the missing package" "$T/nvim.log" "+MasonInstall pyright +qa"
  assert_lacks "not for the one that is there" "$T/nvim.log" "MasonInstall gopls"
}

test_does_not_start_nvim_when_the_stamp_matches_and_everything_is_there() {
  mknvim
  assert_rc "first" "$(run "$WANT1" gopls pyright)" 0
  assert_rc "second" "$(run "$WANT1" gopls pyright)" 0
  assert_eq "nvim ran twice in total: once per package" 2 "$(calls)"
  assert_has "says it is up to date" "$T/out" "up to date"
}

test_a_new_list_that_is_already_satisfied_only_moves_the_stamp() {
  mknvim
  assert_rc "first" "$(run "$WANT1" gopls pyright)" 0
  assert_rc "a new hash, same packages" "$(run "$WANT2" gopls pyright)" 0
  assert_eq "no further call" 2 "$(calls)"
  assert_eq "the stamp follows" "$WANT2" "$(cat "$(STAMP)")"
}

test_a_package_removed_by_hand_is_not_put_back_while_the_list_is_the_same() {
  mknvim
  assert_rc "first" "$(run "$WANT1" gopls pyright)" 0
  rm -rf "$(MASON)/packages/pyright"
  assert_rc "second, same list" "$(run "$WANT1" gopls pyright)" 0
  assert_eq "no further call" 2 "$(calls)"
  assert_eq "pyright stays removed" "gopls" "$(installed gopls pyright)"
  assert_has "says it is up to date" "$T/out" "up to date"
  assert_rc "a changed list" "$(run "$WANT2" gopls pyright)" 0
  assert_eq "now it is installed again" "gopls pyright" "$(installed gopls pyright)"
}

test_a_wiped_packages_directory_is_installed_again_under_the_same_list() {
  mknvim
  assert_rc "first" "$(run "$WANT1" gopls pyright)" 0
  rm -rf "$(MASON)/packages"
  assert_rc "second, same list" "$(run "$WANT1" gopls pyright)" 0
  assert_eq "both are installed again" "gopls pyright" "$(installed gopls pyright)"
  assert_eq "two calls more" 4 "$(calls)"
}

test_a_new_package_in_the_list_is_installed_and_nothing_is_removed() {
  mknvim
  assert_rc "first" "$(run "$WANT1" gopls)" 0
  fakeinstalled installed-by-hand
  assert_rc "a longer list" "$(run "$WANT2" gopls ruff)" 0
  assert_eq "ruff is installed" "gopls ruff" "$(installed gopls ruff)"
  assert_eq "the package that was put there by hand stays" "installed-by-hand" "$(installed installed-by-hand)"
}

test_a_failed_package_does_not_stop_the_others_and_leaves_no_stamp() {
  mknvim
  assert_rc "run" "$(STUB_FAIL=pyright run "$WANT1" gopls pyright marksman)" 1
  assert_eq "the others are installed" "gopls marksman" "$(installed gopls pyright marksman)"
  assert_eq "three calls" 3 "$(calls)"
  assert_absent "no stamp" "$(STAMP)"
  assert_has "names the failed package" "$T/err" "pyright"
  assert_has "says the next start tries again" "$T/err" "tries again"
}

test_a_failed_run_is_followed_by_a_run_that_installs_only_what_failed() {
  mknvim
  assert_rc "failing" "$(STUB_FAIL=pyright run "$WANT1" gopls pyright)" 1
  assert_rc "next start" "$(run "$WANT1" gopls pyright)" 0
  assert_eq "one more call, for pyright" "+MasonInstall pyright +qa" "$(tail -n 1 "$T/nvim.log" | sed 's/.*\(+MasonInstall [^ ]* +qa\).*/\1/')"
  assert_eq "three calls in all: gopls and pyright, then pyright alone" 3 "$(calls)"
  assert_eq "stamped" "$WANT1" "$(cat "$(STAMP)")"
}

test_an_exit_status_of_zero_without_a_receipt_is_a_failure() {
  mknvim
  assert_rc "run" "$(STUB_LIE=pyright run "$WANT1" gopls pyright)" 1
  assert_has "names the package" "$T/err" "pyright"
  assert_absent "no stamp" "$(STAMP)"
}

test_an_exit_status_other_than_zero_is_a_failure_even_when_a_receipt_was_written() {
  mknvim
  assert_rc "run" "$(STUB_RC1=pyright run "$WANT1" gopls pyright)" 1
  assert_has "says what nvim exited with" "$T/err" "exited with status 1 for pyright"
  assert_absent "no stamp" "$(STAMP)"
}

test_a_stopped_service_removes_the_work_directory() {
  mknvim
  local pid i
  HOME=$T_HOME STUB_SLEEP=30 STUB_LOG="$T/nvim.log" bash "$SCRIPT" "$WANT1" "$(NVIM)" "$(INIT)" gopls >"$T/out" 2>"$T/err" &
  pid=$!
  for i in $(seq 1 100); do
    [ -f "$T/nvim.log.sleep" ] && break
    sleep 0.1
  done
  assert_eq "the work directory exists while nvim runs" yes "$([ -d "$T_HOME/.cache/dotfiles/mason-lsp-install" ] && echo yes)"
  # what systemd does with a stopped service: SIGTERM for the whole cgroup, the script and its children
  pkill -TERM -P "$pid"
  kill -TERM "$pid"
  wait "$pid"
  assert_rc "terminated" "$?" 143
  assert_absent "the work directory is gone" "$T_HOME/.cache/dotfiles/mason-lsp-install"
  assert_absent "no stamp" "$(STAMP)"
}

test_the_old_stamp_stays_when_a_new_list_fails() {
  mknvim
  assert_rc "first" "$(run "$WANT1" gopls)" 0
  assert_rc "failing" "$(STUB_FAIL=ruff run "$WANT2" gopls ruff)" 1
  assert_eq "the old stamp stays" "$WANT1" "$(cat "$(STAMP)")"
}

test_the_caches_of_the_install_are_removed_after_a_success_and_after_a_failure() {
  mknvim
  assert_rc "success" "$(run "$WANT1" gopls)" 0
  assert_absent "the work directory is gone" "$T_HOME/.cache/dotfiles/mason-lsp-install"
  assert_eq "no file outside the Mason directory and the stamp" ".local/state/dotfiles/mason-lsp.stamp" "$(cd "$T_HOME" && find . -type f -not -path './.local/share/nvim/mason/*' | sed 's|^\./||')"
  assert_rc "failure" "$(STUB_FAIL=pyright run "$WANT2" gopls pyright)" 1
  assert_absent "the work directory is gone again" "$T_HOME/.cache/dotfiles/mason-lsp-install"
  assert_absent "no ~/.config at all" "$T_HOME/.config"
}

test_a_work_directory_left_by_a_killed_run_is_cleared_first() {
  mknvim
  mkdir -p "$T_HOME/.cache/dotfiles/mason-lsp-install/go/pkg/mod"
  : >"$T_HOME/.cache/dotfiles/mason-lsp-install/go/pkg/mod/stale"
  chmod -R a-w "$T_HOME/.cache/dotfiles/mason-lsp-install/go/pkg"
  assert_rc "run" "$(run "$WANT1" gopls)" 0
  assert_absent "the stale file is gone" "$T_HOME/.cache/dotfiles/mason-lsp-install"
}

test_it_never_touches_the_neovim_config() {
  mknvim
  mkdir -p "$T_HOME/.config/nvim"
  printf 'mine' >"$T_HOME/.config/nvim/init.lua"
  assert_rc "run" "$(run "$WANT1" gopls)" 0
  assert_eq "the user's config is as it was" "mine" "$(cat "$T_HOME/.config/nvim/init.lua")"
  assert_eq "and the only thing in ~/.config" "nvim" "$(ls -A "$T_HOME/.config")"
  assert_has "nvim was told to look elsewhere for its config" "$T/nvim.log" "|$T_HOME/.cache/dotfiles/mason-lsp-install/config|"
}

test_it_uses_the_xdg_variables_for_the_stamp_the_mason_dir_and_the_work_directory() {
  mknvim
  assert_rc "run" "$(XDG_STATE_HOME=$T/xs XDG_DATA_HOME=$T/xd XDG_CACHE_HOME=$T/xc run "$WANT1" gopls)" 0
  assert_eq "stamp under XDG_STATE_HOME" "$WANT1" "$(cat "$T/xs/dotfiles/mason-lsp.stamp")"
  assert_eq "receipt under XDG_DATA_HOME" yes "$([ -f "$T/xd/nvim/mason/packages/gopls/mason-receipt.json" ] && echo yes)"
  assert_has "work directory under XDG_CACHE_HOME" "$T/nvim.log" "|$T/xc/dotfiles/mason-lsp-install|"
  assert_absent "not under ~/.local" "$T_HOME/.local"
}

test_a_bad_argument_exits_2_before_nvim_runs() {
  mknvim
  assert_rc "none" "$(HOME=$T_HOME bash "$SCRIPT" >/dev/null 2>&1; echo $?)" 2
  assert_rc "not a hash" "$(run 'x; rm -rf /' gopls)" 2
  assert_rc "too short" "$(run abc123 gopls)" 2
  assert_rc "no names" "$(run "$WANT1")" 2
  assert_rc "a name with a space" "$(run "$WANT1" 'go pls')" 2
  assert_rc "a name with a slash" "$(run "$WANT1" '../x')" 2
  assert_rc "a name with a capital" "$(run "$WANT1" Gopls)" 2
  assert_rc "a name that starts with a dash" "$(run "$WANT1" -rf)" 2
  assert_rc "a command substitution" "$(run "$WANT1" '$(touch x)')" 2
  assert_eq "nvim never ran" 0 "$(calls)"
  assert_rc "nvim is not executable" "$(HOME=$T_HOME bash "$SCRIPT" "$WANT1" "$T/nope" "$(INIT)" gopls >/dev/null 2>&1; echo $?)" 2
  assert_rc "init file is missing" "$(HOME=$T_HOME bash "$SCRIPT" "$WANT1" "$(NVIM)" "$T/nope.lua" gopls >/dev/null 2>&1; echo $?)" 2
  assert_eq "nvim still never ran" 0 "$(calls)"
}

test_it_makes_nothing_up_when_there_is_nothing_to_do() {
  mknvim
  assert_rc "first" "$(run "$WANT1" gopls)" 0
  local before
  before=$(cd "$T_HOME" && find . | LC_ALL=C sort | shasum -a 256)
  assert_rc "second" "$(run "$WANT1" gopls)" 0
  assert_eq "no file or directory appeared or went" "$before" "$(cd "$T_HOME" && find . | LC_ALL=C sort | shasum -a 256)"
}

# macOS's TMPDIR ends in a slash: keep the fixture paths free of a double slash, which the shell's PWD drops
export TMPDIR=${TMPDIR:-/tmp}
TMPDIR=${TMPDIR%/}
tl_init_pure
tl_run_all
tl_done
