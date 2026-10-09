#!/usr/bin/env bash
# Tests for infra/vm-jumphost-authorize.sh and infra/vm-jumphost-authorize-remote.sh: the Mac fetches the PUBLIC key that the agent VM made
# for the jumphost and appends it, restricted to `docker system dial-stdio`, to the jumphost's authorized_keys: backup first, atomic,
# once, and never touching another line. The `ssh` shim stands for both machines: the VM is a fixture file, the jumphost a directory (the
# remote command runs here as its "user", HOME set to that directory). Fixture keys made here, RFC 5737 addresses, invented names.
set -uo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../home/secretspec/testlib.sh
. "$ROOT/home/secretspec/testlib.sh" || exit 1
for c in jq base64 ssh-keygen od shasum; do
  command -v "$c" >/dev/null || {
    echo "$c not found on PATH" >&2
    exit 2
  }
done
REAL_KEYGEN=$(command -v ssh-keygen)
SCRIPT=$ROOT/infra/vm-jumphost-authorize.sh
VMS='{"testvm-alpha":{"node":"n1","vmid":901,"role":"agent"},"testvm-clean":{"node":"n1","vmid":902}}'

# world [VM-PUB-FILE-CONTENT]: shims in $T/bin, a jumphost home in $T/jh with one authorized key, a VM public key.
world() {
  mkdir -p "$T/bin" "$T/store" "$T/jh/.ssh" "$T/vmhome/.ssh"
  printf '%s' "$VMS" >"$T/store/TF_VAR_vms"
  "$REAL_KEYGEN" -q -t ed25519 -N '' -C 'lex@testvm docker-jumphost' -f "$T/vmkey"
  "$REAL_KEYGEN" -q -t ed25519 -N '' -C unit-cloud -f "$T/oldkey"
  cp "$T/vmkey.pub" "$T/vm.pub"
  ln -s "$T/vm.pub" "$T/vmhome/.ssh/id_ed25519_jumphost.pub"
  # the one key that the jumphost has today, no trailing newline question: written as it is on a real host (newline-terminated)
  cp "$T/oldkey.pub" "$T/jh/.ssh/authorized_keys"
  chmod 600 "$T/jh/.ssh/authorized_keys"
  cp "$T/jh/.ssh/authorized_keys" "$T/ak.orig"
  cat >"$T/bin/secretspec" <<'EOF'
#!/bin/sh
case "$1" in run) shift; [ "$1" = -- ] && shift; TF_VAR_vms=$(cat "$STUB_DIR/TF_VAR_vms") exec "$@" ;; esac
EOF
  cat >"$T/bin/terragrunt" <<'EOF'
#!/bin/sh
printf '{"testvm-alpha":{"ip":"203.0.113.10"},"testvm-clean":{"ip":"203.0.113.11"}}'
EOF
  cat >"$T/bin/ssh" <<'EOF'
#!/bin/sh
# options with a value are skipped; the host is the first word; every call is logged
while [ $# -gt 0 ]; do
  case "$1" in
    -o | -l | -p | -i | -F | -J | -E | -S | -c | -m) shift 2 ;;
    -*) shift ;;
    *) break ;;
  esac
done
host=$1
shift
printf 'ssh %s %s\n' "$host" "$*" >>"$STUB_SSHLOG"
case "$host" in
  lex@203.0.113.10 | lex@203.0.113.11)
    case "$*" in
      true)
        case "${STUB_HOSTKEY:-pinned}" in
          unpinned) echo "Host key verification failed." >&2; exit 255 ;;
          changed) echo "WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!" >&2; exit 255 ;;
        esac
        exit 0 ;;
      *id_ed25519_jumphost.pub*) cd "$STUB_VM_HOME" && HOME="$STUB_VM_HOME" exec bash -c "$*" ;;
      *) exit 0 ;;
    esac ;;
  jumphost_server) cd "$STUB_JH_HOME" && HOME="$STUB_JH_HOME" exec bash -c "$*" ;;
  *) echo "unexpected host $host" >&2; exit 99 ;;
