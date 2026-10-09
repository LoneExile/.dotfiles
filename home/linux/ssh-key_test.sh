#!/usr/bin/env bash
# Tests for home/linux/ssh-key.sh: the Home Manager activation step of the agent role that makes the user's ssh key for the jumphost
# (an ed25519 key made on the VM, never replaced, never printed). The real ssh-keygen is used (fixture HOME, no network, nothing
# else of the machine is touched); ssh-keygen shims stand in for a failing or a missing tool.
set -uo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
# shellcheck source=../secretspec/testlib.sh
. "$ROOT/home/secretspec/testlib.sh" || exit 1
# shellcheck source=minpath_testlib.sh
. "$ROOT/home/linux/minpath_testlib.sh" || exit 1
SCRIPT=$ROOT/home/linux/ssh-key.sh
REAL_MV=$(command -v mv)
KEYGEN=$(command -v ssh-keygen) || {
  echo "ssh-keygen not found" >&2
  exit 2
}

KEY() { echo "$T_HOME/.ssh/id_ed25519_jumphost"; }
# step [KEYGEN] [RUN-DEFINITION]: the activation step as Home Manager runs it (`run` is its wrapper); prints the exit status.
step() {
  (
    export HOME=$T_HOME
    PATH=$(minimal_path "$T/minbin")
    export PATH
    # shellcheck disable=SC2329 # called by ensure_ssh_key
    run() { "$@"; }
    [ -z "${2:-}" ] || eval "$2"
    # shellcheck source=ssh-key.sh
    . "$SCRIPT"
    ensure_ssh_key "${1:-$KEYGEN}" "$(KEY)" docker-jumphost
  ) >"$T/out" 2>"$T/err"
  echo $?
}
sum() { shasum -a 256 "$1" | cut -c1-64; }

test_makes_an_ed25519_key_for_the_user_when_there_is_none() {
  assert_rc "step" "$(step)" 0
  assert_eq "private key mode" 600 "$(tl_mode "$(KEY)")"
  assert_eq "public key is there" yes "$([ -s "$(KEY).pub" ] && echo yes)"
  assert_eq "it is an ed25519 key" "ED25519" "$("$KEYGEN" -l -f "$(KEY)" | awk '{print $NF}' | tr -d '()')"
  assert_eq "no passphrase (the public half can be derived without one)" yes "$("$KEYGEN" -y -P '' -f "$(KEY)" >/dev/null 2>&1 && echo yes)"
  assert_eq "the comment is user@host and the purpose, built at run time" "$(id -un)@$(uname -n) docker-jumphost" "$(cut -d' ' -f3- "$(KEY).pub")"
  assert_eq "the .ssh directory is made mode 700" 700 "$(tl_mode "$T_HOME/.ssh")"
  assert_has "says the fingerprint of the new key" "$T/out" "$("$KEYGEN" -l -f "$(KEY)" | awk '{print $2}')"
  assert_lacks "never prints the private key" "$T/out" "PRIVATE KEY"
  assert_lacks "not on stderr either" "$T/err" "PRIVATE KEY"
  assert_eq "no stray temporary file is left" 2 "$(ls -A "$T_HOME/.ssh" | wc -l | tr -d ' ')"
}

test_an_existing_key_is_never_replaced_and_a_second_run_changes_nothing() {
  assert_rc "first" "$(step)" 0
  local priv pub
  priv=$(sum "$(KEY)")
  pub=$(sum "$(KEY).pub")
  assert_rc "second" "$(step)" 0
  assert_eq "private key unchanged" "$priv" "$(sum "$(KEY)")"
  assert_eq "public key unchanged" "$pub" "$(sum "$(KEY).pub")"
  assert_has "says it kept it" "$T/out" "kept"
  assert_lacks "and makes no new one" "$T/out" "created"
}

test_a_key_of_the_user_with_no_public_half_gets_its_public_half_and_nothing_else() {
  mkdir -p "$T_HOME/.ssh"
  "$KEYGEN" -q -t ed25519 -N '' -C mine -f "$(KEY)"
  rm -f "$(KEY).pub"
  local priv
  priv=$(sum "$(KEY)")
  assert_rc "step" "$(step)" 0
  assert_eq "private key unchanged" "$priv" "$(sum "$(KEY)")"
  assert_eq "the public half is the one of that private key" "$("$KEYGEN" -y -f "$(KEY)" | cut -d' ' -f1-2)" "$(cut -d' ' -f1-2 "$(KEY).pub")"
}

