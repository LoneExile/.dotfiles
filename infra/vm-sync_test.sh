#!/usr/bin/env bash
# Tests for the Mac side of the VM sync: infra/vm-hindsight-entry.sh (the Hindsight URL and key of one
# VM out of the vault map), infra/vm-sync.sh and infra/vm-sync-lib.sh (Hindsight file and skills to the agent user of a VM),
# and the removal that vm-deploy runs before a VM leaves the agent role. The VM is a directory:
# the `ssh` shim runs the remote command here, as the "user", with HOME set to that directory, and
# rsync is the real one talking through the shim. Fixtures only: RFC 5737 addresses, invented
# names, a fixture token.
set -uo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../home/secretspec/testlib.sh
. "$ROOT/home/secretspec/testlib.sh" || exit 1

for c in rsync jq base64 shasum; do
  command -v "$c" >/dev/null || {
    echo "$c not found on PATH" >&2
    exit 2
  }
done

BASE='{"testvm-alpha":{"node":"n1","vmid":901,"mac":"02:00:5E:10:00:01","ipv4_cidr":"203.0.113.10/24","gateway":"203.0.113.1","dns":["198.51.100.53"],"cores":2,"memory_mb":2048,"disk_gb":20,"role":"agent"}}'
CLEAN='{"testvm-alpha":{"node":"n1","vmid":901,"mac":"02:00:5E:10:00:01","ipv4_cidr":"203.0.113.10/24","gateway":"203.0.113.1","dns":["198.51.100.53"],"cores":2,"memory_mb":2048,"disk_gb":20}}'
ALL_ON='{"plugins":true,"skills":true}'
HS_ON='{"plugins":false,"skills":false,"hindsight":true}'
SECRET_ON='{"plugins":true,"skills":true,"hindsight":true}'
HS_URL=https://hindsight.fixture.example
HS_KEY=fixture0hstoken0123456789abcdefABCD
HS_MAP="{\"testvm-alpha\":{\"url\":\"$HS_URL\",\"token\":\"$HS_KEY\"}}"

# shims VMS-JSON [VM-CONFIG-JSON [HINDSIGHT-MAP-JSON]]: PATH directory $T/bin and the fake world.
#   secretspec get|run   a file-backed vault ($T/store); VM_HINDSIGHT absent reads as {} (the manifest default)
#   terragrunt           the `vms` output, with ip and role
#   ssh                  runs the remote command here with HOME=$T/vm (host user@...); root@ answers `id -u`
#   nix                  logs its arguments (the deploy)
shims() {
  mkdir -p "$T/bin" "$T/store" "$T/vm"
  printf '%s' "$1" >"$T/store/TF_VAR_vms"
  [ -z "${3:-}" ] || printf '%s' "$3" >"$T/store/VM_HINDSIGHT"
  printf '%s' "${2:-$ALL_ON}" >"$T/vm-config.json"
  cat >"$T/bin/secretspec" <<'EOF'
#!/bin/sh
case "$1" in
  get)
    printf 'get %s\n' "$2" >>"$STUB_SEQ"
    if [ -f "$STUB_DIR/$2" ]; then cat "$STUB_DIR/$2"
    elif [ "$2" = VM_HINDSIGHT ]; then printf '{}'
    else exit 1; fi ;;
  run) shift; [ "$1" = -- ] && shift; TF_VAR_vms=$(cat "$STUB_DIR/TF_VAR_vms") exec "$@" ;;
esac
EOF
  # python3 stands for the Hindsight health check (the real one has its own test): it logs the arguments it got
  # and the stdin, and answers by $STUB_HEALTH (200, 401, 500 or unreachable). Any other python3 call is a bug.
  cat >"$T/bin/python3" <<'EOF'
#!/bin/sh
case "$1" in
  */vm-hindsight-health.py)
    printf 'health\n' >>"$STUB_SEQ"
    printf '%s\n' "$*" >>"$STUB_PYARGS"
    cat >"$STUB_DIR/health.stdin"
    case "${STUB_HEALTH:-200}" in
      200) echo "hindsight: the gate accepts the key (HTTP 200)"; exit 0 ;;
      unreachable) echo "vm-hindsight-health: could not reach the Hindsight gate (stub)" >&2; exit 1 ;;
      *) echo "vm-hindsight-health: the Hindsight gate answered HTTP $STUB_HEALTH instead of 200 (stub)" >&2; exit 1 ;;
    esac ;;
  *) echo "unexpected python3 call: $*" >&2; exit 99 ;;
esac
EOF
  cat >"$T/bin/terragrunt" <<'EOF'
#!/bin/sh
jq -c 'map_values({ip: (.ipv4_cidr | split("/")[0]), role: (.role // "clean")})' "$STUB_DIR/TF_VAR_vms"
EOF
  cat >"$T/bin/ssh" <<'EOF'
