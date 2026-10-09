#!/usr/bin/env bash
# Tests for infra/vm-sync-remote.sh, the helper that vm-sync and vm-deploy run on the VM as the
# agent user: it writes the Hindsight file, prepares the skills directory, reports the plugin install and
# removes what the sync placed. Run here against a temp HOME, as the user would run it there.
# Fixtures only. The token is a fixture string, never a real one.
set -uo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../home/secretspec/testlib.sh
. "$ROOT/home/secretspec/testlib.sh" || exit 1
HELPER=$ROOT/infra/vm-sync-remote.sh
HS_URL=https://hindsight.fixture.example
HS_TOKEN=fixture0hstoken0123456789abcdefABCD
HS_TOKEN2=fixture0hstoken0second012345678ABCD
HS_MARK='# vm-sync: written from the vault map VM_HINDSIGHT; vm-sync removes it when the VM has no entry'

# h SUBCOMMAND ARGS...: run the helper as the user (stdin from $T/stdin, empty unless set).
h() {
  [ -f "$T/stdin" ] || : >"$T/stdin"
  HOME=$T_HOME bash "$HELPER" "$@" <"$T/stdin" >"$T/out" 2>"$T/err"
  echo $?
}
# hhs URL TOKEN: the hindsight subcommand with the two lines on stdin.
hhs() { printf '%s\n%s\n' "$1" "$2" >"$T/stdin"; h hindsight; }
HSENV() { echo "$T_HOME/.config/dotfiles/hindsight.env"; }
MANIFEST() { echo "$T_HOME/.local/state/dotfiles/vm-sync/manifest"; }
SKILLS() { echo "$T_HOME/.omp/agent/skills"; }
# snapshot DIR: every path under DIR with its type, mode and, for files, content hash.
snapshot() {
  (cd "$1" && find . -mindepth 1 | LC_ALL=C sort | while IFS= read -r p; do
    if [ -L "$p" ]; then
      printf '%s L %s\n' "$p" "$(readlink "$p")"
    elif [ -d "$p" ]; then
      printf '%s D %s\n' "$p" "$(tl_mode "$p")"
    else
      printf '%s F %s %s\n' "$p" "$(tl_mode "$p")" "$(shasum -a 256 <"$p" | cut -c1-16)"
    fi
  done)
}
# wcinstall NAME: install ~/.omp/plugins/NAME the way the Home Manager activation does, with the real writable_copy
# (home/linux/writable-copy.sh), so that the record it keeps has its real name and unsync is tested against that.
wcinstall() {
  mkdir -p "$T/psrc"
  [ -f "$T/psrc/$1" ] || printf '{}' >"$T/psrc/$1"
  (
    export HOME=$T_HOME
    set -eu -o pipefail
    run() { "$@"; }
    # shellcheck source=../home/linux/writable-copy.sh
    . "$ROOT/home/linux/writable-copy.sh"
    writable_copy "$T/psrc/$1" "$T_HOME/.omp/plugins/$1"
  ) >/dev/null
}
# wcrecords: how many writable-copy records of the plugin files there are.
wcrecords() { ls "$T_HOME/.local/state/dotfiles/writable-copy" 2>/dev/null | grep -c '_\.omp_plugins_'; }
# mkplugins: what the plugin sync leaves: manifests, node_modules, records, the install stamp.
mkplugins() {
  mkdir -p "$T_HOME/.omp/plugins/node_modules/some-plugin" "$T_HOME/.local/state/dotfiles"
  wcinstall package.json
  wcinstall bun.lock
  wcinstall omp-plugins.lock.json
  printf 'x' >"$T_HOME/.omp/plugins/node_modules/some-plugin/index.js"
  printf 'h4' >"$T_HOME/.local/state/dotfiles/omp-plugins.stamp"
}
# mkhome: a user's home with things the sync must never touch.
mkhome() {
  mkdir -p "$T_HOME/.omp/agent" "$T_HOME/.config/mise" "$T_HOME/.local/share/mise"
  printf 'provider: x' >"$T_HOME/.omp/agent/config.yml"
  printf 'tools' >"$T_HOME/.config/mise/config.toml"
  printf 'zsh' >"$T_HOME/.zshrc"
  printf 'tool' >"$T_HOME/.local/share/mise/installed"
}

# ---- skills-prepare