test_a_key_of_another_type_or_with_another_public_half_is_left_alone() {
  mkdir -p "$T_HOME/.ssh"
  "$KEYGEN" -q -t rsa -b 2048 -N '' -C theirs -f "$(KEY)"
  printf 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOTHERKEYOTHERKEYOTHERKEYOTHERKEYOTHERKEYOTHERK elsewhere\n' >"$(KEY).pub"
  local priv pub
  priv=$(sum "$(KEY)")
  pub=$(sum "$(KEY).pub")
  assert_rc "step" "$(step)" 0
  assert_eq "private key unchanged" "$priv" "$(sum "$(KEY)")"
  assert_eq "public key unchanged" "$pub" "$(sum "$(KEY).pub")"
}

test_a_link_in_place_of_the_key_is_left_alone() {
  mkdir -p "$T_HOME/.ssh" "$T/elsewhere"
  ln -s "$T/elsewhere/key" "$(KEY)"
  assert_rc "step" "$(step)" 0
  assert_eq "the link stays a link" "$T/elsewhere/key" "$(readlink "$(KEY)")"
  assert_absent "nothing was written through it" "$T/elsewhere/key"
  assert_absent "no public half either" "$(KEY).pub"
}

test_an_existing_ssh_directory_keeps_its_mode() {
  mkdir -p "$T_HOME/.ssh"
  chmod 750 "$T_HOME/.ssh"
  assert_rc "step" "$(step)" 0
  assert_eq "mode unchanged" 750 "$(tl_mode "$T_HOME/.ssh")"
}

test_a_failing_ssh_keygen_is_reported_and_leaves_nothing_and_does_not_fail_the_activation() {
  mkdir -p "$T/bin"
  # fails, but only after it has written a partial file under the name it was given (-f NAME, the last argument)
  printf '#!/bin/sh\nfor a in "$@"; do last=$a; done\nprintf partial >"$last"\necho "ssh-keygen: boom" >&2\nexit 1\n' >"$T/bin/ssh-keygen"
  chmod +x "$T/bin/ssh-keygen"
  assert_rc "step" "$(step "$T/bin/ssh-keygen")" 0
  assert_has "says what failed" "$T/err" "could not"
  assert_absent "no private key" "$(KEY)"
  assert_absent "no public key" "$(KEY).pub"
  assert_eq "no temporary file" 0 "$(ls -A "$T_HOME/.ssh" 2>/dev/null | wc -l | tr -d ' ')"
}

test_a_key_that_appears_while_it_is_made_wins_and_is_never_overwritten() {
  mkdir -p "$T/bin" "$T_HOME/.ssh"
  # the real ssh-keygen, and then, in the call that makes the key, another process puts its own key in place before the move
  printf '#!/bin/sh\n"%s" "$@" || exit $?\ncase " $* " in *" -t "*) printf "planted private" >"%s"; printf "planted public" >"%s.pub" ;; esac\n' "$KEYGEN" "$(KEY)" "$(KEY)" >"$T/bin/ssh-keygen"
  chmod +x "$T/bin/ssh-keygen"
  step "$T/bin/ssh-keygen" >/dev/null
  assert_eq "the planted private key stays" "planted private" "$(cat "$(KEY)")"
  assert_eq "the planted public key stays" "planted public" "$(cat "$(KEY).pub")"
  assert_eq "no temporary file is left" 2 "$(ls -A "$T_HOME/.ssh" | wc -l | tr -d ' ')"
}

test_the_private_key_is_moved_into_place_before_the_public_half() {
  minimal_path "$T/minbin" >/dev/null
  rm -f "$T/minbin/mv"
  printf '#!/bin/sh\nprintf "%%s\\n" "$*" >>"%s/mv.log"\nexec "%s" "$@"\n' "$T" "$REAL_MV" >"$T/minbin/mv"
  chmod +x "$T/minbin/mv"
  assert_rc "step" "$(step)" 0
  assert_eq "two moves" 2 "$(grep -c '' "$T/mv.log")"
  local first second
  first=$(sed -n 1p "$T/mv.log")
  second=$(sed -n 2p "$T/mv.log")
  assert_eq "the first move puts the private key in place" "$(KEY)" "${first##* }"
  assert_eq "the second move puts the public half in place" "$(KEY).pub" "${second##* }"
}

test_a_public_half_without_its_private_key_is_left_alone_and_no_key_is_made() {
  mkdir -p "$T_HOME/.ssh"
  printf 'stale public' >"$(KEY).pub"
  assert_rc "step" "$(step)" 0
  assert_eq "the public half is as it was" "stale public" "$(cat "$(KEY).pub")"
  assert_absent "no private key" "$(KEY)"
  assert_has "says why" "$T/err" "without its private key"
  assert_eq "nothing else in .ssh" 1 "$(ls -A "$T_HOME/.ssh" | wc -l | tr -d ' ')"
}

test_a_dry_run_makes_nothing() {
  assert_rc "step" "$(step "$KEYGEN" 'run() { echo "would run: $*"; }')" 0
  assert_absent "no private key" "$(KEY)"
  assert_absent "no public key" "$(KEY).pub"
}

tl_init_pure
tl_run_all
tl_done