esac
EOF
  chmod +x "$T/bin/"*
  : >"$T/sshlog"
  export STUB_DIR="$T/store" STUB_SSHLOG="$T/sshlog" STUB_VM_HOME="$T/vmhome" STUB_JH_HOME="$T/jh" PATH="$T/bin:$PATH"
}
run() { bash "$SCRIPT" "${1:-testvm-alpha}" "$ROOT" >"$T/out" 2>"$T/err"; echo $?; }
AK() { echo "$T/jh/.ssh/authorized_keys"; }
jh_calls() { grep -c ' jumphost_server ' "$T/sshlog"; }
backups() { find "$T/jh/.ssh" -name 'authorized_keys.bak-*' | wc -l | tr -d ' '; }
blob_of() { awk '{print $2}' "$1"; }
sum() { shasum -a 256 "$1" | cut -c1-64; }
# the jumphost's account files are untouched and nothing else is there
# shellcheck disable=SC2010 # the names are the fixture's own
only_expected_files() { ls -A "$T/jh/.ssh" | grep -vc '^authorized_keys\(\.bak-.*\)\?$'; }

test_appends_the_restricted_line_after_a_backup_and_leaves_the_existing_line_byte_for_byte() {
  world
  assert_rc "run" "$(run)" 0
  assert_eq "two lines now" 2 "$(grep -c '' "$(AK)")"
  assert_eq "the first line is the old one, byte for byte" "$(sed -n 1p "$T/ak.orig")" "$(sed -n 1p "$(AK)")"
  assert_eq "the old file is the beginning of the new one" "" "$(head -c "$(wc -c <"$T/ak.orig" | tr -d ' ')" "$(AK)" | cmp - "$T/ak.orig" 2>&1)"
  assert_eq "the second line is exactly the restricted form of the VM's key, with its comment" "restrict,command=\"docker system dial-stdio\" ssh-ed25519 $(blob_of "$T/vm.pub") testvm-alpha docker-jumphost" "$(sed -n 2p "$(AK)")"
  assert_eq "one backup" 1 "$(backups)"
  assert_eq "the backup is the old file" "$(sum "$T/ak.orig")" "$(sum "$(find "$T/jh/.ssh" -name 'authorized_keys.bak-*' | head -n 1)")"
  assert_eq "backup mode 600" 600 "$(tl_mode "$(find "$T/jh/.ssh" -name 'authorized_keys.bak-*' | head -n 1)")"
  assert_eq "authorized_keys mode 600" 600 "$(tl_mode "$(AK)")"
  assert_eq "no temporary file is left" 0 "$(only_expected_files)"
  assert_has "says the fingerprint of the key it authorized" "$T/out" "$("$REAL_KEYGEN" -l -f "$T/vm.pub" | awk '{print $2}')"
  assert_lacks "never prints a private key" "$T/out" "PRIVATE KEY"
}

test_a_second_run_changes_nothing_and_makes_no_second_backup() {
  world
  assert_rc "first" "$(run)" 0
  local after
  after=$(sum "$(AK)")
  assert_rc "second" "$(run)" 0
  assert_eq "still two lines" 2 "$(grep -c '' "$(AK)")"
  assert_eq "file unchanged" "$after" "$(sum "$(AK)")"
  assert_eq "still one backup" 1 "$(backups)"
  assert_has "says so" "$T/out" "already authorized"
}

test_every_other_line_survives_a_file_without_a_final_newline_and_with_comments_and_blank_lines() {
  world
  printf '# my own note\n\n%s' "$(cat "$T/oldkey.pub")" >"$(AK)"
  cp "$(AK)" "$T/ak.orig"
  assert_rc "run" "$(run)" 0
  assert_eq "the old content is the beginning of the new file (apart from the newline that ends its last line)" "" "$(head -c "$(wc -c <"$T/ak.orig" | tr -d ' ')" "$(AK)" | cmp - "$T/ak.orig" 2>&1)"
  assert_eq "four lines: note, blank, old key, new key" 4 "$(grep -c '' "$(AK)")"
  assert_eq "the old key line is the same" "$(cat "$T/oldkey.pub" | tr -d '\n')" "$(sed -n 3p "$(AK)")"
}