test_skills_prepare_makes_the_directory_and_lists_the_names() {
  assert_rc "prepare" "$(h skills-prepare alpha beta-1 gamma.x)" 0
  assert_eq "directory" yes "$([ -d "$(SKILLS)" ] && echo yes)"
  assert_has "alpha listed" "$(MANIFEST)" "skill alpha"
  assert_has "beta listed" "$(MANIFEST)" "skill beta-1"
  assert_has "gamma listed" "$(MANIFEST)" "skill gamma.x"
  assert_has "the directory it made is listed" "$(MANIFEST)" "dir .omp/agent/skills"
  assert_rc "again" "$(h skills-prepare alpha)" 0
  assert_eq "no duplicate" 1 "$(grep -cx 'skill alpha' "$(MANIFEST)")"
  assert_eq "the skill directories are rsync's to create" "" "$(ls -A "$(SKILLS)")"
}

test_skills_prepare_rejects_bad_names_and_records_nothing() {
  local bad
  for bad in '..' '.' 'a/b' '-x' '.hidden' 'sp ace' '$(x)' 'a;b' '' '/abs'; do
    assert_rc "name: $bad" "$(h skills-prepare good "$bad")" 1
    assert_absent "nothing recorded for: $bad" "$(MANIFEST)"
    assert_absent "no skills directory for: $bad" "$(SKILLS)"
  done
  assert_rc "no names" "$(h skills-prepare)" 2
}

test_skills_prepare_refuses_a_link_in_place_of_a_skill() {
  mkdir -p "$(SKILLS)" "$T/elsewhere"
  ln -s "$T/elsewhere" "$(SKILLS)/alpha"
  assert_rc "link" "$(h skills-prepare alpha)" 1
  assert_has "names the entry" "$T/err" "alpha"
  assert_absent "nothing recorded" "$(MANIFEST)"
  printf 'f' >"$(SKILLS)/file-skill"
  assert_rc "a file" "$(h skills-prepare file-skill)" 1
}

test_skills_prepare_refuses_a_link_in_place_of_the_skills_directory_or_above_it() {
  mkdir -p "$T_HOME/.omp/agent" "$T/elsewhere"
  ln -s "$T/elsewhere" "$(SKILLS)"
  assert_rc "skills directory is a link" "$(h skills-prepare alpha)" 1
  assert_absent "nothing recorded" "$(MANIFEST)"
  assert_eq "nothing was made behind the link" "" "$(ls -A "$T/elsewhere")"
  rm "$(SKILLS)"
  rm -rf "$T_HOME/.omp/agent"
  ln -s "$T/elsewhere" "$T_HOME/.omp/agent"
  assert_rc "agent directory is a link" "$(h skills-prepare alpha)" 1
  assert_eq "nothing was made behind that link" "" "$(ls -A "$T/elsewhere")"
}

test_skills_prepare_leaves_other_entries_alone() {
  mkdir -p "$(SKILLS)/mine"
  printf 'mine' >"$(SKILLS)/mine/SKILL.md"
  local before
  before=$(snapshot "$(SKILLS)")
  assert_rc "prepare" "$(h skills-prepare alpha)" 0
  assert_eq "unchanged" "$before" "$(snapshot "$(SKILLS)")"
  assert_lacks "the directory pre-existed, so it is not ours to remove" "$(MANIFEST)" "dir .omp/agent/skills"
}

# ---- unsync

test_unsync_removes_the_synced_skills_and_keeps_the_others() {
  mkdir -p "$(SKILLS)/mine"
  printf 'mine' >"$(SKILLS)/mine/SKILL.md"
  assert_rc "prepare" "$(h skills-prepare alpha beta)" 0
  mkdir -p "$(SKILLS)/alpha/sub" "$(SKILLS)/beta"
  printf 'a' >"$(SKILLS)/alpha/sub/f"
  printf 'b' >"$(SKILLS)/beta/SKILL.md"
  assert_rc "unsync" "$(h unsync)" 0
  assert_absent "alpha gone" "$(SKILLS)/alpha"
  assert_absent "beta gone" "$(SKILLS)/beta"
  assert_eq "the user's skill stays" mine "$(cat "$(SKILLS)/mine/SKILL.md")"
  assert_eq "the directory stays while it holds something" yes "$([ -d "$(SKILLS)" ] && echo yes)"
}