#!/bin/sh
# options: -o X, -l/-p/-i/-F/-J/-E/-S/-c/-m take a value; other -x are flags; the host is the first word.
# Host keys behave as in ssh: $STUB_KNOWN_HOSTS holds "<ip> ok" (pinned) or "<ip> changed"; a host that is not
# in it is refused under StrictHostKeyChecking=yes, and pinned by any other setting (accept-new, ask, default).
strict=default
opts=
while [ $# -gt 0 ]; do
  case "$1" in
    -o)
      opts="$opts,$2"
      case "$2" in StrictHostKeyChecking=*) strict=${2#*=} ;; esac
      shift 2 ;;
    -l | -p | -i | -F | -J | -E | -S | -c | -m) shift 2 ;;
    -*) shift ;;
    *) break ;;
  esac
done
host=$1
shift
printf 'ssh %s %s\n' "$host" "$*" >>"$STUB_SSHLOG"
printf 'strict=%s %s opts=%s\n' "$strict" "$host" "$opts" >>"$STUB_SSHOPTS"
printf 'ssh %s\n' "${host%%@*}" >>"$STUB_SEQ"
if [ -n "${STUB_SSH_DOWN:-}" ]; then exit 255; fi
if [ -n "${STUB_SSH_FAIL_FIRST:-}" ]; then
  n=$(cat "$STUB_DIR/ssh.count" 2>/dev/null || echo 0)
  n=$((n + 1))
  printf '%s' "$n" >"$STUB_DIR/ssh.count"
  [ "$n" -gt "$STUB_SSH_FAIL_FIRST" ] || exit 255
fi
ip=${host#*@}
line=$(grep "^$ip " "$STUB_KNOWN_HOSTS" 2>/dev/null)
case "$line" in
  *" changed")
    echo "@@@ WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED! @@@" >&2
    echo "Host key verification failed." >&2
    exit 255 ;;
  "")
    if [ "$strict" = yes ]; then
      echo "No ED25519 host key is known for $ip and you have requested strict checking." >&2
      echo "Host key verification failed." >&2
      exit 255
    fi
    echo "$ip ok" >>"$STUB_KNOWN_HOSTS" ;;
esac
case "$host" in
  root@*)
    case "$*" in
      "id -u "*) exit "${STUB_USER_RC:-0}" ;;
      *) exit 0 ;;
    esac ;;
  *)
    if [ -n "${STUB_USER_LOGIN_FAILS:-}" ]; then exit 255; fi
    cd "$STUB_VM_HOME" && HOME="$STUB_VM_HOME" exec bash -c "$*" ;;
esac
EOF
  # nix stands for nixos-rebuild: it trusts a new host key on first use (accept-new), as vm-deploy always did
  cat >"$T/bin/nix" <<'EOF'
#!/bin/sh
printf 'nix\n' >>"$STUB_SEQ"
ip=$(printf '%s' "$*" | sed -n 's/.*--target-host root@\([^ ]*\).*/\1/p')
if [ -n "$ip" ] && ! grep -q "^$ip " "$STUB_KNOWN_HOSTS" 2>/dev/null; then echo "$ip ok" >>"$STUB_KNOWN_HOSTS"; fi
exit 0
EOF
  chmod +x "$T/bin/"*
  : >"$T/sshlog" >"$T/seq" >"$T/sshopts"
  printf '203.0.113.10 ok\n' >"$T/known_hosts"
  export STUB_DIR="$T/store" STUB_SSHLOG="$T/sshlog" STUB_SSHOPTS="$T/sshopts" STUB_KNOWN_HOSTS="$T/known_hosts" STUB_SEQ="$T/seq" STUB_VM_HOME="$T/vm" STUB_PYARGS="$T/pyargs"
  export VM_SYNC_CONFIG_PATH="$T/vm-config.json" VM_SYNC_POLL=0 VM_SYNC_WAIT=2 PATH="$T/bin:$PATH"
  # a library of skills, with things that must not be synced
  local d
  for d in alpha beta gamma; do
    mkdir -p "$T/lib/$d/scripts" "$T/lib/$d/refs/deep"
    printf 'skill %s\n' "$d" >"$T/lib/$d/SKILL.md"
    printf '#!/bin/sh\necho %s\n' "$d" >"$T/lib/$d/scripts/run.sh"
    chmod 755 "$T/lib/$d/scripts/run.sh"
    printf 'ref %s\n' "$d" >"$T/lib/$d/refs/deep/note.md"
  done
  mkdir -p "$T/lib/.git" "$T/lib/.skills-manager" "$T/lib/nodoc"
  printf 'x' >"$T/lib/.git/config"
  printf 'x' >"$T/lib/.skills-manager/protocol.json"
  printf 'x' >"$T/lib/nodoc/README.md"
  printf 'x' >"$T/lib/stray-file"
  ln -s alpha "$T/lib/linkdir"
  export SYNC_SKILLS_SRC="$T/lib"
}

sync_run() { bash "$ROOT/infra/vm-sync.sh" "${1:-testvm-alpha}" "$ROOT" >"$T/out" 2>"$T/err"; echo $?; }
deploy() { (cd "$ROOT" && bash "$ROOT/infra/vm-deploy.sh" "${1:-testvm-alpha}" "$ROOT") >"$T/out" 2>"$T/err"; echo $?; }
VMSKILLS() { echo "$T/vm/.omp/agent/skills"; }
VMHS() { echo "$T/vm/.config/dotfiles/hindsight.env"; }
# hashes DIR: sorted per-file hashes of DIR, relative paths.
hashes() { (cd "$1" && find . -type f | LC_ALL=C sort | while IFS= read -r f; do printf '%s %s\n' "$(shasum -a 256 <"$f" | cut -c1-64)" "$f"; done); }

