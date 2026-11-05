#!/usr/bin/env bash
# Tests for hosts/windows/win-authorize.sh: a Windows host's key goes into authorized_keys on the hosts it logs in
# to. secretspec, ssh and gh are stubs (bin/<name> -> stub) with their state in $T/st. The ssh stub runs the
# command it gets with a plain sh, as the remote host would, with HOME set to $T/st/hosts/<alias>, so the script
# that edits authorized_keys is the real one. The host list is the repo's (hosts/windows/rex/ssh-hosts.txt).
set -uo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
# shellcheck source=../../home/secretspec/testlib.sh
. "$ROOT/home/secretspec/testlib.sh" || exit 1

write_stub() {
  cat >"$T/stub" <<'STUB'
#!/usr/bin/env bash
S=${STUB_STATE:?}
name=$(basename "$0")
case $name in
  secretspec)
    if [ -f "$S/vault/$2" ]; then cat "$S/vault/$2"; else printf '{}'; fi ;;
  ssh)
    while [[ ${1:-} == -o ]]; do shift 2; done
    alias=$1
    shift
    if grep -qx "$alias" "$S/down" 2>/dev/null; then
      echo "ssh: connect to host $alias port 22: Operation timed out" >&2
      exit 255
    fi
    echo "ssh $alias" >>"$S/calls"
    mkdir -p "$S/hosts/$alias"
    HOME=$S/hosts/$alias exec sh -c "$*" ;;
  gh)
    case $1 in
      api) cat "$S/gh-keys" ;;
      ssh-key)
        if [ -e "$S/gh-noscope" ]; then echo "HTTP 404: Not Found (https://api.github.com/user/keys)" >&2; exit 1; fi
        awk '{print $1" "$2}' "$3" >>"$S/gh-keys"
        echo "gh ssh-key add $5" >>"$S/calls" ;;
    esac ;;
esac
STUB
  chmod +x "$T/stub"
}

# world: the stubs, and a key for rex in the vault map WIN_SSH_KEYS.
world() {
  S=$T/st
  mkdir -p "$S/vault" "$S/hosts"
  write_stub
  for c in secretspec ssh gh; do ln -sf "$T/stub" "$T_SHIM/$c"; done
  ssh-keygen -q -t ed25519 -N '' -C user@rex -f "$T/k" </dev/null >/dev/null
  jq -n --rawfile k "$T/k" '{rex: ($k | rtrimstr("\n"))}' >"$S/vault/WIN_SSH_KEYS"
  PUB=$(cat "$T/k.pub")
  : >"$S/gh-keys"
  : >"$S/calls"
  export STUB_STATE=$S HOME=$T_HOME TMPDIR=$T/tmp PATH=$T_SHIM:$PATH
}

authorize() {
  bash "$ROOT/hosts/windows/win-authorize.sh" rex >"$T/out" 2>"$T/err"
  rc=$?
}

# keys ALIAS: the lines of that host's authorized_keys.
keys() { cat "$S/hosts/$1/.ssh/authorized_keys" 2>/dev/null; }

test_every_host_gets_the_key_once() {
  world
  authorize
  assert_rc "first run" "$rc" 0
  local a
  for a in home pxc_hermes pxc_lab pxc_root px_lab px_root; do
    assert_eq "$a holds the key" "$PUB" "$(keys "$a")"
    assert_has "$a is reported as changed" "$T/out" "changed: $a: key added"
  done
  assert_eq "the new file is the user's only" "600" "$(stat -f %Lp "$S/hosts/home/.ssh/authorized_keys")"
  assert_eq "and so is the new directory" "700" "$(stat -f %Lp "$S/hosts/home/.ssh")"
  assert_eq "GitHub holds it" "$(awk '{print $1" "$2}' "$T/k.pub")" "$(cat "$S/gh-keys")"
  assert_has "under the host's name" "$S/calls" "gh ssh-key add rex (Windows)"
  authorize
  assert_rc "second run" "$rc" 0
  assert_eq "no second line" "$PUB" "$(keys home)"
  assert_eq "seven ok lines" "7" "$(grep -c '^ok: ' "$T/out")"
  assert_eq "GitHub got it once" "1" "$(grep -c 'gh ssh-key add' "$S/calls")"
}

test_a_file_without_a_final_newline_keeps_its_last_line() {
  world
  mkdir -p "$S/hosts/home/.ssh"
  printf 'ssh-ed25519 AAAAother other@box' >"$S/hosts/home/.ssh/authorized_keys"
  chmod 644 "$S/hosts/home/.ssh/authorized_keys"
  authorize
  assert_eq "both lines" "$(printf 'ssh-ed25519 AAAAother other@box\n%s' "$PUB")" "$(keys home)"
  assert_eq "an existing file keeps its mode" "644" "$(stat -f %Lp "$S/hosts/home/.ssh/authorized_keys")"
}

test_the_key_counts_as_there_whatever_its_options_and_comment() {
  world
  mkdir -p "$S/hosts/home/.ssh"
  printf 'from="198.51.100.0/24" %s another@comment\n' "$(awk '{print $1" "$2}' "$T/k.pub")" >"$S/hosts/home/.ssh/authorized_keys"
  authorize
  assert_has "reported as there" "$T/out" "ok: home: the key is in ~/.ssh/authorized_keys"
  assert_eq "not added" "1" "$(keys home | wc -l | tr -d ' ')"
}

test_a_host_that_is_down_is_an_error_and_the_rest_still_run() {
  world
  echo px_root >"$S/down"
  authorize
  assert_rc "run" "$rc" 1
  assert_has "names the host" "$T/out" "error: px_root: ssh: connect to host px_root port 22: Operation timed out"
  assert_eq "a host after it still gets the key" "$PUB" "$(keys pxc_root)"
}

test_github_without_the_key_scope_says_how_to_get_it() {
  world
  touch "$S/gh-noscope"
  authorize
  assert_rc "run" "$rc" 1
  assert_has "the fix" "$T/out" "gh auth refresh -h github.com -s admin:public_key"
  assert_eq "the other hosts still get the key" "$PUB" "$(keys home)"
}

test_no_key_in_the_vault_is_an_error() {
  world
  echo '{}' >"$S/vault/WIN_SSH_KEYS"
  authorize
  assert_rc "run" "$rc" 1
  assert_has "says what to run" "$T/err" "run just win-sync first"
  assert_eq "no host was touched" "" "$(cat "$S/calls")"
}

tl_init_pure
tl_run_all
tl_done