test_unsync_removes_a_skills_directory_it_made_and_not_one_it_found() {
  assert_rc "prepare" "$(h skills-prepare alpha)" 0
  mkdir -p "$(SKILLS)/alpha"
  assert_rc "unsync" "$(h unsync)" 0
  assert_absent "the directory it made is gone" "$(SKILLS)"
  assert_absent ".omp/agent is gone too (made by it)" "$T_HOME/.omp"
  rm -rf "$T_HOME/.omp" "$T_HOME/.local"
  mkdir -p "$(SKILLS)"
  assert_rc "prepare in an existing, empty directory" "$(h skills-prepare alpha)" 0
  mkdir -p "$(SKILLS)/alpha"
  assert_rc "unsync" "$(h unsync)" 0
  assert_eq "the empty directory that was there before stays" yes "$([ -d "$(SKILLS)" ] && echo yes)"
}

test_unsync_leaves_everything_else_exactly_as_it_was() {
  mkhome
  local before after
  before=$(snapshot "$T_HOME" | grep ' F ')
  assert_rc "hindsight" "$(hhs "$HS_URL" "$HS_TOKEN")" 0
  assert_rc "prepare" "$(h skills-prepare alpha beta)" 0
  mkdir -p "$(SKILLS)/alpha" "$(SKILLS)/beta"
  printf 'a' >"$(SKILLS)/alpha/SKILL.md"
  mkplugins
  assert_rc "unsync" "$(h unsync)" 0
  # Every file, with its mode and content hash, is as it was before the sync: the ones the user has
  # are untouched and none of the synced ones is left. (Directories of the activation may remain.)
  after=$(snapshot "$T_HOME" | grep ' F ')
  assert_eq "the set of files, modes and contents" "$before" "$after"
  assert_eq "no dotfiles config directory is left" "" "$(ls -A "$T_HOME/.config" | grep -x dotfiles)"
}

test_unsync_removes_the_plugin_install_and_its_records() {
  mkhome
  mkplugins
  assert_eq "the records are those of the real writable_copy" 3 "$(wcrecords)"
  assert_rc "unsync" "$(h unsync)" 0
  assert_absent "plugins home" "$T_HOME/.omp/plugins"
  assert_absent "install stamp" "$T_HOME/.local/state/dotfiles/omp-plugins.stamp"
  assert_eq "the three records are gone" 0 "$(wcrecords)"
  assert_eq "omp's own config stays" "provider: x" "$(cat "$T_HOME/.omp/agent/config.yml")"
}

test_unsync_leaves_a_plugins_home_that_the_activation_did_not_place() {
  mkdir -p "$T_HOME/.omp/plugins/node_modules/x"
  printf '{"mine":true}' >"$T_HOME/.omp/plugins/package.json"
  assert_rc "unsync" "$(h unsync)" 0
  assert_eq "the user's plugins home stays" '{"mine":true}' "$(cat "$T_HOME/.omp/plugins/package.json")"
}

test_unsync_does_not_follow_a_link_in_place_of_the_plugins_home() {
  mkdir -p "$T/elsewhere"
  printf 'keep' >"$T/elsewhere/f"
  mkdir -p "$T_HOME/.omp" "$T_HOME/.local/state/dotfiles/writable-copy"
  ln -s "$T/elsewhere" "$T_HOME/.omp/plugins"
  wcinstall package.json
  assert_rc "unsync" "$(h unsync)" 0
  assert_eq "the link's target is untouched" keep "$(cat "$T/elsewhere/f")"
}

test_unsync_does_not_follow_a_link_above_a_recorded_path() {
  mkdir -p "$T/elsewhere/dotfiles" "$T/elsewhere/skills/alpha" "$T_HOME/.config" "$T_HOME/.omp/agent" "$T_HOME/.local/state/dotfiles/vm-sync"
  printf 'keep' >"$T/elsewhere/dotfiles/hindsight.env"
  printf 'keep' >"$T/elsewhere/skills/alpha/SKILL.md"
  ln -s "$T/elsewhere/dotfiles" "$T_HOME/.config/dotfiles"
  ln -s "$T/elsewhere/skills" "$T_HOME/.omp/agent/skills"
  printf 'file .config/dotfiles/hindsight.env\nskill alpha\n' >"$(MANIFEST)"
  assert_rc "unsync" "$(h unsync)" 1
  assert_eq "the file behind the linked directory stays" keep "$(cat "$T/elsewhere/dotfiles/hindsight.env")"
  assert_eq "the skill behind the linked directory stays" keep "$(cat "$T/elsewhere/skills/alpha/SKILL.md")"
  assert_has "says it refused" "$T/err" "refused"
  assert_eq "the manifest is kept for a retry" yes "$([ -f "$(MANIFEST)" ] && echo yes)"
}