# ---- vm-hindsight-entry.sh

ent() { bash "$ROOT/infra/vm-hindsight-entry.sh" "$@" >"$T/out" 2>"$T/err"; echo $?; }

test_entry_script_prints_url_and_key_of_the_named_vm_only() {
  shims "$BASE" "" "{\"testvm-alpha\":{\"url\":\"$HS_URL\",\"token\":\"$HS_KEY\"},\"testvm-beta\":{\"url\":\"https://other.fixture.example\",\"token\":\"fixture0other0hstoken0123456789ab\"}}"
  assert_rc "entry" "$(ent testvm-alpha)" 0
  assert_eq "the url, then the key, and nothing else" "$HS_URL
$HS_KEY" "$(cat "$T/out")"
  assert_eq "stderr empty" "" "$(cat "$T/err")"
  assert_lacks "not the other VM's" "$T/out" "other"
}

test_entry_script_prints_nothing_without_an_entry() {
  shims "$BASE" "" '{"testvm-beta":{"url":"https://other.fixture.example","token":"fixture0other0hstoken0123456789ab"}}'
  assert_rc "no entry for the VM" "$(ent testvm-alpha)" 0
  assert_eq "nothing on stdout" "" "$(cat "$T/out")"
  shims "$BASE"
  assert_rc "key absent from the vault (default {})" "$(ent testvm-alpha)" 0
  assert_eq "nothing" "" "$(cat "$T/out")"
  shims "$BASE" "" '{"testvm-alpha":null}'
  assert_rc "a null entry" "$(ent testvm-alpha)" 0
  assert_eq "nothing" "" "$(cat "$T/out")"
}

test_entry_script_refuses_a_malformed_vault_value_without_echoing_it() {
  local bad
  for bad in 'not json' "[\"$HS_KEY\"]" '{"testvm-alpha":"x"}' '{"testvm-alpha":["x"]}' '{"testvm-alpha":{}}' \
    "{\"testvm-alpha\":{\"url\":\"$HS_URL\"}}" "{\"testvm-alpha\":{\"token\":\"$HS_KEY\"}}" \
    "{\"testvm-alpha\":{\"url\":\"http://hindsight.fixture.example\",\"token\":\"$HS_KEY\"}}" \
    "{\"testvm-alpha\":{\"url\":\"$HS_URL/p?x=1\",\"token\":\"$HS_KEY\"}}" \
    "{\"testvm-alpha\":{\"url\":\"$HS_URL\",\"token\":\"short\"}}" \
    "{\"testvm-alpha\":{\"url\":\"$HS_URL\",\"token\":\"has space in it 0123456789abcdef\"}}" \
    "{\"testvm-alpha\":{\"url\":7,\"token\":\"$HS_KEY\"}}"; do
    shims "$BASE" "" "$bad"
    assert_rc "bad value: $bad" "$(ent testvm-alpha)" 1
    assert_has "names the vault key" "$T/err" "VM_HINDSIGHT"
    assert_eq "stdout empty" "" "$(cat "$T/out")"
    assert_lacks "stderr hides the key" "$T/err" "hstoken0123456789"
    assert_lacks "stderr hides the url" "$T/err" "hindsight.fixture.example"
  done
}

test_entry_script_fails_when_the_vault_cannot_be_read() {
  shims "$BASE"
  printf '#!/bin/sh\nexit 1\n' >"$T/bin/secretspec"
  assert_rc "secretspec fails" "$(ent testvm-alpha)" 1
  assert_has "says it" "$T/err" "cannot read VM_HINDSIGHT"
}

test_entry_script_says_what_is_wrong_with_the_map_or_the_entry() {
  local bad
  for bad in 'null' '7' '"x"' '["x"]'; do
    shims "$BASE" "" "$bad"
    assert_rc "map: $bad" "$(ent testvm-alpha)" 1
    assert_has "says it is not a JSON object" "$T/err" "is not a JSON object"
    assert_eq "stdout empty" "" "$(cat "$T/out")"
  done
  for bad in '{"testvm-alpha":"x"}' '{"testvm-alpha":7}' '{"testvm-alpha":["x"]}'; do
    shims "$BASE" "" "$bad"
    assert_rc "entry: $bad" "$(ent testvm-alpha)" 1
    assert_has "says it is not an object" "$T/err" "not an object"
    assert_eq "stdout empty" "" "$(cat "$T/out")"
  done
}

test_entry_script_takes_one_argument() {
  shims "$BASE"
  assert_rc "none" "$(ent)" 2
  assert_rc "two" "$(ent a b)" 2
}

# ---- vm-sync.sh

