#!/usr/bin/env bash
# Tests for hosts/windows/win-sync.sh and win-render.py: the bundle the Mac sends to a Windows host. ssh, scp,
# secretspec and nix are stubs (bin/<name> -> stub) that keep their state in $T/st: the vault is a directory of
# files, scp keeps what it was sent, ssh answers the host key probe and records the PowerShell command. The
# data is the repo's own (hosts/windows/rex, home/omp, home/tern); the Mac's SSH settings, Tern host list, Tern
# known_hosts, own Tern identity (tern remote host-key) and skills library are fixtures. apply.ps1 itself runs only
# on Windows (README: Windows hosts).
# shellcheck disable=SC2088,SC2016 # a literal ~ and ${...} are the text these tests expect
set -uo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
# shellcheck source=../../home/secretspec/testlib.sh
. "$ROOT/home/secretspec/testlib.sh" || exit 1
# Fixture Tern endpoint ids: the Mac's own, and one already in its host list.
EID=$(printf 'a%.0s' $(seq 64))
EID2=$(printf 'b%.0s' $(seq 64))

write_stub() {
  cat >"$T/stub" <<'STUB'
#!/usr/bin/env bash
S=${STUB_STATE:?}
name=$(basename "$0")
case $name in
  secretspec)
    f=$S/vault/$2
    echo "secretspec $1 $2" >>"$S/calls"
    case $1 in
      get)
        if [ -f "$f" ]; then cat "$f"
        elif [ "$2" = WIN_SSH_KEYS ]; then printf '{}'
        else echo "secret $2 not found" >&2; exit 1; fi ;;
      set) cat >"$f" ;;
    esac ;;
  nix) cat "$S/ssh-settings.json" ;;
  tern) printf '{"endpoint_id":"%s","fingerprint":"SHA256:mac"}\n' "$(cat "$S/eid")" ;;
  ssh)
    while [[ ${1:-} == -o ]]; do shift 2; done
    target=$1
    shift
    if [ "$*" = "exit 0" ]; then
      case $(cat "$S/probe") in
        unpinned) echo "Host key verification failed." >&2; exit 255 ;;
        down) echo "ssh: connect to host $target port 22: Operation timed out" >&2; exit 255 ;;
      esac
      exit 0
    fi
    printf '%s\n' "$*" >"$S/remote-cmd"
    echo "ssh $target apply" >>"$S/calls"
    exit "$(cat "$S/remote-rc")" ;;
  scp)
    while [[ ${1:-} == -* ]]; do case $1 in -o) shift 2 ;; *) shift ;; esac; done
    cp "$1" "$S/sent.tgz"
    echo "scp $2" >>"$S/calls" ;;
esac
STUB
  chmod +x "$T/stub"
}