test_unsync_refuses_manifest_lines_that_point_outside() {
  mkdir -p "$T_HOME/.local/state/dotfiles/vm-sync" "$T/outside/victim"
  printf 'keep' >"$T/outside/victim/f"
  printf 'keep' >"$T_HOME/.kept"
  printf 'keep' >"$T_HOME/bad name"
  printf 'keep' >"$T_HOME/.bad;name"
  # The way out of the home and back in to the victim file, as the kernel resolves it.
  local tn up n
  tn=$(cd "$T" && pwd -P)
  n=$(printf '%s' "$T_HOME" | tr -cd '/' | wc -c | tr -d ' ')
  up=$(printf '../%.0s' $(seq 1 "$n"))
  cat >"$(MANIFEST)" <<EOF
file ${up}${tn#/}/outside/victim/f
file $T/outside/victim/f
skill ../outside
skill ..
dir ../..
file .kept/../.kept
file bad name
file .bad;name
file
unknown thing
EOF
  assert_eq "the line really leads to the victim" keep "$(cat "$T_HOME/${up}${tn#/}/outside/victim/f")"
  assert_rc "unsync" "$(h unsync)" 1
  assert_eq "outside file stays" keep "$(cat "$T/outside/victim/f")"
  assert_eq "inside file stays" keep "$(cat "$T_HOME/.kept")"
  assert_eq "a name with a space is not a manifest entry" keep "$(cat "$T_HOME/bad name")"
  assert_eq "a name with a semicolon is not a manifest entry" keep "$(cat "$T_HOME/.bad;name")"
  assert_has "says a line was refused" "$T/err" "refused"
}

test_unsync_exits_1_and_keeps_its_evidence_when_a_removal_fails() {
  mkhome
  mkplugins
  assert_rc "prepare" "$(h skills-prepare alpha)" 0
  mkdir -p "$(SKILLS)/alpha/sub"
  printf 'a' >"$(SKILLS)/alpha/sub/f"
  chmod 555 "$(SKILLS)/alpha/sub" "$T_HOME/.omp/plugins/node_modules/some-plugin"
  assert_rc "unsync with two removals that fail" "$(h unsync)" 1
  assert_has "names the skill" "$T/err" "could not remove ~/.omp/agent/skills/alpha"
  assert_has "names the plugin install" "$T/err" "could not remove ~/.omp/plugins"
  assert_lacks "does not claim there was nothing to do" "$T/out" "nothing to remove"
  assert_eq "the manifest is kept for a retry" yes "$([ -f "$(MANIFEST)" ] && echo yes)"
  assert_eq "the three records are kept" 3 "$(wcrecords)"
  assert_eq "the install stamp is kept" yes "$([ -f "$T_HOME/.local/state/dotfiles/omp-plugins.stamp" ] && echo yes)"
  chmod 755 "$(SKILLS)/alpha/sub" "$T_HOME/.omp/plugins/node_modules/some-plugin"
  assert_rc "the retry works" "$(h unsync)" 0
  assert_absent "skill gone" "$(SKILLS)/alpha"
  assert_absent "plugin install gone" "$T_HOME/.omp/plugins"
  assert_eq "the records are gone" 0 "$(wcrecords)"
  assert_absent "manifest gone" "$(MANIFEST)"
}

test_unsync_refuses_manifest_lines_for_files_of_the_user_inside_the_home() {
  mkhome
  mkdir -p "$T_HOME/.config/gh" "$T_HOME/.omp/agent/skills/theirs" "$T_HOME/.local/state/dotfiles/vm-sync"
  printf 'login' >"$T_HOME/.config/gh/hosts.yml"
  printf 'keys' >"$T_HOME/.omp/.env"
  printf 'theirs' >"$T_HOME/.omp/agent/skills/theirs/SKILL.md"
  printf 'user' >"$T_HOME/precious.dotfiles-backup"
  cat >"$(MANIFEST)" <<EOF
file .config/gh/hosts.yml
file .omp/.env
file .zshrc
backup precious.dotfiles-backup
backup .config/gh/hosts.yml.dotfiles-backup
dir .config/gh
dir .local
dir .ssh
skill ..
EOF
  assert_rc "unsync" "$(h unsync)" 1
  assert_eq "hosts.yml stays" login "$(cat "$T_HOME/.config/gh/hosts.yml")"
  assert_eq "~/.omp/.env stays" keys "$(cat "$T_HOME/.omp/.env")"
  assert_eq ".zshrc stays" zsh "$(cat "$T_HOME/.zshrc")"
  assert_eq "the user's skill stays" theirs "$(cat "$T_HOME/.omp/agent/skills/theirs/SKILL.md")"
  assert_eq "a backup of the user's own stays where it is" user "$(cat "$T_HOME/precious.dotfiles-backup")"
  assert_eq "every one of the nine lines was refused" 9 "$(grep -c 'refused manifest line' "$T/err")"
  assert_eq "the manifest is kept" yes "$([ -f "$(MANIFEST)" ] && echo yes)"
}

test_unsync_with_nothing_to_remove_succeeds_and_twice_is_the_same() {
  mkhome
  local before
  before=$(snapshot "$T_HOME")
  assert_rc "nothing placed" "$(h unsync)" 0
  assert_has "says so" "$T/out" "nothing"
  assert_eq "nothing changed" "$before" "$(snapshot "$T_HOME")"
  assert_rc "hindsight" "$(hhs "$HS_URL" "$HS_TOKEN")" 0
  assert_rc "unsync" "$(h unsync)" 0
  assert_rc "unsync again" "$(h unsync)" 0
}

test_unsync_stops_the_install_service_first_when_systemd_is_there() {
  mkdir -p "$T/bin"
  printf '#!/bin/sh\nprintf "%%s\\n" "$*" >>"%s/systemctl.log"\nexit 0\n' "$T" >"$T/bin/systemctl"
  chmod +x "$T/bin/systemctl"
  mkplugins
  HOME=$T_HOME PATH="$T/bin:$PATH" bash "$HELPER" unsync >"$T/out" 2>"$T/err"
  assert_rc "unsync" "$?" 0
  assert_has "stopped the unit" "$T/systemctl.log" "--user stop omp-plugins-install.service"
  assert_has "stopped the Mason install too, so that none runs on as the removed user" "$T/systemctl.log" "--user stop mason-lsp-install.service"
}

# stub_systemctl ACTIVE [STOP_RC]: a systemctl that logs every call to $T/systemctl.log, prints ACTIVE for `--user is-active docker.service`
# (what the unit reports after the stop: inactive, active, deactivating, ...) and exits STOP_RC (default 0) for a stop of docker.service.
stub_systemctl() {
  mkdir -p "$T/bin"
  cat >"$T/bin/systemctl" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >>"$T/systemctl.log"
case "\$*" in
  "--user is-active docker.service") echo "$1"; [ "$1" = active ] && exit 0; exit 3 ;;
  "--user stop docker.service") exit ${2:-0} ;;
esac
exit 0
EOF
  chmod +x "$T/bin/systemctl"
}