test_sync_mirrors_the_skills() {
  shims "$BASE"
  mkdir -p "$(VMSKILLS)/mine" "$(VMSKILLS)/alpha/stale"
  printf 'mine' >"$(VMSKILLS)/mine/SKILL.md"
  printf 'stale' >"$(VMSKILLS)/alpha/stale/old.md"
  printf 'stale' >"$(VMSKILLS)/alpha/extra.txt"
  assert_rc "sync" "$(sync_run)" 0
  assert_eq "alpha mirrors the Mac exactly (files and hashes)" "$(hashes "$T/lib/alpha")" "$(hashes "$(VMSKILLS)/alpha")"
  assert_eq "beta" "$(hashes "$T/lib/beta")" "$(hashes "$(VMSKILLS)/beta")"
  assert_eq "gamma" "$(hashes "$T/lib/gamma")" "$(hashes "$(VMSKILLS)/gamma")"
  assert_absent "a stale file inside a synced directory is deleted" "$(VMSKILLS)/alpha/extra.txt"
  assert_absent "a stale directory inside a synced directory is deleted" "$(VMSKILLS)/alpha/stale"
  assert_eq "the user's own skill stays" mine "$(cat "$(VMSKILLS)/mine/SKILL.md")"
  assert_eq "script keeps its exec bit" yes "$([ -x "$(VMSKILLS)/beta/scripts/run.sh" ] && echo yes)"
  assert_eq "exactly the three plus the user's" "alpha beta gamma mine" "$(ls "$(VMSKILLS)" | tr '\n' ' ' | sed 's/ $//')"
}

test_sync_syncs_only_the_library_skills() {
  shims "$BASE"
  assert_rc "sync" "$(sync_run)" 0
  assert_eq "only real skill directories" "alpha beta gamma" "$(ls "$(VMSKILLS)" | tr '\n' ' ' | sed 's/ $//')"
  assert_absent "no .git" "$(VMSKILLS)/.git"
  assert_absent "no metadata directory" "$(VMSKILLS)/.skills-manager"
  assert_absent "no directory without SKILL.md" "$(VMSKILLS)/nodoc"
  assert_absent "no linked directory" "$(VMSKILLS)/linkdir"
  assert_absent "no stray file" "$(VMSKILLS)/stray-file"
}

test_sync_follows_the_vms_options() {
  shims "$BASE" '{"plugins":false,"skills":false,"hindsight":false}' "$HS_MAP"
  assert_rc "all off" "$(sync_run)" 0
  assert_absent "no skills" "$(VMSKILLS)"
  assert_absent "no hindsight file" "$(VMHS)"
  assert_eq "the vault entry was not even read" 0 "$(grep -c 'get VM_HINDSIGHT' "$T/seq")"
  assert_lacks "no plugin line" "$T/out" "plugins:"
  printf '{"plugins":false,"skills":true}' >"$T/vm-config.json"
  assert_rc "skills only" "$(sync_run)" 0
  assert_eq "skills" yes "$([ -d "$(VMSKILLS)/alpha" ] && echo yes)"
  assert_absent "still no hindsight file" "$(VMHS)"
  printf '{"plugins":true,"skills":false}' >"$T/vm-config.json"
  rm -rf "$T/vm"
  mkdir -p "$T/vm"
  assert_rc "plugins only" "$(sync_run)" 0
  assert_absent "no skills" "$(VMSKILLS)"
  assert_has "the plugin status line" "$T/out" "plugins:"
}

test_sync_refuses_the_managed_skills_store() {
  shims "$BASE"
  mkdir -p "$T/store-of-notes/managed-skills/some-note"
  printf 'x' >"$T/store-of-notes/managed-skills/some-note/SKILL.md"
  assert_rc "as the source" "$(SYNC_SKILLS_SRC="$T/store-of-notes/managed-skills" sync_run)" 1
  assert_has "says why" "$T/err" "managed-skills"
  assert_absent "nothing reached the VM" "$(VMSKILLS)"
  mkdir -p "$T/notes-only/managed-skills/readme-dir"
  printf 'x' >"$T/notes-only/managed-skills/readme-dir/README.md"
  assert_rc "a store with no skill directory in it" "$(SYNC_SKILLS_SRC="$T/notes-only/managed-skills" sync_run)" 1
  assert_has "refused as the store, not for being empty" "$T/err" "never leaves this Mac"
  ln -s "$T/store-of-notes/managed-skills" "$T/innocent-name"
  assert_rc "through a link" "$(SYNC_SKILLS_SRC="$T/innocent-name" sync_run)" 1
  assert_absent "nothing reached the VM (link)" "$(VMSKILLS)"
  mkdir -p "$T/lib/managed-skills"
  printf 'x' >"$T/lib/managed-skills/SKILL.md"
  assert_rc "as a directory of the library" "$(sync_run)" 1
  assert_has "names the member" "$T/err" "part of the managed-skills store"
  assert_absent "nothing reached the VM (member)" "$(VMSKILLS)"
  assert_eq "no rsync was started" 0 "$(grep -c 'rsync --server' "$T/sshlog")"
}

test_sync_refuses_an_empty_or_missing_library() {
  shims "$BASE"
  rm -rf "$T/lib"
  mkdir -p "$T/lib"
  assert_rc "empty" "$(sync_run)" 1
  assert_has "says so" "$T/err" "no skills"
  assert_absent "no skills directory made" "$(VMSKILLS)"
  assert_rc "missing" "$(SYNC_SKILLS_SRC="$T/nowhere" sync_run)" 1
}