# world: the stubs, a vault with OMP_ENV, the Mac's SSH settings, Tern pins and a skills library.
world() {
  S=$T/st
  mkdir -p "$S/vault" "$T/tern" "$T/skills/alpha" "$T/skills/beta" "$T/skills/notes"
  write_stub
  for c in ssh scp secretspec nix tern; do ln -sf "$T/stub" "$T_SHIM/$c"; done
  echo "$EID" >"$S/eid"
  printf 'A_KEY=one\nB_KEY=two\n' >"$S/vault/OMP_ENV"
  echo ok >"$S/probe"
  echo 0 >"$S/remote-rc"
  : >"$S/calls"
  cat >"$S/ssh-settings.json" <<'JSON'
{
  "*": {"data": {"header": "Host *", "User": "root", "AddKeysToAgent": "yes", "UseKeychain": "yes", "StrictHostKeyChecking": "no"}},
  "dxc.0dl.me": {"data": {"header": "Host dxc.0dl.me", "ProxyCommand": "cloudflared access ssh --hostname %h"}},
  "github.com": {"data": {"header": "Host github.com", "HostName": "ssh.github.com", "Port": 443}},
  "home 198.51.100.249": {"data": {"header": "Host home 198.51.100.249", "HostName": "198.51.100.249", "User": "le", "IdentityFile": "~/.ssh/id_crypt"}},
  "pxc_hermes": {"data": {"header": "Host pxc_hermes", "HostName": "198.51.100.29", "User": "ubuntu", "IdentityFile": "~/.ssh/id_ed25519"}},
  "pxc_lab": {"data": {"header": "Host pxc_lab", "HostName": "198.51.100.20", "IdentityFile": "~/.ssh/id_crypt"}},
  "pxc_root": {"data": {"header": "Host pxc_root", "HostName": "198.51.100.10", "IdentityFile": "~/.ssh/id_crypt"}},
  "px_lab": {"data": {"header": "Host px_lab", "HostName": "203.0.113.20", "IdentityFile": "~/.ssh/id_crypt"}},
  "px_root": {"data": {"header": "Host px_root", "HostName": "203.0.113.179", "IdentityFile": "~/.ssh/id_crypt"}}
}
JSON
  printf '198.51.100.29:8376 SHA256:pinA\n198.51.100.249:8377 SHA256:pinB\n198.51.100.249:8376 SHA256:other\n203.0.113.40:8376 SHA256:pinC\n' >"$T/tern/known_hosts"
  printf '# Remote hosts Tern connects to\nubuntu@198.51.100.29\nle@198.51.100.249:8377\thome\nlex@203.0.113.40\nuser@192.0.2.10\nme@%s\tother\n' "$EID2" >"$T/tern/hosts"
  echo '# alpha' >"$T/skills/alpha/SKILL.md"
  echo 'body' >"$T/skills/alpha/notes.md"
  ln -s /etc/hosts "$T/skills/alpha/outside"
  echo '# beta' >"$T/skills/beta/SKILL.md"
  echo 'not a skill' >"$T/skills/notes/README.md"
  export STUB_STATE=$S WIN_SYNC_TERN_DIR=$T/tern SYNC_SKILLS_SRC=$T/skills
  export HOME=$T_HOME TMPDIR=$T/tmp PATH=$T_SHIM:$PATH
}

# sync [ARG...]: run win-sync for rex; rc in $rc, the bundle unpacked into $T/b (when one was sent).
sync() {
  rm -rf "$T/b" "$S/sent.tgz"
  bash "$ROOT/hosts/windows/win-sync.sh" rex user@192.0.2.10 "$@" >"$T/out" 2>"$T/err"
  rc=$?
  if [ -f "$S/sent.tgz" ]; then mkdir -p "$T/b" && tar -xzf "$S/sent.tgz" -C "$T/b"; fi
}

test_the_bundle_holds_every_file_files_tsv_installs() {
  world
  sync
  assert_rc "sync" "$rc" 0
  assert_eq "every source of files.tsv is in the bundle" "" \
    "$(cut -f2 "$T/b/files.tsv" | while read -r s; do [ -f "$T/b/$s" ] || echo "$s"; done)"
  assert_eq "the destinations" "~/.omp/agent/config.yml ~/.omp/agent/models.yml ~/.omp/agent/mcp.json ~/.omp/.env ~/.omp/plugins/package.json ~/.omp/plugins/bun.lock ~/.omp/plugins/omp-plugins.lock.json %APPDATA%/Tern/settings.json ~/.ssh/config ~/.ssh/id_ed25519 ~/.ssh/id_ed25519.pub" \
    "$(cut -f3 "$T/b/files.tsv" | tr '\n' ' ' | sed 's/ $//')"
  assert_eq "the two secrets are mode secret" "~/.omp/.env ~/.ssh/id_ed25519" \
    "$(awk -F'\t' '$1=="secret"{print $3}' "$T/b/files.tsv" | tr '\n' ' ' | sed 's/ $//')"
  assert_eq ".env is the vault's, byte for byte" "$(shasum -a 256 <"$S/vault/OMP_ENV")" "$(shasum -a 256 <"$T/b/omp/env")"
  assert_eq "config.yml is the repo's" "$(shasum -a 256 <"$ROOT/home/omp/config.yml")" "$(shasum -a 256 <"$T/b/omp/config.yml")"
  assert_eq "the .pub belongs to the key" "$(ssh-keygen -y -f "$T/b/ssh/id_ed25519")" "$(cat "$T/b/ssh/id_ed25519.pub")"
  assert_eq "the winget ids, without comments" "Git.Git OpenJS.NodeJS.LTS Oven-sh.Bun Google.Chrome DEVCOM.JetBrainsMonoNerdFont" \
    "$(tr '\n' ' ' <"$T/b/winget.txt" | sed 's/ $//')"
  assert_has "apply.ps1 travels with it" "$T/b/apply.ps1" "Sync-Files"
  assert_eq "no macOS metadata in the archive" "" "$(tar -tzf "$S/sent.tgz" | grep -E '(^|/)\._' || true)"
}