test_unsync_stops_the_rootless_docker_service_and_looks_that_it_is_down() {
  stub_systemctl inactive
  mkplugins
  HOME=$T_HOME PATH="$T/bin:$PATH" bash "$HELPER" unsync >"$T/out" 2>"$T/err"
  assert_rc "unsync" "$?" 0
  assert_has "stopped the rootless Docker service, so that its daemon and containers do not run on as the removed user" "$T/systemctl.log" "--user stop docker.service"
  assert_has "asked whether it is down" "$T/systemctl.log" "--user is-active docker.service"
  assert_eq "the stop came before the question" "--user stop docker.service" "$(grep -F 'docker.service' "$T/systemctl.log" | head -n 1)"
}

test_unsync_refuses_while_the_rootless_docker_service_is_still_up() {
  stub_systemctl active
  assert_rc "hindsight" "$(hhs "$HS_URL" "$HS_TOKEN")" 0
  HOME=$T_HOME PATH="$T/bin:$PATH" bash "$HELPER" unsync >"$T/out" 2>"$T/err"
  assert_rc "unsync" "$?" 1
  assert_has "names the service" "$T/err" "rootless Docker service"
  assert_eq "the manifest is kept for a retry" yes "$([ -f "$(MANIFEST)" ] && echo yes)"
  stub_systemctl deactivating
  HOME=$T_HOME PATH="$T/bin:$PATH" bash "$HELPER" unsync >"$T/out" 2>"$T/err"
  assert_rc "a service that is still stopping is not down either" "$?" 1
  stub_systemctl failed
  HOME=$T_HOME PATH="$T/bin:$PATH" bash "$HELPER" unsync >"$T/out" 2>"$T/err"
  assert_rc "a failed service has no process left: down" "$?" 0
}

