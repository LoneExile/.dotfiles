#!/usr/bin/env bash
# Tests for infra/vm-sync-remote.sh, the helper that vm-sync and vm-deploy run on the VM as the
# agent user: it writes the gh login, prepares the skills directory, reports the plugin install and
# removes what the sync placed. Run here against a temp HOME, as the user would run it there.
# Fixtures only. The token is a fixture string, never a real one.
set -uo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../home/secretspec/testlib.sh
. "$ROOT/home/secretspec/testlib.sh" || exit 1
HELPER=$ROOT/infra/vm-sync-remote.sh
TOKEN=fixture0ghtoken0123456789abcdefABCDEF01
TOKEN2=fixture0ghtoken0second0123456789ABCDEF

# h SUBCOMMAND ARGS...: run the helper as the user (stdin from $T/stdin, empty unless set).
h() {
  [ -f "$T/stdin" ] || : >"$T/stdin"
  HOME=$T_HOME bash "$HELPER" "$@" <"$T/stdin" >"$T/out" 2>"$T/err"
  echo $?
}
# hgh TOKEN: the gh subcommand with TOKEN on stdin (printed as is, a trailing newline is added).
hgh() { printf '%s\n' "$1" >"$T/stdin"; h gh; }
MANIFEST() { echo "$T_HOME/.local/state/dotfiles/vm-sync/manifest"; }
HOSTS() { echo "$T_HOME/.config/gh/hosts.yml"; }
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
# wcstamp NAME: the writable-copy record the Home Manager activation keeps for a file of ~/.omp/plugins.
wcstamp() { echo "$T_HOME/.local/state/dotfiles/writable-copy/${T_HOME//\//_}_.omp_plugins_$1"; }
# mkplugins: what the plugin sync leaves: manifests, node_modules, records, the install stamp.
mkplugins() {
  mkdir -p "$T_HOME/.omp/plugins/node_modules/some-plugin" "$T_HOME/.local/state/dotfiles/writable-copy"
  printf '{}' >"$T_HOME/.omp/plugins/package.json"
  printf '{}' >"$T_HOME/.omp/plugins/bun.lock"
  printf '{}' >"$T_HOME/.omp/plugins/omp-plugins.lock.json"
  printf 'x' >"$T_HOME/.omp/plugins/node_modules/some-plugin/index.js"
  printf 'h1' >"$(wcstamp package.json)"
  printf 'h2' >"$(wcstamp bun.lock)"
  printf 'h3' >"$(wcstamp omp-plugins.lock.json)"
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

# ---- gh

test_gh_writes_the_login_for_gh_and_git() {
  assert_rc "gh" "$(hgh "$TOKEN")" 0
  assert_bytes "hosts.yml content" "$(HOSTS)" "github.com:
    oauth_token: $TOKEN
    git_protocol: https
"
  assert_eq "hosts.yml is 600" 600 "$(tl_mode "$(HOSTS)")"
  assert_eq "its directory is 700" 700 "$(tl_mode "$T_HOME/.config/gh")"
  assert_has "manifest lists the file" "$(MANIFEST)" "file .config/gh/hosts.yml"
  assert_has "manifest lists the directory it made" "$(MANIFEST)" "dir .config/gh"
  assert_lacks "the token is not in stdout" "$T/out" "$TOKEN"
  assert_lacks "the token is not in stderr" "$T/err" "$TOKEN"
  assert_lacks "the token is not in the manifest" "$(MANIFEST)" "$TOKEN"
}

test_gh_accepts_the_token_without_a_trailing_newline() {
  printf '%s' "$TOKEN" >"$T/stdin"
  assert_rc "gh" "$(h gh)" 0
  assert_has "token written" "$(HOSTS)" "oauth_token: $TOKEN"
}

test_gh_rejects_a_token_of_a_wrong_shape_and_writes_nothing() {
  local bad
  for bad in 'short' 'has space in it 0123456789abcdef' 'quote"0123456789abcdefghijklmnop' "colon:0123456789abcdefghijklmnop" 'dollar$0123456789abcdefghijklmnop' ''; do
    printf '%s\n' "$bad" >"$T/stdin"
    assert_rc "bad token" "$(h gh)" 1
    assert_absent "no hosts.yml for: $bad" "$(HOSTS)"
    assert_lacks "stderr hides the value" "$T/err" "0123456789abcdefghijklmnop"
  done
  printf '%s\n%s\n' "$TOKEN" "$TOKEN2" >"$T/stdin"
  assert_rc "two lines, both well formed" "$(h gh)" 1
  assert_absent "no hosts.yml" "$(HOSTS)"
  assert_absent "no manifest" "$(MANIFEST)"
}

test_gh_overwrites_its_own_file_when_the_token_changes() {
  assert_rc "first" "$(hgh "$TOKEN")" 0
  assert_rc "second" "$(hgh "$TOKEN2")" 0
  assert_has "new token" "$(HOSTS)" "oauth_token: $TOKEN2"
  assert_lacks "old token is gone" "$(HOSTS)" "$TOKEN"
  assert_absent "no backup of our own file" "$(HOSTS).dotfiles-backup"
  assert_eq "listed once" 1 "$(grep -cx 'file .config/gh/hosts.yml' "$(MANIFEST)")"
}

test_gh_keeps_a_login_the_user_made_as_a_backup_and_unsync_restores_it() {
  mkdir -p "$T_HOME/.config/gh"
  printf 'github.com:\n    oauth_token: usermade\n' >"$(HOSTS)"
  chmod 600 "$(HOSTS)"
  assert_rc "gh" "$(hgh "$TOKEN")" 0
  assert_has "the new login" "$(HOSTS)" "oauth_token: $TOKEN"
  assert_has "the user's login is kept" "$(HOSTS).dotfiles-backup" "usermade"
  assert_eq "backup is 600" 600 "$(tl_mode "$(HOSTS).dotfiles-backup")"
  assert_has "says so" "$T/out" "dotfiles-backup"
  assert_rc "again" "$(hgh "$TOKEN2")" 0
  assert_has "the backup is still the user's" "$(HOSTS).dotfiles-backup" "usermade"
  assert_rc "unsync" "$(h unsync)" 0
  assert_has "the user's login is back" "$(HOSTS)" "usermade"
  assert_absent "no backup left" "$(HOSTS).dotfiles-backup"
  assert_absent "no manifest left" "$(MANIFEST)"
}

test_gh_replaces_a_link_and_unsync_puts_it_back() {
  mkdir -p "$T_HOME/.config/gh"
  printf 'target' >"$T/target"
  ln -s "$T/target" "$(HOSTS)"
  assert_rc "gh" "$(hgh "$TOKEN")" 0
  assert_eq "a regular file now" "" "$(find "$(HOSTS)" -type l)"
  assert_eq "the link's target is untouched" target "$(cat "$T/target")"
  assert_rc "unsync" "$(h unsync)" 0
  assert_eq "the link is back" "$T/target" "$(readlink "$(HOSTS)")"
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
  assert_rc "gh" "$(hgh "$TOKEN")" 0
  assert_rc "prepare" "$(h skills-prepare alpha beta)" 0
  mkdir -p "$(SKILLS)/alpha" "$(SKILLS)/beta"
  printf 'a' >"$(SKILLS)/alpha/SKILL.md"
  mkplugins
  assert_rc "unsync" "$(h unsync)" 0
  # Every file, with its mode and content hash, is as it was before the sync: the ones the user has
  # are untouched and none of the synced ones is left. (Directories of the activation may remain.)
  after=$(snapshot "$T_HOME" | grep ' F ')
  assert_eq "the set of files, modes and contents" "$before" "$after"
  assert_eq "no gh directory is left" "" "$(ls -A "$T_HOME/.config" | grep -x gh)"
}

test_unsync_removes_the_plugin_install_and_its_records() {
  mkhome
  mkplugins
  assert_rc "unsync" "$(h unsync)" 0
  assert_absent "plugins home" "$T_HOME/.omp/plugins"
  assert_absent "install stamp" "$T_HOME/.local/state/dotfiles/omp-plugins.stamp"
  assert_absent "record of package.json" "$(wcstamp package.json)"
  assert_absent "record of bun.lock" "$(wcstamp bun.lock)"
  assert_absent "record of the lock file" "$(wcstamp omp-plugins.lock.json)"
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
  printf 'h1' >"$(wcstamp package.json)"
  assert_rc "unsync" "$(h unsync)" 0
  assert_eq "the link's target is untouched" keep "$(cat "$T/elsewhere/f")"
}

test_unsync_does_not_follow_a_link_above_a_recorded_path() {
  mkdir -p "$T/elsewhere/gh" "$T/elsewhere/skills/alpha" "$T_HOME/.config" "$T_HOME/.omp/agent" "$T_HOME/.local/state/dotfiles/vm-sync"
  printf 'keep' >"$T/elsewhere/gh/hosts.yml"
  printf 'keep' >"$T/elsewhere/skills/alpha/SKILL.md"
  ln -s "$T/elsewhere/gh" "$T_HOME/.config/gh"
  ln -s "$T/elsewhere/skills" "$T_HOME/.omp/agent/skills"
  printf 'file .config/gh/hosts.yml\nskill alpha\n' >"$(MANIFEST)"
  assert_rc "unsync" "$(h unsync)" 1
  assert_eq "the file behind the linked directory stays" keep "$(cat "$T/elsewhere/gh/hosts.yml")"
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

test_unsync_with_nothing_to_remove_succeeds_and_twice_is_the_same() {
  mkhome
  local before
  before=$(snapshot "$T_HOME")
  assert_rc "nothing placed" "$(h unsync)" 0
  assert_has "says so" "$T/out" "nothing"
  assert_eq "nothing changed" "$before" "$(snapshot "$T_HOME")"
  assert_rc "gh" "$(hgh "$TOKEN")" 0
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
