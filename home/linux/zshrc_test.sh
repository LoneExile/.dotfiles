#!/usr/bin/env bash
# Tests for the interactive zsh of the agent role (home/linux/zsh.nix): the ~/.zshrc that the role generates is taken from
# the flake (nix eval, no VM), its store paths are pointed at fixture plugins, and it is run in a real zsh. A real terminal
# is a pty (python3's pty module): the file tests for one. Fixtures only; HOME and ZDOTDIR are temporary; the plugins
# are stubs that record when they were loaded. The three files of the Mac (home/zsh/config) are the real ones, loaded
# from the store copy that the flake names, and the commands that their aliases name are shims that log any call.
set -uo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
# shellcheck source=../secretspec/testlib.sh
. "$ROOT/home/secretspec/testlib.sh" || exit 1
command -v zsh >/dev/null || { echo "zsh not found: skipping the zshrc tests"; exit 0; }
PY3=$(command -v python3) || { echo "python3 not found: the zshrc tests need a pty"; exit 2; }

RAW=$(nix eval --raw "$ROOT#nixosConfigurations.proxmox-agent.config.home-manager.users.lex.programs.zsh.initContent") || {
  echo "zshrc_test: nix eval failed" >&2
  exit 2
}

# fixture TMP: the plugin stubs, the shims, the ZDOTDIR with the generated .zshrc (store paths of the plugins replaced).
# Every stub appends a word to _t_load; the last two also record what was true at that moment.
fixture() {
  local d=$1 name cmds
  mkdir -p "$d/home" "$d/zd" "$d/shims" "$d/plug/site-functions" "$d/state"
  cat >"$d/plug/syntax.zsh" <<'EOF'
_t_load+=(syntax)
(( $+aliases[gs] )) && _t_aliases_first=1
_zsh_highlight() { :; }
EOF
  cat >"$d/plug/autosuggest.zsh" <<'EOF'
_t_load+=(autosuggest)
_zsh_autosuggest_start() { :; }
EOF
  cat >"$d/plug/substring.zsh" <<'EOF'
_t_load+=(substring)
history-substring-search-up() { :; }
EOF
  cat >"$d/plug/fzf-tab.zsh" <<'EOF'
_t_load+=(fzftab)
fzf-tab-complete() { :; }
enable-fzf-tab() { :; }
EOF
  cat >"$d/plug/fzf-tab-source.zsh" <<'EOF'
_t_load+=(fzftabsource)
_t_compdef_known_at_last_plugin=$+functions[compdef]
EOF
  printf '#compdef fixturecmd\n_fixturecmd() { :; }\n' >"$d/plug/site-functions/_fixturecmd"
  # the shims: every command that an alias of the Mac names, so that a call at load time is seen
  cmds=$(grep -E '^alias [^=]+=' "$ROOT/home/zsh/config/aliases.zsh" | sed -E "s/^alias [^=]+=[\"']?//" | awk '{print $1}' | tr -d "\"'" | sort -u)
  for name in $cmds colima lazygit lazydocker pnpm uv bun brew zap open sdl-freerdp gdu-go kubectl sudo; do
    case $name in ls | cp | mv | df | free | clear | exit | eval) continue ;; esac
    printf '#!/bin/sh\nprintf "%%s %%s\\n" "%s" "$*" >>"%s/calls.log"\nexit 0\n' "$name" "$d" >"$d/shims/$name"
    chmod +x "$d/shims/$name"
  done
  : >"$d/calls.log"
  printf 'setopt no_global_rcs\n' >"$d/zd/.zshenv"
  printf '%s\n' "$RAW" |
    sed -E \
      -e "s#/nix/store/[a-z0-9]{32}-zsh-syntax-highlighting-[0-9.]+/share/zsh-syntax-highlighting/zsh-syntax-highlighting\.zsh#$d/plug/syntax.zsh#" \
      -e "s#/nix/store/[a-z0-9]{32}-zsh-autosuggestions-[0-9.]+/share/zsh-autosuggestions/zsh-autosuggestions\.zsh#$d/plug/autosuggest.zsh#" \
      -e "s#/nix/store/[a-z0-9]{32}-zsh-history-substring-search-[0-9.]+/share/zsh-history-substring-search/zsh-history-substring-search\.zsh#$d/plug/substring.zsh#" \
      -e "s#/nix/store/[a-z0-9]{32}-zsh-fzf-tab-[0-9.]+/share/fzf-tab/fzf-tab\.plugin\.zsh#$d/plug/fzf-tab.zsh#" \
      -e "s#/nix/store/[a-z0-9]{32}-source/fzf-tab-source\.plugin\.zsh#$d/plug/fzf-tab-source.zsh#" \
      -e "s#/nix/store/[a-z0-9]{32}-zsh-completions-[0-9.]+/share/zsh/site-functions#$d/plug/site-functions#" \
      -e "s#eval \"\\$\\(/nix/store/[^ ]*/bin/(starship|mise|direnv) [^)]*\\)\"#true#" \
      -e "s#/home/lex#$d/home#g" \
      >"$d/zd/.zshrc"
}

