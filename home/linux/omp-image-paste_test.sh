#!/usr/bin/env bash
# Tests for home/linux/omp-image-paste.zsh: the omp function of the agent role's ~/.zshenv, which turns on Tern's paste-events mode
# (CSI ? 5522 h) while omp runs in a Tern pane and off after it. The file under test is the real one. A real terminal is a pty
# (python3's pty module); the omp that it runs is a fixture script (never the real omp), and HOME and ZDOTDIR are temporary. The
# pty output is printed with ESC as ^ so that a diff can show it, and the escapes that matter are the two of the mode.
set -uo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
# shellcheck source=../secretspec/testlib.sh
. "$ROOT/home/secretspec/testlib.sh" || exit 1
command -v zsh >/dev/null || { echo "zsh not found: skipping the omp-image-paste tests"; exit 0; }
PY3=$(command -v python3) || { echo "python3 not found: the omp-image-paste tests need a pty"; exit 2; }
WRAPPER=$ROOT/home/linux/omp-image-paste.zsh

# The fixture omp: prints every argument in brackets and exits with FAKE_OMP_EXIT (default 0); with FAKE_OMP_WAIT set it prints READY
# and waits (for the Ctrl-C of the test).
fixture() {
  local d=$1
  mkdir -p "$d/bin" "$d/zd" "$d/home"
  cat >"$d/bin/omp" <<'EOF'
#!/bin/sh
printf 'ARGS'
for a in "$@"; do printf '[%s]' "$a"; done
printf '\n'
if [ -n "${FAKE_OMP_WAIT:-}" ]; then echo READY; sleep 30; fi
exit "${FAKE_OMP_EXIT:-0}"
EOF
  chmod +x "$d/bin/omp"
  mkdir -p "$d/empty"
  # what the role puts in ~/.zshenv (the function), and nothing else
  cat "$WRAPPER" >"$d/zd/.zshenv"
}

# ptyrun DIR [ENV=VALUE]... -- ZSH-ARGS...: zsh in a pty of its own (stdin, stdout and stderr are its slave side), a scrubbed environment
# (TERM_PROGRAM=tern unless an ENV says otherwise), the fixture bin first on PATH. When PTY_INT_AFTER is set, a Ctrl-C is typed once
# that text has been printed. The output with CRs dropped and ESC shown as ^ goes to stdout; the exit status is zsh's. 30 s at most.
PTY_PY='import os, pty, select, signal, sys, time
pid, fd = pty.fork()
if pid == 0:
    os.execvp(sys.argv[1], sys.argv[1:])
marker = os.environ.get("PTY_INT_AFTER", "").encode()
out, sent, end = b"", False, time.time() + 30
while time.time() < end:
    r, _, _ = select.select([fd], [], [], 0.1)
    if r:
        try:
            data = os.read(fd, 65536)
        except OSError:
            break
        if not data:
            break
        out += data
    if marker and not sent and marker in out:
        os.write(fd, b"\x03")
        sent = True
try:
    done, status = os.waitpid(pid, os.WNOHANG)
    if not done:
        time.sleep(0.2)
        done, status = os.waitpid(pid, os.WNOHANG)
    if not done:
        os.kill(pid, signal.SIGKILL)
        status = os.waitpid(pid, 0)[1]
except ChildProcessError:
    status = 0