test_sync_skips_a_directory_with_an_unusable_name_and_says_so() {
  shims "$BASE"
  mkdir -p "$T/lib/bad name"
  printf 'x' >"$T/lib/bad name/SKILL.md"
  assert_rc "sync" "$(sync_run)" 0
  assert_has "warns" "$T/err" "skipping the directory"
  assert_eq "the others are synced" "alpha beta gamma" "$(ls "$(VMSKILLS)" | tr '\n' ' ' | sed 's/ $//')"
}

test_sync_twice_changes_nothing_and_follows_a_removed_file() {
  shims "$BASE"
  assert_rc "first" "$(sync_run)" 0
  local before
  before=$(hashes "$T/vm")
  assert_rc "second" "$(sync_run)" 0
  assert_eq "same tree" "$before" "$(hashes "$T/vm")"
  rm "$T/lib/alpha/refs/deep/note.md"
  assert_rc "third" "$(sync_run)" 0
  assert_absent "removed on the Mac, removed on the VM" "$(VMSKILLS)/alpha/refs/deep/note.md"
}

test_sync_only_runs_for_the_agent_role() {
  shims "$CLEAN"
  assert_rc "clean role" "$(sync_run)" 1
  assert_has "says why" "$T/err" "clean"
  assert_eq "nothing was run on the VM" 0 "$(grep -c '^ssh ' "$T/sshlog")"
  assert_absent "no skills" "$(VMSKILLS)"
}

test_sync_waits_for_ssh_and_gives_up() {
  shims "$BASE"
  assert_rc "ssh comes up on the third try" "$(STUB_SSH_FAIL_FIRST=2 sync_run)" 0
  assert_eq "synced after the wait" yes "$([ -d "$(VMSKILLS)/alpha" ] && echo yes)"
  rm -rf "$T/vm"
  mkdir -p "$T/vm"
  assert_rc "ssh never comes up" "$(STUB_SSH_DOWN=1 VM_SYNC_WAIT=1 sync_run)" 1
  assert_has "says it" "$T/err" "cannot log in"
}

test_sync_fails_on_an_unreadable_vm_config() {
  shims "$BASE"
  printf 'not json' >"$T/vm-config.json"
  assert_rc "bad config" "$(sync_run)" 1
  assert_has "says it" "$T/err" "dotfiles-agent-sync"
  assert_absent "nothing synced" "$(VMSKILLS)"
  rm "$T/vm-config.json"
  assert_rc "missing config" "$(sync_run)" 1
}

test_sync_runs_the_remote_part_as_the_user_never_as_root() {
  shims "$BASE"
  assert_rc "sync" "$(sync_run)" 0
  assert_eq "no root login" 0 "$(grep -c '^ssh root' "$T/seq")"
}

# ---- host keys: the sync only talks to a VM whose key is pinned already

test_sync_refuses_a_host_key_that_is_not_pinned() {
  shims "$BASE" "$SECRET_ON" "$HS_MAP"
  : >"$T/known_hosts"
  assert_rc "sync" "$(sync_run)" 1
  assert_has "says the key is not pinned" "$T/err" "not pinned in known_hosts"
  assert_has "names the re-key step" "$T/err" "ssh-keygen -R 203.0.113.10"
  assert_has "says why: secrets" "$T/err" "never trusts a key on first use"
  assert_eq "nothing was pinned by the attempt" "" "$(cat "$T/known_hosts")"
  assert_eq "no remote command ran (only the probe)" 0 "$(grep -c 'base64 -d' "$T/sshlog")"
  assert_eq "no rsync was started" 0 "$(grep -c 'rsync --server' "$T/sshlog")"
  assert_absent "no hindsight file" "$(VMHS)"
  assert_absent "no skills" "$(VMSKILLS)"
  assert_lacks "the key went nowhere" "$T/sshlog" "$HS_KEY"
}

test_sync_refuses_a_host_key_that_does_not_match_the_pinned_one() {
  shims "$BASE" "$SECRET_ON" "$HS_MAP"
  printf '203.0.113.10 changed\n' >"$T/known_hosts"
  assert_rc "sync" "$(sync_run)" 1
  assert_has "names the re-key step" "$T/err" "ssh-keygen -R 203.0.113.10"
  assert_eq "no remote command ran" 0 "$(grep -c 'base64 -d' "$T/sshlog")"
  assert_absent "no hindsight file" "$(VMHS)"
  assert_absent "no skills" "$(VMSKILLS)"
}

test_every_connection_of_the_sync_is_strict_and_writes_no_host_key() {
  shims "$BASE" "$SECRET_ON" "$HS_MAP"
  assert_rc "sync" "$(sync_run)" 0
  assert_eq "ssh was called (config, hindsight, skills-prepare, plugins) and rsync ran its three transfers" yes "$([ "$(grep -c '' "$T/sshopts")" -ge 8 ] && [ "$(grep -c 'rsync --server' "$T/sshlog")" -eq 3 ] && echo yes)"
  assert_eq "no connection without StrictHostKeyChecking=yes" 0 "$(grep -vc '^strict=yes ' "$T/sshopts")"
  assert_eq "no connection without UpdateHostKeys=no" 0 "$(grep -vc 'UpdateHostKeys=no' "$T/sshopts")"
  assert_eq "known_hosts is as it was" "203.0.113.10 ok" "$(cat "$T/known_hosts")"
}