test_the_skills_are_the_librarys_skill_directories_without_links() {
  world
  sync
  assert_rc "sync" "$rc" 0
  assert_eq "skills.txt" "alpha beta" "$(tr '\n' ' ' <"$T/b/skills.txt" | sed 's/ $//')"
  assert_eq "a skill's files" "body" "$(cat "$T/b/skills/alpha/notes.md")"
  assert_absent "a directory without SKILL.md stays out" "$T/b/skills/notes"
  assert_absent "a symbolic link stays out" "$T/b/skills/alpha/outside"
  assert_has "and says so" "$T/err" "leaving out the symbolic link alpha/outside"
}

test_mcp_servers_get_the_hosts_overrides() {
  world
  sync
  local m=$T/b/omp/mcp.json mac=$ROOT/home/omp/mcp.json ov=$ROOT/hosts/windows/rex/mcp-overrides.json
  assert_eq "the host drops some servers" "true" "$(jq '.drop | length > 0' "$ov")"
  assert_eq "dropped servers are gone" "" "$(jq -r --slurpfile o "$ov" '.mcpServers | keys[] | select(. as $k | $o[0].drop | index($k))' "$m")"
  assert_eq "a dropped server leaves disabledServers too" "" "$(jq -r --slurpfile o "$ov" '(.disabledServers // [])[] | select(. as $k | $o[0].drop | index($k))' "$m")"
  assert_eq "codegraph is replaced" "npx -y @colbymchenry/codegraph@latest serve --mcp" "$(jq -r '.mcpServers.codegraph | [.command] + .args | join(" ")' "$m")"
  assert_eq "no \${HOME} is left" "0" "$(grep -c '\${HOME}' "$m")"
  assert_eq "context-mode's path uses USERPROFILE" '${USERPROFILE}/.omp/plugins/node_modules/context-mode/server.bundle.mjs' "$(jq -r '.mcpServers["context-mode"].args[0]' "$m")"
  assert_eq "a server with no override is the Mac's" "$(jq -c '.mcpServers.drawio' "$mac")" "$(jq -c '.mcpServers.drawio' "$m")"
  assert_eq "the servers keep the Mac's order" "$(jq -r --slurpfile o "$ov" '.mcpServers | keys_unsorted[] | select(. as $k | $o[0].drop | index($k) | not)' "$mac" | tr '\n' ' ')" \
    "$(jq -r '.mcpServers | keys_unsorted[]' "$m" | tr '\n' ' ')"
}

test_ssh_config_has_the_listed_hosts_with_the_hosts_own_key() {
  world
  sync
  local c=$T/b/ssh/config
  assert_eq "the Host lines, Host * last" "Host github.com|Host home 198.51.100.249|Host pxc_hermes|Host pxc_lab|Host pxc_root|Host px_lab|Host px_root|Host *" \
    "$(grep '^Host ' "$c" | tr '\n' '|' | sed 's/|$//')"
  assert_eq "every IdentityFile is the host's own key" "~/.ssh/id_ed25519" "$(awk '$1=="IdentityFile"{print $2}' "$c" | sort -u)"
  assert_eq "one IdentityFile per block that had one" "6" "$(grep -c 'IdentityFile' "$c")"
  assert_lacks "no macOS-only option" "$c" "UseKeychain"
  assert_lacks "an unlisted host stays out" "$c" "cloudflared"
  assert_has "other options stay" "$c" "  Port 443"
  assert_has "the Mac's defaults stay" "$c" "  StrictHostKeyChecking no"
}