sys.stdout.buffer.write(out)
sys.exit(os.waitstatus_to_exitcode(status))'
# (__ETC_ZSHENV_SOURCED=1 makes nix-darwin's /etc/zshenv, which rewrites PATH, return at once: the fixture bin must stay first.)
ptyrun() {
  local d=$1 envs=()
  shift
  while [[ $# -gt 0 && $1 != -- ]]; do envs+=("$1"); shift; done
  shift
  [[ " ${envs[*]} " == *" TERM_PROGRAM="* ]] || envs+=(TERM_PROGRAM=tern)
  env -i HOME="$d/home" ZDOTDIR="$d/zd" PATH="$d/bin:/usr/bin:/bin" TERM=xterm-256color __ETC_ZSHENV_SOURCED=1 "${envs[@]}" "$PY3" -c "$PTY_PY" zsh "$@" 2>&1 | LC_ALL=C tr -d '\r' | LC_ALL=C tr '\033' '^'
  return "${PIPESTATUS[0]}"
}
# plainrun DIR ZSH-ARGS...: the same without a terminal (stdin and stdout are pipes), TERM_PROGRAM=tern.
plainrun() {
  local d=$1
  shift
  env -i HOME="$d/home" ZDOTDIR="$d/zd" PATH="$d/bin:/usr/bin:/bin" TERM=xterm-256color __ETC_ZSHENV_SOURCED=1 TERM_PROGRAM=tern zsh "$@" 2>&1 </dev/null | LC_ALL=C tr '\033' '^'
  return "${PIPESTATUS[0]}"
}
ON='^[?5522h'
OFF='^[?5522l'
# -f: no ~/.zshenv of the machine; the function is sourced from the fixture's copy of the file under test
# shellcheck disable=SC2016
SRC='. "$ZDOTDIR/.zshenv"'

test_in_a_tern_pane_the_mode_is_on_while_omp_runs_and_off_after() {
  fixture "$T/a"
  local out rc
  out=$(ptyrun "$T/a" -- -f -c "$SRC; omp a 'b c'; print done rc=\$?")
  rc=$?
  assert_eq "mode on, omp's output, mode off, then the shell goes on" "$out" "${ON}ARGS[a][b c]
${OFF}done rc=0"
  assert_rc "zsh" "$rc" 0
}

test_omps_exit_status_is_kept_and_the_mode_is_reset_on_an_error_exit() {
  fixture "$T/b"
  local out rc
  out=$(ptyrun "$T/b" FAKE_OMP_EXIT=3 -- -f -c "$SRC; omp x; print rc=\$?")
  assert_eq "an error exit of omp: status 3 kept, mode reset" "$out" "${ON}ARGS[x]
${OFF}rc=3"
  out=$(ptyrun "$T/b" FAKE_OMP_EXIT=7 -- -f -c "$SRC; omp x")
  rc=$?
  assert_rc "omp as the last command of zsh -c: the shell's own status is omp's" "$rc" 7
  assert_has "and the mode was reset before the shell ended" <(printf '%s\n' "$out") "${OFF}"
}

test_ctrl_c_resets_the_mode_in_a_shell_without_job_control_and_in_an_interactive_one() {
  fixture "$T/c"
  local out rc
  # zsh -c: the shell and omp are in the pty's foreground group, so the SIGINT reaches both; without the INT trap the shell dies first.
  out=$(ptyrun "$T/c" FAKE_OMP_WAIT=1 PTY_INT_AFTER=READY -- -f -c "$SRC; omp")
  rc=$?
  assert_has "zsh -c: the mode is reset after Ctrl-C" <(printf '%s\n' "$out") "^C${OFF}"
  assert_rc "zsh -c: the status is the SIGINT's" "$rc" 130
  out=$(ptyrun "$T/c" FAKE_OMP_WAIT=1 PTY_INT_AFTER=READY -- -f -i -c "$SRC; omp; print after rc=\$?")
  assert_has "zsh -i: the mode is reset after Ctrl-C" <(printf '%s\n' "$out") "^C${OFF}"
  assert_has "zsh -i: and the shell goes on with omp's status" <(printf '%s\n' "$out") "after rc=130"
}

test_no_escape_byte_unless_stdin_and_stdout_are_ttys() {
  fixture "$T/d"
  local out
  out=$(plainrun "$T/d" -f -c "$SRC; omp --version; print rc=\$?")
  assert_eq "no tty at all (a script, ssh host omp): no escape" "$out" "ARGS[--version]
rc=0"
  out=$(ptyrun "$T/d" -- -f -c "$SRC; omp --version | cat; print rc=\${pipestatus[1]}")
  assert_eq "a tty for stdin and a pipe for stdout (omp --version | cat, omp -p | less): no escape" "$out" "ARGS[--version]
rc=0"
  out=$(ptyrun "$T/d" -- -f -c "$SRC; omp --version </dev/null; print rc=\$?")
  assert_eq "a tty for stdout and none for stdin: no escape" "$out" "ARGS[--version]
rc=0"
  out=$(ptyrun "$T/d" FAKE_OMP_EXIT=4 -- -f -c "$SRC; omp x >\"$T/d/o.txt\"; print rc=\$?")
  assert_eq "stdout to a file: no escape on the terminal, omp's status kept" "$out" "rc=4"
  assert_eq "and none in the file" "$(cat "$T/d/o.txt")" "ARGS[x]"
}

test_only_a_tern_pane_gets_it() {
  fixture "$T/e"
  local out
  out=$(ptyrun "$T/e" TERM_PROGRAM=ghostty -- -f -c "$SRC; omp a")
  assert_eq "another terminal program (an ssh login from it): no escape" "$out" "ARGS[a]"
  out=$(ptyrun "$T/e" TERM_PROGRAM= -- -f -c "$SRC; omp a")
  assert_eq "an empty TERM_PROGRAM: no escape" "$out" "ARGS[a]"
}

test_every_argument_goes_through_so_update_and_version_are_unchanged() {
  fixture "$T/f"
  local out
  out=$(ptyrun "$T/f" -- -f -c "$SRC; omp update; omp --version; omp -p 'two words' '' end")
  assert_eq "omp update, omp --version and a prompt with spaces and an empty argument arrive as they were typed" "$out" "${ON}ARGS[update]
${OFF}${ON}ARGS[--version]
${OFF}${ON}ARGS[-p][two words][][end]
${OFF}"
}

test_a_missing_omp_fails_as_before_and_still_resets_the_mode() {
  fixture "$T/g"
  local out rc
  out=$(ptyrun "$T/g" PATH="$T/g/empty:/usr/bin:/bin" -- -f -c "$SRC; omp a; print rc=\$?")
  rc=$?
  assert_has "the shell says it is not found" <(printf '%s\n' "$out") "command not found"
  assert_has "status 127 is kept" <(printf '%s\n' "$out") "rc=127"
  assert_has "the mode was reset" <(printf '%s\n' "$out") "${OFF}"
  assert_rc "zsh" "$rc" 0
}

test_a_login_shell_gets_it_from_zshenv_alone_interactive_or_not() {
  fixture "$T/h"
  # no -f: ~/.zshenv (here the fixture's ZDOTDIR) is read, ~/.zshrc does not exist, and the machine's own files are off. A Tern pane runs
  # `zsh -l` (an interactive login shell) with omp as its child (measured on the VM and on the Mac); `-c omp` is the form without it.
  local out rc
  out=$(ptyrun "$T/h" -- -o NO_GLOBAL_RCS -l -c "omp a")
  rc=$?
  assert_eq "zsh -l -c omp: mode on, omp, mode off" "$out" "${ON}ARGS[a]
${OFF}"
  assert_rc "zsh -l -c omp" "$rc" 0
  out=$(ptyrun "$T/h" -- -o NO_GLOBAL_RCS -l -i -c "omp a; print rc=\$?")
  assert_eq "zsh -l -i (interactive login, as the pane's shell): mode on, omp, mode off" "$out" "${ON}ARGS[a]
${OFF}rc=0"
}

tl_init_pure
tl_run_all
tl_done