test_the_removal_of_the_sync_also_needs_a_pinned_key() {
  shims "$BASE"
  : >"$T/known_hosts"
  local rc=0
  (
    . "$ROOT/infra/vm-sync-lib.sh"
    vm_unsync testvm-alpha "$ROOT" 203.0.113.10
  ) >"$T/out" 2>"$T/err" || rc=$?
  assert_rc "vm_unsync" "$rc" 1
  assert_has "names the re-key step" "$T/err" "ssh-keygen -R 203.0.113.10"
  assert_eq "no remote command ran" 0 "$(grep -c 'base64 -d\|id -u' "$T/sshlog")"
  assert_eq "nothing was pinned" "" "$(cat "$T/known_hosts")"
}

test_the_remote_call_refuses_an_argument_that_is_not_a_plain_name() {
  shims "$BASE"
  local bad rc
  for bad in "x;touch $T/pwned" 'a b' "a'b" '$(id)' '-x' ''; do
    rc=0
    (
      . "$ROOT/infra/vm-sync-lib.sh"
      sync_remote "$ROOT" 203.0.113.10 skills-prepare "$bad"
    ) >"$T/out" 2>"$T/err" || rc=$?
    assert_rc "argument: $bad" "$rc" 1
    assert_absent "nothing ran for: $bad" "$T/pwned"
  done
  assert_eq "no ssh call at all" 0 "$(grep -c '^ssh ' "$T/sshlog")"
}

# ---- vm-deploy: sync after an agent deploy, removal before a clean one

test_deploy_of_the_agent_role_syncs_after_the_switch() {
  shims "$BASE" "$SECRET_ON" "$HS_MAP"
  assert_rc "deploy" "$(deploy)" 0
  assert_eq "nix first, then the user's ssh" "nix" "$(grep -E '^(nix|ssh lex)' "$T/seq" | head -1)"
  assert_eq "the switch is before the first remote call as the user" "yes" "$(awk '/^nix$/ {n=NR} /^ssh lex$/ && !f {f=NR} END {print (n && f && n < f) ? "yes" : "no"}' "$T/seq")"
  assert_has "hindsight file" "$(VMHS)" "HINDSIGHT_API_TOKEN='$HS_KEY'"
  assert_eq "skills" yes "$([ -d "$(VMSKILLS)/alpha" ] && echo yes)"
}

test_a_failed_sync_after_the_switch_fails_the_deploy_and_says_what_to_do() {
  shims "$BASE" 'not json'
  assert_rc "deploy" "$(deploy)" 1
  assert_has "the switch happened" "$T/seq" "nix"
  assert_has "says it is deployed and names the recipe" "$T/err" "just vm-sync"
}

test_deploy_of_the_clean_role_removes_what_the_sync_placed_first() {
  shims "$BASE" "$SECRET_ON" "$HS_MAP"
  mkdir -p "$(VMSKILLS)/mine"
  printf 'mine' >"$(VMSKILLS)/mine/SKILL.md"
  printf 'cfg' >"$T/vm/keepme"
  assert_rc "sync" "$(sync_run)" 0
  : >"$T/seq"
  printf '%s' "$CLEAN" >"$T/store/TF_VAR_vms"
  assert_rc "deploy as clean" "$(deploy)" 0
  assert_eq "the removal ran before the switch" "yes" "$(awk '/^nix$/ {n=NR} /^ssh lex$/ {f=NR} END {print (n && f && f < n) ? "yes" : "no"}' "$T/seq")"
  assert_absent "hindsight file is gone" "$(VMHS)"
  assert_absent "alpha is gone" "$(VMSKILLS)/alpha"
  assert_absent "beta is gone" "$(VMSKILLS)/beta"
  assert_absent "gamma is gone" "$(VMSKILLS)/gamma"
  assert_eq "the user's skill stays" mine "$(cat "$(VMSKILLS)/mine/SKILL.md")"
  assert_eq "another file stays" cfg "$(cat "$T/vm/keepme")"
}

# ---- vm-sync.sh: the Hindsight piece