test_a_missing_authorized_keys_is_made_with_the_one_line_and_mode_600_and_no_backup() {
  world
  rm -f "$(AK)"
  assert_rc "run" "$(run)" 0
  assert_eq "one line" 1 "$(grep -c '' "$(AK)")"
  assert_eq "mode 600" 600 "$(tl_mode "$(AK)")"
  assert_eq "no backup of nothing" 0 "$(backups)"
  assert_has "restricted" "$(AK)" 'restrict,command="docker system dial-stdio" ssh-ed25519 '
}

test_the_same_key_with_other_options_is_never_changed_and_is_reported() {
  world
  printf 'ssh-ed25519 %s sneaky\n' "$(blob_of "$T/vm.pub")" >>"$(AK)"
  cp "$(AK)" "$T/ak.orig"
  assert_rc "run" "$(run)" 1
  assert_eq "file unchanged" "$(sum "$T/ak.orig")" "$(sum "$(AK)")"
  assert_eq "no backup" 0 "$(backups)"
  assert_has "says why" "$T/err" "other options"
}

test_the_same_restricted_key_with_another_comment_is_already_authorized_and_changes_nothing() {
  world
  assert_rc "first" "$(run)" 0
  # the line was written earlier with another comment (an older run, or by hand)
  sed -i.orig 's/ testvm-alpha docker-jumphost$/ an old comment/' "$(AK)"
  rm -f "$(AK).orig"
  local after
  after=$(sum "$(AK)")
  assert_rc "second" "$(run)" 0
  assert_eq "file unchanged" "$after" "$(sum "$(AK)")"
  assert_eq "still two lines" 2 "$(grep -c '' "$(AK)")"
  assert_eq "still one backup" 1 "$(backups)"
  assert_has "says so" "$T/out" "already authorized"
}

test_the_remote_script_writes_nothing_but_the_restricted_form_of_the_key() {
  world
  local blob b64
  blob=$(blob_of "$T/vmkey.pub")
  for bad in "ssh-ed25519 $blob x" "command=\"/bin/sh\" ssh-ed25519 $blob x" "restrict,command=\"/bin/sh\" ssh-ed25519 $blob x" "restrict,command=\"docker system dial-stdio\" ssh-ed25519 $blob"; do
    b64=$(printf '%s' "$bad" | base64 | tr -d '\n')
    assert_rc "refused: ${bad:0:40}" "$(cd "$T/jh" && HOME="$T/jh" bash "$ROOT/infra/vm-jumphost-authorize-remote.sh" "$b64" >/dev/null 2>&1; echo $?)" 2
    assert_eq "authorized_keys unchanged: ${bad:0:40}" "$(sum "$T/ak.orig")" "$(sum "$(AK)")"
  done
  assert_eq "no backup was made" 0 "$(backups)"
}

test_a_link_in_place_of_authorized_keys_is_refused() {
  world
  mv "$(AK)" "$T/real-ak"
  ln -s "$T/real-ak" "$(AK)"
  assert_rc "run" "$(run)" 1
  assert_eq "still a link" "$T/real-ak" "$(readlink "$(AK)")"
  assert_eq "the target unchanged" "$(sum "$T/ak.orig")" "$(sum "$T/real-ak")"
}