test_unsync_without_a_docker_unit_is_fine() {
  stub_systemctl inactive 5
  mkplugins
  HOME=$T_HOME PATH="$T/bin:$PATH" bash "$HELPER" unsync >"$T/out" 2>"$T/err"
  assert_rc "a stop that says not loaded (5) is no failure when nothing runs" "$?" 0
  assert_lacks "and nothing is reported" "$T/err" "Docker"
}

test_unsync_leaves_the_docker_and_podman_data_alone() {
  stub_systemctl inactive
  mkplugins
  lput .local/share/docker/volumes/v1/_data/db 'rows' 644
  lput .local/share/docker/image/overlay2/repositories.json '{}' 644
  lput .local/share/containers/storage/overlay-images/images.json '[]' 644
  lput .config/docker/daemon.json '{}' 644
  lput .config/lazydocker/config.yml 'mine: 1' 644
  lput .config/lazygit/config.yml 'mine: 2' 644
  local want
  want=$(cd "$T_HOME" && find .local/share/docker .local/share/containers .config/docker .config/lazydocker .config/lazygit -type f | LC_ALL=C sort | xargs shasum -a 256)
  HOME=$T_HOME PATH="$T/bin:$PATH" bash "$HELPER" unsync >"$T/out" 2>"$T/err"
  assert_rc "unsync" "$?" 0
  assert_eq "no Docker, podman, lazydocker or lazygit file was removed or changed" "$want" "$(cd "$T_HOME" && find .local/share/docker .local/share/containers .config/docker .config/lazydocker .config/lazygit -type f | LC_ALL=C sort | xargs shasum -a 256)"
}

test_unsync_leaves_the_mason_install_and_every_neovim_file_alone() {
  mkdir -p "$T/bin"
  printf '#!/bin/sh\nexit 0\n' >"$T/bin/systemctl"
  chmod +x "$T/bin/systemctl"
  mkplugins
  lput .local/share/nvim/mason/packages/gopls/mason-receipt.json '{"name":"gopls"}' 644
  lput .local/share/nvim/mason/bin/gopls 'x' 755
  lput .local/state/dotfiles/mason-lsp.stamp 'abc' 644
  lput .local/state/nvim/mason.log 'log' 644
  lput .config/nvim/init.lua 'mine' 644
  local before
  before=$(cd "$T_HOME" && find .local/share/nvim .local/state/dotfiles/mason-lsp.stamp .local/state/nvim .config/nvim -type f | LC_ALL=C sort | xargs shasum -a 256)
  HOME=$T_HOME PATH="$T/bin:$PATH" bash "$HELPER" unsync >"$T/out" 2>"$T/err"
  assert_rc "unsync" "$?" 0
  assert_eq "no Mason or Neovim file was removed or changed" "$before" "$(cd "$T_HOME" && find .local/share/nvim .local/state/dotfiles/mason-lsp.stamp .local/state/nvim .config/nvim -type f | LC_ALL=C sort | xargs shasum -a 256)"
  assert_absent "while the plugin install is gone" "$T_HOME/.omp/plugins"
}

# ---- hindsight

test_hindsight_writes_the_env_file_for_zsh() {
  assert_rc "hindsight" "$(hhs "$HS_URL" "$HS_TOKEN")" 0
  assert_bytes "file content" "$(HSENV)" "$HS_MARK
HINDSIGHT_API_URL='$HS_URL'
HINDSIGHT_API_TOKEN='$HS_TOKEN'
"
  assert_eq "mode 600" 600 "$(tl_mode "$(HSENV)")"
  assert_eq "its directory is 700" 700 "$(tl_mode "$T_HOME/.config/dotfiles")"
  assert_has "manifest lists the file" "$(MANIFEST)" "file .config/dotfiles/hindsight.env"
  assert_has "manifest lists the directory it made" "$(MANIFEST)" "dir .config/dotfiles"
  assert_lacks "the key is not in stdout" "$T/out" "$HS_TOKEN"
  assert_lacks "the key is not in stderr" "$T/err" "$HS_TOKEN"
  assert_lacks "the key is not in the manifest" "$(MANIFEST)" "$HS_TOKEN"
  assert_absent "~/.omp/.env is not touched" "$T_HOME/.omp/.env"
}