test_tern_gets_the_macs_host_list_without_the_host_itself_plus_the_mac() {
  world
  sync
  assert_rc "sync" "$rc" 0
  assert_eq "the Mac's lines, comment and the Windows host left out, then the Mac by endpoint id" \
    "$(printf 'ubuntu@198.51.100.29\nle@198.51.100.249:8377\thome\nlex@203.0.113.40\nme@%s\tother\n%s@%s\t%s' "$EID2" "$(id -un)" "$EID" "$(hostname -s)")" \
    "$(cat "$T/b/tern-hosts.txt")"
  assert_eq "one pin per address line, port 8376 when none; none for an endpoint id" \
    "$(printf '198.51.100.29:8376 SHA256:pinA\n198.51.100.249:8377 SHA256:pinB\n203.0.113.40:8376 SHA256:pinC')" "$(cat "$T/b/tern-pins.txt")"
}

test_without_the_macs_tern_endpoint_id_nothing_is_sent() {
  world
  echo not-an-id >"$S/eid"
  sync
  assert_rc "sync" "$rc" 1
  assert_has "says why" "$T/err" "cannot read this Mac's Tern endpoint id"
  assert_lacks "nothing is sent" "$S/calls" "scp"
}

test_a_tern_host_the_mac_never_pinned_stops_the_sync() {
  world
  printf '198.51.100.29:8376 SHA256:pinA\n' >"$T/tern/known_hosts"
  sync
  assert_rc "sync" "$rc" 1
  assert_has "says which host" "$T/err" "no pinned Tern host key for 198.51.100.249:8377"
  assert_lacks "nothing is sent" "$S/calls" "scp"
}

test_the_first_sync_makes_a_key_and_stores_it_the_next_reuses_it() {
  world
  sync
  assert_rc "first sync" "$rc" 0
  assert_eq "one write to the vault" "1" "$(grep -c 'secretspec set WIN_SSH_KEYS' "$S/calls")"
  assert_eq "the bundle holds the stored key" "$(jq -r .rex "$S/vault/WIN_SSH_KEYS")" "$(cat "$T/b/ssh/id_ed25519")"
  assert_has "the key's comment names the user and the host" "$T/b/ssh/id_ed25519.pub" "user@rex"
  local first
  first=$(shasum -a 256 <"$T/b/ssh/id_ed25519")
  sync
  assert_rc "second sync" "$rc" 0
  assert_eq "still one write" "1" "$(grep -c 'secretspec set WIN_SSH_KEYS' "$S/calls")"
  assert_eq "the same key" "$first" "$(shasum -a 256 <"$T/b/ssh/id_ed25519")"
}

test_check_passes_the_flag_and_never_makes_a_key() {
  world
  sync --check
  assert_rc "check, no key yet" "$rc" 1
  assert_has "says why" "$T/err" "no SSH key for rex"
  assert_lacks "no vault write" "$S/calls" "secretspec set"
  assert_lacks "nothing is sent" "$S/calls" "scp"
  sync
  assert_lacks "an apply has no -Check" "$S/remote-cmd" "-Check"
  sync --check
  assert_rc "check" "$rc" 0
  assert_has "a check has -Check" "$S/remote-cmd" "-Bundle \$d -Check"
  assert_has "the host deletes its copies" "$S/remote-cmd" "Remove-Item -Recurse -Force -LiteralPath \$d,\$t"
}

test_an_unpinned_host_key_stops_the_sync_before_any_secret_is_read() {
  world
  echo unpinned >"$S/probe"
  sync
  assert_rc "sync" "$rc" 1
  assert_has "says why" "$T/err" "never trusts a key on first use"
  assert_lacks "no vault read" "$S/calls" "secretspec"
  assert_lacks "nothing is sent" "$S/calls" "scp"
}

test_the_hosts_exit_code_is_the_syncs() {
  world
  echo 1 >"$S/remote-rc"
  sync
  assert_rc "sync" "$rc" 1
}

test_apply_ps1_is_ascii() {
  assert_eq "no byte outside printable ASCII, tab and newline" "" "$(LC_ALL=C grep -n "$(printf '[^\t -~]')" "$ROOT/hosts/windows/apply.ps1" || true)"
}