test_a_key_that_is_not_ed25519_or_is_malformed_is_refused_before_the_jumphost_is_touched() {
  world
  local bad good blob
  good=$(cat "$T/vmkey.pub")
  blob=$(blob_of "$T/vmkey.pub")
  "$REAL_KEYGEN" -q -t rsa -b 2048 -N '' -C rsa -f "$T/rsakey"
  "$REAL_KEYGEN" -q -t ecdsa -b 256 -N '' -C ecdsa -f "$T/eckey"
  local -a cases=(
    "rsa|$(cat "$T/rsakey.pub")"
    "ecdsa|$(cat "$T/eckey.pub")"
    "sk-ed25519|sk-ssh-ed25519@openssh.com $blob x"
    "cert|ssh-ed25519-cert-v01@openssh.com $blob x"
    "empty|"
    "type only|ssh-ed25519"
    "no blob|ssh-ed25519  comment"
    "not base64|ssh-ed25519 !!!notbase64!!! x"
    "truncated|ssh-ed25519 ${blob:0:40} x"
    "padded to look longer|ssh-ed25519 ${blob}AAAA x"
    "blob of another type|ssh-ed25519 $(blob_of "$T/rsakey.pub") x"
    "68 characters that are not a key|ssh-ed25519 $(printf 'A%.0s' $(seq 1 68)) x"
    "options in front|command=\"/bin/sh\" $good"
    "two keys|$good
$(cat "$T/oldkey.pub")"
    "a second line injecting an option|$good
restrict,command=\"/bin/sh\" ssh-ed25519 $blob y"
    "a leading line|# comment
$good"
  )
  for bad in "${cases[@]}"; do
    printf '%s\n' "${bad#*|}" >"$T/vm.pub"
    : >"$T/sshlog"
    assert_rc "refused: ${bad%%|*}" "$(run)" 1
    assert_eq "the jumphost was not contacted: ${bad%%|*}" 0 "$(jh_calls)"
    assert_eq "authorized_keys unchanged: ${bad%%|*}" "$(sum "$T/ak.orig")" "$(sum "$(AK)")"
  done
}

test_a_lenient_base64_cannot_let_junk_characters_into_the_key_line() {
  world
  # a decoder that ignores every character outside the alphabet (some platforms' base64 does): the key stays valid after the junk is dropped
  mkdir -p "$T/lenient"
  # shellcheck disable=SC2016 # the shim's own variables, expanded when it runs
  printf '#!/bin/sh\nif [ "${1:-}" = -d ] || [ "${1:-}" = -D ]; then tr -cd "A-Za-z0-9+/=" | "%s" "$@"; else exec "%s" "$@"; fi\n' "$(command -v base64)" "$(command -v base64)" >"$T/lenient/base64"
  chmod +x "$T/lenient/base64"
  local blob
  blob=$(blob_of "$T/vmkey.pub")
  printf 'ssh-ed25519 %s;"%s c\n' "${blob:0:20}" "${blob:20}" >"$T/vm.pub"
  assert_rc "refused" "$(PATH="$T/lenient:$PATH" run)" 1
  assert_eq "the jumphost was not contacted" 0 "$(jh_calls)"
  assert_eq "authorized_keys unchanged" "$(sum "$T/ak.orig")" "$(sum "$(AK)")"
}

test_a_host_key_of_the_vm_that_is_not_pinned_or_has_changed_stops_it_before_anything_is_read_or_changed() {
  world
  local state
  for state in unpinned changed; do
    : >"$T/sshlog"
    assert_rc "refused: $state" "$(STUB_HOSTKEY=$state run)" 1
    assert_has "says the host key: $state" "$T/err" "host key"
    assert_eq "the public key was not read: $state" 0 "$(grep -c 'id_ed25519_jumphost.pub' "$T/sshlog")"
    assert_eq "the jumphost was not contacted: $state" 0 "$(jh_calls)"
    assert_eq "authorized_keys unchanged: $state" "$(sum "$T/ak.orig")" "$(sum "$(AK)")"
  done
}

test_a_directory_in_place_of_authorized_keys_is_refused_and_nothing_goes_into_it() {
  world
  rm -f "$(AK)"
  mkdir "$(AK)"
  : >"$(AK)/keep"
  assert_rc "run" "$(run)" 1
  assert_eq "still a directory" yes "$([ -d "$(AK)" ] && echo yes)"
  assert_eq "only what was there" keep "$(ls -A "$(AK)")"
}