# The system files of the machine that runs the test (/etc/zshenv of nix-darwin sets EDITOR and puts its own PATH in front) are
# switched off with the variables that make them return at once: the test is about ~/.zshrc.
# ptyrun DIR ZSH-ARGS...: zsh in a real terminal (a pty of its own: stdin, stdout and stderr are its slave side), HOME and ZDOTDIR
# of the fixture; the output (CRs dropped) on stdout. A shell that runs longer than 60 s is killed.
PTY_PY='import fcntl, os, pty, signal, sys, time
pid, fd = pty.fork()
if pid == 0:
    os.execvp(sys.argv[1], sys.argv[1:])
fcntl.fcntl(fd, fcntl.F_SETFL, fcntl.fcntl(fd, fcntl.F_GETFL) | os.O_NONBLOCK)
out, end, status = b"", time.time() + 60, None
while status is None and time.time() < end:
    try:
        data = os.read(fd, 65536)
        if not data:
            break
        out += data
        continue
    except BlockingIOError:
        pass
    except OSError:
        break
    done, st = os.waitpid(pid, os.WNOHANG)
    if done:
        status = st
    else:
        time.sleep(0.01)
if status is None:
    try:
        os.kill(pid, signal.SIGKILL)
    except ProcessLookupError:
        pass
    status = os.waitpid(pid, 0)[1]
try:
    while True:
        data = os.read(fd, 65536)
        if not data:
            break
        out += data
except OSError:
    pass
sys.stdout.buffer.write(out)
sys.exit(os.waitstatus_to_exitcode(status))'
ptyrun() {
  local d=$1
  shift
  env -i HOME="$d/home" ZDOTDIR="$d/zd" PATH="$d/shims:/usr/bin:/bin" TERM=xterm-256color __ETC_ZSHENV_SOURCED=1 __ETC_ZSHRC_SOURCED=1 __NIX_DARWIN_SET_ENVIRONMENT_DONE=1 __NIXOS_SET_ENVIRONMENT_DONE=1 \
    "$PY3" -c "$PTY_PY" zsh "$@" 2>&1 | LC_ALL=C tr -d '\r'
}
# plainrun DIR ZSH-ARGS...: the same without a terminal (stdin and stdout are not ttys).
plainrun() {
  local d=$1
  shift
  env -i HOME="$d/home" ZDOTDIR="$d/zd" PATH="$d/shims:/usr/bin:/bin" TERM=xterm-256color __ETC_ZSHENV_SOURCED=1 __ETC_ZSHRC_SOURCED=1 __NIX_DARWIN_SET_ENVIRONMENT_DONE=1 __NIXOS_SET_ENVIRONMENT_DONE=1 zsh "$@" </dev/null 2>&1
}
RESULT='print -r -- "R load=${_t_load} aliasesfirst=${_t_aliases_first-0} compdefknown=${_t_compdef_known_at_last_plugin-?} editor=$EDITOR visual=$VISUAL fixturecmd=${_comps[fixturecmd]-none} gs=${aliases[gs]-none} ld=${aliases[ld]-none} home=$(bindkey "^[[H")"'

test_a_real_terminal_loads_the_mac_files_then_the_plugins_then_compinit_once() {
  fixture "$T/a"
  local out
  out=$(ptyrun "$T/a" -i -c "$RESULT")
  assert_has "the plugins loaded in the order of the Mac's zshrc" <(printf '%s\n' "$out") "R load=syntax autosuggest substring fzftab fzftabsource "
  assert_has "the Mac's aliases were already there when the first plugin loaded" <(printf '%s\n' "$out") "aliasesfirst=1"
  assert_has "compinit had not run when the last plugin loaded" <(printf '%s\n' "$out") "compdefknown=0"
  assert_has "a completer of the zsh-completions fpath entry is registered in \$_comps (compinit ran after the fpath was extended)" <(printf '%s\n' "$out") "fixturecmd=_fixturecmd"
  assert_has "alias gs is the Mac's" <(printf '%s\n' "$out") "gs=git status"
  assert_has "alias ld is the Mac's" <(printf '%s\n' "$out") "ld=lazydocker"
  assert_has "a binding of keybindings.zsh (Home key) is in place" <(printf '%s\n' "$out") 'home="^[[H" beginning-of-line'
  assert_eq "nothing but the result line was printed at startup" "1" "$(printf '%s\n' "$out" | grep -c .)"
  local trace
  trace=$(ptyrun "$T/a" -i -x -c true | grep -cE '> compinit( |$)')
  assert_eq "compinit is called exactly once" 1 "$trace"
}