test_hindsight_file_is_valid_for_a_shell_and_exports_both_variables() {
  assert_rc "hindsight" "$(hhs "https://h.fixture.example:8443/api" "$HS_TOKEN")" 0
  local got
  got=$(env -i PATH="$PATH" HOME="$T_HOME" bash -c 'set -a; . "$HOME/.config/dotfiles/hindsight.env"; set +a; printf "%s|%s" "$HINDSIGHT_API_URL" "$HINDSIGHT_API_TOKEN"')
  assert_eq "what a shell reads from it" "https://h.fixture.example:8443/api|$HS_TOKEN" "$got"
}

test_hindsight_rejects_a_url_or_key_of_a_wrong_shape_and_writes_nothing() {
  local bad
  for bad in 'http://hindsight.fixture.example' 'ftp://hindsight.fixture.example' 'https://hindsight.fixture.example/p?x=1' 'https://user@hindsight.fixture.example' 'https://hind sight.fixture.example' "https://hindsight.fixture.example/'x" 'https://hindsight.fixture.example/$x' 'https://hindsight.fixture.example;id' 'hindsight.fixture.example' 'https://' ''; do
    assert_rc "url: $bad" "$(hhs "$bad" "$HS_TOKEN")" 1
    assert_absent "no file for the url: $bad" "$(HSENV)"
    assert_lacks "stderr hides the key" "$T/err" "$HS_TOKEN"
  done
  for bad in 'short' 'has space in it 0123456789abcdef' "quote'0123456789abcdefghijklmnop" 'dollar$0123456789abcdefghijklmnop' '~0123456789abcdefghijklmnop' 'slash/0123456789abcdefghijklmnop' 'semi;0123456789abcdefghijklmnop' ''; do
    assert_rc "key: $bad" "$(hhs "$HS_URL" "$bad")" 1
    assert_absent "no file for the key: $bad" "$(HSENV)"
    assert_lacks "stderr hides the key" "$T/err" "0123456789abcdefghijklmnop"
  done
  printf '%s\n%s\n%s\n' "$HS_URL" "$HS_TOKEN" "$HS_TOKEN2" >"$T/stdin"
  assert_rc "three lines" "$(h hindsight)" 1
  printf '%s\n' "$HS_URL" >"$T/stdin"
  assert_rc "one line" "$(h hindsight)" 1
  assert_absent "no file" "$(HSENV)"
  assert_absent "no manifest" "$(MANIFEST)"
}

test_hindsight_overwrites_its_own_file_and_keeps_a_file_it_did_not_write() {
  assert_rc "first" "$(hhs "$HS_URL" "$HS_TOKEN")" 0
  assert_rc "second" "$(hhs "$HS_URL" "$HS_TOKEN2")" 0
  assert_has "new key" "$(HSENV)" "$HS_TOKEN2"
  assert_lacks "old key gone" "$(HSENV)" "$HS_TOKEN"
  assert_absent "no backup of its own file" "$(HSENV).dotfiles-backup"
  assert_eq "listed once" 1 "$(grep -cx 'file .config/dotfiles/hindsight.env' "$(MANIFEST)")"
  assert_rc "unsync" "$(h unsync)" 0
  assert_absent "file removed" "$(HSENV)"
  assert_absent "its directory removed too" "$T_HOME/.config/dotfiles"
  # a file the user made there
  mkdir -p "$T_HOME/.config/dotfiles"
  printf 'HINDSIGHT_API_URL=mine\n' >"$(HSENV)"
  assert_rc "over the user's file" "$(hhs "$HS_URL" "$HS_TOKEN")" 0
  assert_has "the user's file is kept" "$(HSENV).dotfiles-backup" "HINDSIGHT_API_URL=mine"
  assert_rc "unsync" "$(h unsync)" 0
  assert_has "and put back" "$(HSENV)" "HINDSIGHT_API_URL=mine"
}