# render_repo: a small repo for win-render.py itself, with one host x.
render_repo() {
  R=$T/repo
  mkdir -p "$R/home/omp/plugins" "$R/home/tern" "$R/hosts/windows/x" "$T/stage/omp" "$T/stage/ssh"
  echo 'a: 1' >"$R/home/omp/config.yml"
  echo 'b: 2' >"$R/home/omp/models.yml"
  echo '{"mcpServers": {"one": {"command": "${HOME}/one"}, "two": {"command": "two"}}, "disabledServers": ["two"]}' >"$R/home/omp/mcp.json"
  for f in package.json bun.lock omp-plugins.lock.json; do echo "$f" >"$R/home/omp/plugins/$f"; done
  echo '{}' >"$R/home/tern/settings.json"
  echo '{"drop": ["two"], "replace": {}}' >"$R/hosts/windows/x/mcp-overrides.json"
  echo 'h1' >"$R/hosts/windows/x/ssh-hosts.txt"
  mkdir -p "$T/rt"
  printf 'me@box\n' >"$T/rt/hosts"
  echo 'Some.Id' >"$R/hosts/windows/x/winget.txt"
  echo '{"h1": {"data": {"header": "Host h1", "HostName": "box"}}}' >"$T/ssh.json"
  echo 'box:8376 SHA256:pin' >"$T/rt/known_hosts"
  for f in omp/env ssh/id_ed25519 ssh/id_ed25519.pub; do echo x >"$T/stage/$f"; done
}

render() {
  python3 "$ROOT/hosts/windows/win-render.py" "$R" x "$T/stage" "$T/ssh.json" "$T/rt" 192.0.2.10 "${MAC_LINE:-mac@$EID}" >"$T/out" 2>"$T/err"
  rc=$?
}

test_the_render_drops_a_disabled_server_and_rewrites_home() {
  render_repo
  render
  assert_rc "render" "$rc" 0
  assert_eq "the result" '{"mcpServers":{"one":{"command":"${USERPROFILE}/one"}},"disabledServers":[]}' "$(jq -c . "$T/stage/omp/mcp.json")"
}

test_the_render_refuses_overrides_for_servers_the_mac_lacks() {
  render_repo
  echo '{"drop": ["ghost"], "replace": {}}' >"$R/hosts/windows/x/mcp-overrides.json"
  render
  assert_rc "render" "$rc" 1
  assert_has "names it" "$T/err" "does not have: ghost"
}

test_the_render_refuses_a_host_alias_the_mac_lacks() {
  render_repo
  echo 'nowhere' >"$R/hosts/windows/x/ssh-hosts.txt"
  render
  assert_rc "render" "$rc" 1
  assert_has "names it" "$T/err" "nowhere matches 0 Host blocks"
}

test_the_render_refuses_a_tern_line_it_cannot_read() {
  render_repo
  printf 'me@box\nme@bad host!\n' >"$T/rt/hosts"
  render
  assert_rc "render" "$rc" 1
  assert_has "names it" "$T/err" "not [user@]host[:port]: 'me@bad host!'"
}

test_the_macs_own_line_must_be_an_endpoint_id() {
  render_repo
  MAC_LINE=mac@203.0.113.7 render
  assert_rc "an address" "$rc" 1
  assert_has "says why" "$T/err" "the Mac's own Tern line is not <user>@<endpoint id>"
  MAC_LINE=$(printf 'mac@%s\tmac' "$EID") render
  assert_rc "an endpoint id" "$rc" 0
  assert_eq "it ends the list, with no pin" "$(printf 'me@box\nmac@%s\tmac' "$EID")" "$(cat "$T/stage/tern-hosts.txt")"
  assert_eq "the other line's pin" "box:8376 SHA256:pin" "$(cat "$T/stage/tern-pins.txt")"
}

test_the_render_needs_the_secret_files_first() {
  render_repo
  rm "$T/stage/omp/env"
  render
  assert_rc "render" "$rc" 1
  assert_has "names it" "$T/err" "the bundle has no omp/env"
}

tl_init_pure
tl_run_all
tl_done