test_compinit_is_cached_like_the_mac_and_refreshed_when_the_system_or_the_day_changes() {
  fixture "$T/b"
  local cache=$T/b/home/.cache/zsh
  ptyrun "$T/b" -i -c true >/dev/null
  assert_eq "the first start dumps" yes "$([ -f "$cache/zcompdump" ] && echo yes)"
  assert_eq "and records which system it is for" yes "$([ -s "$cache/zcompdump.key" ] && echo yes)"
  assert_eq "a start within the day, for the same system, takes the dump as it is (compinit -C)" 1 "$(ptyrun "$T/b" -i -x -c true | grep -cE '> compinit -C ')"
  assert_eq "and does not run the check" 0 "$(ptyrun "$T/b" -i -x -c true | grep -cE '> compinit -d ')"
  # another system (a deploy changed the packages): the dump is rebuilt, whatever its age
  printf 'some-other-system' >"$cache/zcompdump.key"
  assert_eq "a dump for another system is rebuilt (full compinit)" 1 "$(ptyrun "$T/b" -i -x -c true | grep -cE '> compinit -d ')"
  assert_eq "and the key is the current one again" 0 "$([ "$(cat "$cache/zcompdump.key")" = some-other-system ] && echo 1 || echo 0)"
  # a day later
  touch -t 202001010000 "$cache/zcompdump"
  assert_eq "a dump older than a day is rebuilt (full compinit)" 1 "$(ptyrun "$T/b" -i -x -c true | grep -cE '> compinit -d ')"
}

test_a_stale_dump_from_before_the_plugins_does_not_hide_a_completer() {
  fixture "$T/c"
  local cache=$T/c/home/.cache/zsh
  mkdir -p "$cache"
  # a dump that knows no fixturecmd, young, with the key of another system: what the earlier compinit of /etc/zshrc left
  printf '#files: 0\tversion: 5.9\n_comps=()\n' >"$cache/zcompdump"
  printf 'the-system-before-the-deploy' >"$cache/zcompdump.key"
  assert_has "the completer is registered" <(ptyrun "$T/c" -i -c "$RESULT") "fixturecmd=_fixturecmd"
}

test_the_editor_is_vim_when_nvim_is_absent_and_the_one_of_options_zsh_when_it_is_there() {
  fixture "$T/d"
  rm -f "$T/d/shims/nvim" # the shims name every command of an alias, nvim too
  assert_has "no nvim: EDITOR and VISUAL are vim, not the text of a failed which" <(ptyrun "$T/d" -i -c "$RESULT") "editor=vim visual=vim"
  printf '#!/bin/sh\nexit 0\n' >"$T/d/shims/nvim"
  chmod +x "$T/d/shims/nvim"
  assert_has "with nvim: options.zsh's value stays" <(ptyrun "$T/d" -i -c "$RESULT") "editor=$T/d/shims/nvim visual=$T/d/shims/nvim"
}

test_a_shell_without_a_terminal_loads_no_plugin_and_prints_nothing() {
  fixture "$T/e"
  local out
  out=$(plainrun "$T/e" -i -c "$RESULT")
  assert_eq "zsh -i without a tty prints the line of the command and nothing else" 1 "$(printf '%s\n' "$out" | grep -c .)"
  assert_has "no plugin was loaded, there is no alias of the Mac and no completer" <(printf '%s\n' "$out") "R load= aliasesfirst=0 compdefknown=? editor= visual= fixturecmd=none gs=none ld=none"
  assert_eq "zsh -c prints what the command prints and nothing else" "x" "$(plainrun "$T/e" -c 'print -r -- x')"
  assert_eq "zsh -lc too" "x" "$(plainrun "$T/e" -lc 'print -r -- x')"
  assert_eq "no completion dump was made" "no" "$([ -e "$T/e/home/.cache/zsh/zcompdump" ] && echo yes || echo no)"
}

test_loading_the_files_runs_none_of_the_commands_that_the_aliases_name() {
  fixture "$T/f"
  ptyrun "$T/f" -i -c true >/dev/null
  assert_eq "no command was called while the Mac's files and the plugins loaded" "" "$(cat "$T/f/calls.log")"
  # a positive control: the detector sees a call of one of those commands when the shell makes one
  ptyrun "$T/f" -i -c 'gs' >/dev/null
  assert_has "the shim logs what a call looks like (alias gs runs git)" "$T/f/calls.log" "git status"
}

tl_init_pure
tl_run_all
tl_done