test_sync_hindsight_checks_the_gate_then_writes_the_file_and_puts_nothing_in_an_argument() {
  shims "$BASE" "$HS_ON" "$HS_MAP"
  mkdir -p "$T/vm/.omp"
  printf 'mine' >"$T/vm/.omp/.env"
  assert_rc "sync" "$(sync_run)" 0
  assert_has "url line" "$(VMHS)" "HINDSIGHT_API_URL='$HS_URL'"
  assert_has "key line" "$(VMHS)" "HINDSIGHT_API_TOKEN='$HS_KEY'"
  assert_eq "mode 600" 600 "$(tl_mode "$(VMHS)")"
  assert_eq "the health check ran once" 1 "$(grep -c '^health$' "$T/seq")"
  assert_eq "the check ran before the write" "yes" "$(awk '/^health$/ {h=NR} /^ssh lex$/ {s=NR} END {print (h && s && h < s) ? "yes" : "no"}' "$T/seq")"
  assert_eq "the check got the script path only" "$ROOT/infra/vm-hindsight-health.py" "$(cat "$T/pyargs")"
  assert_eq "the check got the url and the key on stdin" "$HS_URL
$HS_KEY" "$(cat "$T/store/health.stdin")"
  assert_lacks "no key on any ssh command line" "$T/sshlog" "$HS_KEY"
  assert_lacks "no url on any ssh command line" "$T/sshlog" "hindsight.fixture.example"
  assert_lacks "no key in the output" "$T/out" "$HS_KEY"
  assert_lacks "no key in stderr" "$T/err" "$HS_KEY"
  assert_eq "the user's ~/.omp/.env is untouched" "mine" "$(cat "$T/vm/.omp/.env")"
}

test_sync_hindsight_pushes_nothing_when_the_gate_does_not_accept_the_key() {
  local st rc
  for st in 401 500 unreachable; do
    shims "$BASE" "$HS_ON" "$HS_MAP"
    rc=$(STUB_HEALTH=$st sync_run)
    assert_rc "gate says $st" "$rc" 1
    assert_has "names the VM" "$T/err" "testvm-alpha"
    assert_has "says nothing was written" "$T/err" "nothing was written to the VM"
    assert_absent "no file for $st" "$(VMHS)"
    assert_eq "no hindsight call reached the VM for $st" 0 "$(grep -c "'hindsight'" "$T/sshlog")"
    assert_lacks "no key in stderr" "$T/err" "$HS_KEY"
  done
  shims "$BASE" "$HS_ON" "$HS_MAP"
  assert_rc "first, accepted" "$(sync_run)" 0
  local before
  before=$(shasum -a 256 <"$(VMHS)")
  assert_rc "then revoked" "$(STUB_HEALTH=401 sync_run)" 1
  assert_eq "the file on the VM is as it was" "$before" "$(shasum -a 256 <"$(VMHS)")"
}

test_sync_hindsight_without_an_entry_removes_the_file_with_one_notice() {
  shims "$BASE" "$HS_ON" "$HS_MAP"
  assert_rc "first sync" "$(sync_run)" 0
  assert_eq "the file is there" yes "$([ -f "$(VMHS)" ] && echo yes)"
  printf '{"testvm-beta":{"url":"https://other.fixture.example","token":"fixture0other0hstoken0123456789ab"}}' >"$T/store/VM_HINDSIGHT"
  assert_rc "second sync, no entry" "$(sync_run)" 0
  assert_absent "the file is gone" "$(VMHS)"
  assert_eq "one line about hindsight" 1 "$(grep -c '^hindsight:' "$T/out")"
  assert_has "names the vault key and the VM" "$T/out" "no entry for testvm-alpha in VM_HINDSIGHT"
  assert_eq "the check did not run again" 1 "$(grep -c '^health$' "$T/seq")"
  assert_rc "third sync, nothing to remove" "$(sync_run)" 0
  assert_eq "one line again" 1 "$(grep -c '^hindsight:' "$T/out")"
  assert_has "says there is nothing" "$T/out" "no file to remove"
  shims "$BASE" "$HS_ON"
  assert_rc "key absent from the vault (default {})" "$(sync_run)" 0
  assert_has "same notice" "$T/out" "no entry for testvm-alpha in VM_HINDSIGHT"
}

test_sync_hindsight_does_nothing_when_the_vms_option_is_off() {
  shims "$BASE" "$ALL_ON" "$HS_MAP"
  assert_rc "option absent" "$(sync_run)" 0
  assert_absent "no file" "$(VMHS)"
  printf '{"plugins":false,"skills":false,"hindsight":false}' >"$T/vm-config.json"
  assert_rc "option false" "$(sync_run)" 0
  assert_absent "still no file" "$(VMHS)"
  assert_eq "the vault entry was not read" 0 "$(grep -c 'get VM_HINDSIGHT' "$T/seq")"
  assert_eq "no check ran" 0 "$(grep -c '^health$' "$T/seq")"
}

test_sync_hindsight_refuses_a_malformed_vault_map_and_writes_nothing() {
  local bad
  for bad in 'not json' '{"testvm-alpha":"x"}' "{\"testvm-alpha\":{\"url\":\"http://hindsight.fixture.example\",\"token\":\"$HS_KEY\"}}" "{\"testvm-alpha\":{\"url\":\"$HS_URL\",\"token\":\"short\"}}"; do
    shims "$BASE" "$HS_ON" "$bad"
    assert_rc "bad map: $bad" "$(sync_run)" 1
    assert_has "names the vault key" "$T/err" "VM_HINDSIGHT"
    assert_absent "no file" "$(VMHS)"
    assert_eq "no check ran" 0 "$(grep -c '^health$' "$T/seq")"
  done
}