test_hindsight_remove_deletes_its_file_and_says_so_in_one_line() {
  assert_rc "write" "$(hhs "$HS_URL" "$HS_TOKEN")" 0
  assert_rc "remove" "$(h hindsight-remove testvm-alpha)" 0
  assert_absent "file gone" "$(HSENV)"
  assert_eq "one line of output" 1 "$(wc -l <"$T/out" | tr -d ' ')"
  assert_has "names the VM and the vault key" "$T/out" "no entry for testvm-alpha in VM_HINDSIGHT"
  assert_has "says it removed" "$T/out" "removed"
  assert_lacks "no key in the notice" "$T/out" "$HS_TOKEN"
  assert_lacks "the manifest forgets the file" "$(MANIFEST)" "hindsight.env"
}

test_hindsight_remove_with_no_file_or_a_file_it_did_not_write() {
  assert_rc "no file" "$(h hindsight-remove testvm-alpha)" 0
  assert_eq "one line" 1 "$(wc -l <"$T/out" | tr -d ' ')"
  assert_has "says there is nothing" "$T/out" "no file to remove"
  mkdir -p "$T_HOME/.config/dotfiles"
  printf 'HINDSIGHT_API_URL=mine\n' >"$(HSENV)"
  assert_rc "a file of the user" "$(h hindsight-remove testvm-alpha)" 0
  assert_eq "it stays" "HINDSIGHT_API_URL=mine" "$(cat "$(HSENV)")"
  assert_eq "one line" 1 "$(wc -l <"$T/out" | tr -d ' ')"
  assert_has "says why" "$T/out" "not written by vm-sync"
}

test_hindsight_remove_takes_one_plain_name() {
  assert_rc "none" "$(h hindsight-remove)" 2
  assert_rc "bad name" "$(h hindsight-remove 'a b')" 1
  assert_rc "two" "$(h hindsight-remove a b)" 2
}

test_hindsight_remove_does_not_follow_a_link_above_the_file() {
  mkdir -p "$T/elsewhere" "$T_HOME/.config"
  printf '%s\nHINDSIGHT_API_URL=x\n' "$HS_MARK" >"$T/elsewhere/hindsight.env"
  ln -s "$T/elsewhere" "$T_HOME/.config/dotfiles"
  assert_rc "remove" "$(h hindsight-remove testvm-alpha)" 1
  assert_has "the file behind the link stays" "$T/elsewhere/hindsight.env" "HINDSIGHT_API_URL=x"
}

test_hindsight_write_does_not_follow_a_link_above_the_file() {
  mkdir -p "$T/elsewhere" "$T_HOME/.config"
  ln -s "$T/elsewhere" "$T_HOME/.config/dotfiles"
  assert_rc "write" "$(hhs "$HS_URL" "$HS_TOKEN")" 1
  assert_absent "nothing was written behind the link" "$T/elsewhere/hindsight.env"
  assert_has "says why" "$T/err" "is a link"
  assert_lacks "stderr hides the key" "$T/err" "$HS_TOKEN"
}

test_hindsight_replaces_a_link_and_unsync_puts_it_back() {
  mkdir -p "$T_HOME/.config/dotfiles"
  printf 'target' >"$T/target"
  ln -s "$T/target" "$(HSENV)"
  assert_rc "hindsight" "$(hhs "$HS_URL" "$HS_TOKEN")" 0
  assert_eq "a regular file now" "" "$(find "$(HSENV)" -type l)"
  assert_eq "the link's target is untouched" target "$(cat "$T/target")"
  assert_rc "unsync" "$(h unsync)" 0
  assert_eq "the link is back" "$T/target" "$(readlink "$(HSENV)")"
}

# ---- plugins-status

test_plugins_status_reports_installed_and_not_yet() {
  assert_rc "nothing" "$(h plugins-status)" 0
  assert_has "not installed" "$T/out" "not installed yet"
  mkplugins
  assert_rc "installed" "$(h plugins-status)" 0
  assert_has "installed" "$T/out" "installed"
  assert_lacks "not the other message" "$T/out" "not installed yet"
}

test_an_unknown_subcommand_exits_2() {
  assert_rc "none" "$(h)" 2
  assert_rc "unknown" "$(h frobnicate)" 2
}

tl_init_pure
tl_run_all
tl_done