test_a_backup_of_a_world_readable_file_is_mode_600_and_so_is_the_new_file() {
  world
  chmod 644 "$(AK)"
  assert_rc "run" "$(run)" 0
  assert_eq "one backup" 1 "$(backups)"
  assert_eq "backup mode 600" 600 "$(tl_mode "$(find "$T/jh/.ssh" -name 'authorized_keys.bak-*' | head -n 1)")"
  assert_eq "authorized_keys mode 600" 600 "$(tl_mode "$(AK)")"
}

test_the_comment_is_made_on_the_mac_from_the_vm_name_whatever_the_vm_wrote() {
  world
  printf 'ssh-ed25519 %s lex@x" ; command="/bin/sh" $(id) `id` \\ end\n' "$(blob_of "$T/vmkey.pub")" >"$T/vm.pub"
  assert_rc "run" "$(run)" 0
  assert_eq "the line is exactly the restricted form, with the VM name as its comment" "restrict,command=\"docker system dial-stdio\" ssh-ed25519 $(blob_of "$T/vmkey.pub") testvm-alpha docker-jumphost" "$(sed -n 2p "$(AK)")"
  assert_eq "exactly two double quotes in the line" 2 "$(sed -n 2p "$(AK)" | tr -cd '"' | wc -c | tr -d ' ')"
}

test_a_vm_name_with_odd_characters_is_refused_before_anything_runs() {
  world
  local n
  for n in 'a;b' 'a b' 'a"b' '-x' 'a$(id)' 'a/b'; do
    : >"$T/sshlog"
    assert_rc "refused: $n" "$(run "$n")" 1
    assert_has "says why: $n" "$T/err" "not a valid VM name"
    assert_eq "nothing was contacted: $n" 0 "$(wc -l <"$T/sshlog" | tr -d ' ')"
  done
}

test_the_public_half_is_read_bounded_and_only_from_a_regular_file() {
  world
  assert_rc "run" "$(run)" 0
  assert_has "the remote command tests for a regular file" "$T/sshlog" "test -f"
  assert_has "and reads a bounded number of bytes" "$T/sshlog" "head -c 2048"
  : >"$T/sshlog"
  head -c 100000 /dev/zero | tr '\0' 'A' >"$T/vm.pub"
  assert_rc "a huge file is refused" "$(run)" 1
  assert_eq "the jumphost was not contacted" 0 "$(jh_calls)"
  rm -f "$T/vm.pub"
  mkdir "$T/vm.pub"
  assert_rc "a directory is refused" "$(run)" 1
  assert_eq "the jumphost was not contacted (directory)" 0 "$(jh_calls)"
}

test_a_vm_without_the_key_yet_is_told_to_deploy_and_the_jumphost_is_not_touched() {
  world
  rm -f "$T/vm.pub"
  assert_rc "run" "$(run)" 1
  assert_has "says what to do" "$T/err" "deploy"
  assert_eq "the jumphost was not contacted" 0 "$(jh_calls)"
}

test_a_vm_of_the_clean_role_is_refused() {
  world
  assert_rc "run" "$(run testvm-clean)" 1
  assert_has "says why" "$T/err" "clean"
  assert_eq "the jumphost was not contacted" 0 "$(jh_calls)"
}

test_the_jumphost_being_down_is_an_error_and_changes_nothing() {
  world
  mkdir -p "$T/bin2"
  sed 's#exec bash -c "\$\*"#exit 255#' "$T/bin/ssh" >"$T/bin2/ssh"
  chmod +x "$T/bin2/ssh"
  assert_rc "run" "$(PATH="$T/bin2:$PATH" run)" 1
  assert_eq "file unchanged" "$(sum "$T/ak.orig")" "$(sum "$(AK)")"
}

tl_init_pure
tl_run_all
tl_done
