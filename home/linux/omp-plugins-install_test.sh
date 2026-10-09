#!/usr/bin/env bash
# Tests for home/linux/omp-plugins-install.sh: the user service of the agent role that installs the
# captured omp plugins with `bun install --frozen-lockfile`, only when the captured files changed.
# `bun` is a shim that logs how it was called and builds a node_modules directory.
set -uo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
# shellcheck source=../secretspec/testlib.sh
. "$ROOT/home/secretspec/testlib.sh" || exit 1
SCRIPT=$ROOT/home/linux/omp-plugins-install.sh
WANT1=$(printf 'one' | shasum -a 256 | cut -c1-64)
WANT2=$(printf 'two' | shasum -a 256 | cut -c1-64)

PLUG() { echo "$T_HOME/.omp/plugins"; }
STAMP() { echo "$T_HOME/.local/state/dotfiles/omp-plugins.stamp"; }

# A plugins home as the Home Manager activation leaves it: the manifests, no node_modules.
mkplugins() {
  mkdir -p "$(PLUG)"
  printf '{"name":"omp-plugins","dependencies":{}}\n' >"$(PLUG)/package.json"
  printf '{"lockfileVersion":1,"workspaces":{"":{}},"packages":{}}\n' >"$(PLUG)/bun.lock"
}
# bun shim: logs the working directory, the arguments and the cache variable; STUB_BUN_RC sets the
# exit status (a failure leaves no node_modules); a success builds one, with a file in the cache.
mkbun() {
  mkdir -p "$T/bin"
  cat >"$T/bin/bun" <<'EOF'
#!/bin/sh
printf '%s|%s|%s\n' "$PWD" "$*" "${BUN_INSTALL_CACHE_DIR:-}" >>"$STUB_LOG"
[ -z "${BUN_INSTALL_CACHE_DIR:-}" ] || { mkdir -p "$BUN_INSTALL_CACHE_DIR" && : >"$BUN_INSTALL_CACHE_DIR/cached-tarball"; }
rc=${STUB_BUN_RC:-0}
[ "$rc" -ne 0 ] || mkdir -p "$PWD/node_modules/some-plugin"
exit "$rc"
EOF
  chmod +x "$T/bin/bun"
  : >"$T/bun.log"
}
# run WANT: the service's ExecStart; prints the exit status.
run() {
  HOME=$T_HOME PATH="$T/bin:$PATH" STUB_LOG="$T/bun.log" bash "$SCRIPT" "$@" >"$T/out" 2>"$T/err"
  echo $?
}
bun_calls() { wc -l <"$T/bun.log" | tr -d ' '; }

test_installs_when_nothing_was_installed_before() {
  mkplugins
  mkbun
  assert_rc "run" "$(run "$WANT1")" 0
  assert_eq "bun ran once" 1 "$(bun_calls)"
  assert_eq "in the plugins home, frozen" "$(cd "$(PLUG)" && pwd)|install --frozen-lockfile|$(PLUG)/.bun-cache" "$(cat "$T/bun.log")"
  assert_eq "the stamp is the wanted hash" "$WANT1" "$(cat "$(STAMP)")"
  assert_eq "node_modules exists" yes "$([ -d "$(PLUG)/node_modules" ] && echo yes)"
  assert_absent "the bun cache is removed again" "$(PLUG)/.bun-cache"
  assert_has "says it installed" "$T/out" "installed"
}

test_does_not_install_again_when_the_stamp_matches() {
  mkplugins
  mkbun
  assert_rc "first" "$(run "$WANT1")" 0
  assert_rc "second" "$(run "$WANT1")" 0
  assert_eq "bun ran once in total" 1 "$(bun_calls)"
  assert_has "says it is up to date" "$T/out" "up to date"
}

test_installs_again_when_the_captured_files_changed() {
  mkplugins
  mkbun
  assert_rc "first" "$(run "$WANT1")" 0
  assert_rc "after a change" "$(run "$WANT2")" 0
  assert_eq "bun ran twice" 2 "$(bun_calls)"
  assert_eq "the stamp follows" "$WANT2" "$(cat "$(STAMP)")"
}