test_deploy_of_the_agent_role_syncs_hindsight_after_the_switch() {
  shims "$BASE" "$SECRET_ON" "$HS_MAP"
  assert_rc "deploy" "$(deploy)" 0
  assert_has "key line" "$(VMHS)" "HINDSIGHT_API_TOKEN='$HS_KEY'"
  assert_eq "the check ran" 1 "$(grep -c '^health$' "$T/seq")"
  assert_eq "the switch is before the first remote call as the user" "yes" "$(awk '/^nix$/ {n=NR} /^ssh lex$/ && !f {f=NR} END {print (n && f && n < f) ? "yes" : "no"}' "$T/seq")"
}

test_deploy_of_the_clean_role_removes_the_hindsight_file_and_nothing_else() {
  shims "$BASE" "$HS_ON" "$HS_MAP"
  mkdir -p "$T/vm/.omp"
  printf 'mine' >"$T/vm/.omp/.env"
  assert_rc "sync" "$(sync_run)" 0
  printf 'user file' >"$T/vm/.config/dotfiles/mine.txt"
  : >"$T/seq"
  printf '%s' "$CLEAN" >"$T/store/TF_VAR_vms"
  assert_rc "deploy as clean" "$(deploy)" 0
  assert_absent "the hindsight file is gone" "$(VMHS)"
  assert_eq "the user's file in the same directory stays" "user file" "$(cat "$T/vm/.config/dotfiles/mine.txt")"
  assert_eq "~/.omp/.env stays" "mine" "$(cat "$T/vm/.omp/.env")"
  assert_absent "no manifest left" "$T/vm/.local/state/dotfiles/vm-sync/manifest"
}

test_deploy_of_the_clean_role_skips_the_removal_when_there_is_no_user() {
  shims "$CLEAN"
  assert_rc "deploy" "$(STUB_USER_RC=1 deploy)" 0
  assert_eq "no login as the user" 0 "$(grep -c '^ssh lex' "$T/seq")"
  assert_has "the switch ran" "$T/seq" "nix"
  assert_has "says why" "$T/out" "nothing to remove"
}

test_deploy_of_the_clean_role_stops_before_the_switch_when_the_removal_fails() {
  shims "$CLEAN"
  assert_rc "deploy" "$(STUB_USER_LOGIN_FAILS=1 deploy)" 1
  assert_eq "no switch" 0 "$(grep -c '^nix$' "$T/seq")"
  assert_has "says what failed" "$T/err" "not changing the role"
}

test_deploy_stops_when_root_cannot_be_reached_to_look_for_the_user() {
  shims "$CLEAN"
  assert_rc "deploy" "$(STUB_SSH_DOWN=1 deploy)" 1
  assert_eq "no switch" 0 "$(grep -c '^nix$' "$T/seq")"
  assert_has "says root cannot be reached" "$T/err" "cannot reach testvm-alpha as root"
}

test_deploy_of_the_agent_role_sends_no_secret_over_a_key_that_the_switch_pinned() {
  shims "$BASE" "$SECRET_ON" "$HS_MAP"
  : >"$T/known_hosts"
  assert_rc "deploy" "$(deploy)" 1
  assert_has "the switch ran (it trusts a new key on first use, as it always did)" "$T/seq" "nix"
  assert_eq "and pinned the key" "203.0.113.10 ok" "$(cat "$T/known_hosts")"
  assert_has "says why nothing was synced" "$T/err" "was not pinned before this deploy"
  assert_has "names the re-key step" "$T/err" "ssh-keygen -R 203.0.113.10"
  assert_has "names the recipe to run next" "$T/err" "just vm-sync"
  assert_absent "no hindsight file" "$(VMHS)"
  assert_absent "no skills" "$(VMSKILLS)"
  assert_lacks "the key went nowhere" "$T/sshlog" "$HS_KEY"
  assert_eq "no connection as the agent user" 0 "$(grep -c '^ssh lex' "$T/seq")"
  assert_rc "vm-sync afterwards, with the key pinned" "$(sync_run)" 0
  assert_has "hindsight file now" "$(VMHS)" "HINDSIGHT_API_TOKEN='$HS_KEY'"
}

test_deploy_of_the_clean_role_without_a_pinned_key_skips_the_removal_and_deploys() {
  shims "$CLEAN"
  : >"$T/known_hosts"
  assert_rc "deploy" "$(deploy)" 0
  assert_has "the switch ran" "$T/seq" "nix"
  assert_has "says the removal was skipped" "$T/err" "removal of synced files is skipped"
  assert_eq "no connection as the agent user" 0 "$(grep -c '^ssh lex' "$T/seq")"
  assert_eq "no connection of the sync before the switch pinned the key" 0 "$(grep -c 'id -u' "$T/sshlog")"
}

test_deploy_stops_before_the_switch_when_the_host_key_does_not_match() {
  local role
  for role in "$BASE" "$CLEAN"; do
    shims "$role"
    printf '203.0.113.10 changed\n' >"$T/known_hosts"
    assert_rc "deploy" "$(deploy)" 1
    assert_has "names the re-key step" "$T/err" "ssh-keygen -R 203.0.113.10"
    assert_eq "no switch" 0 "$(grep -c '^nix$' "$T/seq")"
  done
}

tl_init_pure
tl_run_all
tl_done