test_installs_again_when_node_modules_is_gone() {
  mkplugins
  mkbun
  assert_rc "first" "$(run "$WANT1")" 0
  rm -rf "$(PLUG)/node_modules"
  assert_rc "second" "$(run "$WANT1")" 0
  assert_eq "bun ran again" 2 "$(bun_calls)"
}

test_a_failed_install_leaves_no_stamp_and_keeps_the_old_one() {
  mkplugins
  mkbun
  assert_rc "first" "$(run "$WANT1")" 0
  assert_rc "failing install" "$(STUB_BUN_RC=3 run "$WANT2")" 3
  assert_eq "the old stamp stays" "$WANT1" "$(cat "$(STAMP)")"
  assert_absent "the bun cache is removed after a failure too" "$(PLUG)/.bun-cache"
  assert_has "says it failed" "$T/err" "failed"
  rm -rf "$T_HOME/.local" "$(PLUG)/node_modules"
  assert_rc "failing from scratch" "$(STUB_BUN_RC=3 run "$WANT1")" 3
  assert_absent "no stamp" "$(STAMP)"
}

test_a_failed_install_is_tried_again_by_the_next_run() {
  mkplugins
  mkbun
  assert_rc "failing" "$(STUB_BUN_RC=1 run "$WANT1")" 1
  assert_rc "next run, bun works" "$(run "$WANT1")" 0
  assert_eq "bun ran twice" 2 "$(bun_calls)"
  assert_eq "stamped" "$WANT1" "$(cat "$(STAMP)")"
}

test_missing_manifests_stop_it_before_bun() {
  mkplugins
  mkbun
  rm "$(PLUG)/bun.lock"
  assert_rc "no bun.lock" "$(run "$WANT1")" 1
  assert_has "names the file" "$T/err" "bun.lock"
  mkplugins
  rm "$(PLUG)/package.json"
  assert_rc "no package.json" "$(run "$WANT1")" 1
  assert_has "names the file" "$T/err" "package.json"
  assert_eq "bun never ran" 0 "$(bun_calls)"
  assert_absent "no stamp" "$(STAMP)"
}

test_a_bad_argument_exits_2() {
  mkplugins
  mkbun
  assert_rc "none" "$(run)" 2
  assert_rc "not a hash" "$(run 'x; rm -rf /')" 2
  assert_rc "too short" "$(run abc123)" 2
  assert_rc "two" "$(run "$WANT1" "$WANT2")" 2
  assert_eq "bun never ran" 0 "$(bun_calls)"
}

test_it_touches_nothing_but_the_plugins_home_and_the_stamp() {
  mkplugins
  mkbun
  mkdir -p "$T_HOME/.omp/agent"
  printf 'mine' >"$T_HOME/.omp/agent/config.yml"
  assert_rc "run" "$(run "$WANT1")" 0
  assert_eq "files outside the plugins home" ".omp/agent/config.yml .local/state/dotfiles/omp-plugins.stamp" "$(cd "$T_HOME" && find . -type f -not -path './.omp/plugins/*' | sed 's|^\./||' | LC_ALL=C sort -r | tr '\n' ' ' | sed 's/ $//')"
  assert_eq "agent file unchanged" mine "$(cat "$T_HOME/.omp/agent/config.yml")"
}

test_it_uses_xdg_state_home_for_the_stamp() {
  mkplugins
  mkbun
  assert_rc "run" "$(XDG_STATE_HOME=$T/xdg run "$WANT1")" 0
  assert_eq "stamp under XDG_STATE_HOME" "$WANT1" "$(cat "$T/xdg/dotfiles/omp-plugins.stamp")"
  assert_absent "not under ~/.local" "$T_HOME/.local"
}

tl_init_pure
tl_run_all
tl_done
