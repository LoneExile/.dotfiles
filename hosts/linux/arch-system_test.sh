#!/usr/bin/env bash
# Tests for hosts/linux/arch-system.sh: a non-NixOS Arch host's packages and root settings as code. Every command
# it runs is a stub (bin/<name> -> stub) that keeps its state in files under $T/st and logs each call that would
# change the host to $T/st/calls; /etc and /var live under ARCH_SYSTEM_ROOT=$T/root.
set -uo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
# shellcheck source=../../home/secretspec/testlib.sh
. "$ROOT/home/secretspec/testlib.sh" || exit 1

write_stub() {
  cat >"$T/stub" <<'STUB'
#!/usr/bin/env bash
S=${STUB_STATE:?}
name=$(basename "$0")
log() { printf '%s %s\n' "$name" "$*" >>"$S/calls"; }
# setu FILE UNIT ENABLED ACTIVE
setu() { { grep -v "^$2 " "$1" 2>/dev/null; echo "$2 $3 $4"; } >"$1.new"; mv "$1.new" "$1"; }
case $name in
  id) case ${1:-} in -u) cat "$S/uid" ;; -un) echo rex ;; esac ;;
  sudo)
    while [[ ${1:-} == -* ]]; do
      case $1 in -v) exit 0 ;; -p) shift ;; esac
      shift
    done
    [ $# -eq 0 ] || exec "$@" ;;
  systemctl)
    u=""
    if [ "$1" = --user ]; then u=u; shift; fi
    f=$S/${u}units cmd=$1
    shift
    case $cmd in
      is-enabled) st=$(awk -v n="$1" '$1==n{print $2}' "$f"); echo "${st:-disabled}"; [ "$st" = enabled ] ;;
      is-active) [ "$1" = -q ] && shift; [ "$(awk -v n="$1" '$1==n{print $3}' "$f")" = active ] ;;
      enable) [ "$1" = --now ] && shift; for x; do setu "$f" "$x" enabled active; done; log "$u enable $*" ;;
      disable) [ "$1" = --now ] && shift; for x; do setu "$f" "$x" disabled inactive; done; log "$u disable $*" ;;
      *) log "$cmd $*" ;;
    esac ;;
  loginctl) : >"$ARCH_SYSTEM_ROOT/var/lib/systemd/linger/$2"; log "$*" ;;
  getent) echo "$2:x:1000:1000::$STUB_HOME:$(cat "$S/shell")" ;;
  chsh) echo "$2" >"$S/shell"; log "$*" ;;
  nmcli) if [ "$1" = -g ]; then cat "$S/wol"; else echo "${*: -1}" >"$S/wol"; log "$*"; fi ;;
  ufw)
    case $1 in
      show) echo "Added user rules (see 'ufw status' for running firewall):"; cat "$S/ufw" ;;
      status) cat "$S/ufwstatus" ;;
      allow) echo "ufw allow from $5 to any port $9 proto $3 comment '${11}'" >>"$S/ufw"; log "$*" ;;
    esac ;;
  sshd) exit "$(cat "$S/sshd_rc" 2>/dev/null || echo 0)" ;;
  findmnt) cat "$S/nixsrc" ;;
  pacman)
    case $1 in
      -Qq) grep -qx "$2" "$S/pkgs" ;;
      -Qqe) cat "$S/explicit" ;;
      -T) shift; rc=0; for d; do grep -qx "${d%%[<>=]*}" "$S/pkgs" || { echo "$d"; rc=127; }; done; exit $rc ;;
      -S)
        shift; dep=""; ps=()
        for a; do case $a in --asdeps) dep=1 ;; -*) ;; *) ps+=("$a") ;; esac; done
        for p in "${ps[@]}"; do echo "$p" >>"$S/pkgs"; [ -n "$dep" ] || echo "$p" >>"$S/explicit"; done
        log "-S ${dep:+--asdeps }${ps[*]}" ;;
      -U)
        shift
        for a; do case $a in -*) ;; *) n=$(basename "$a"); n=${n%-1-1-x86_64.pkg.tar.zst}; echo "$n" >>"$S/pkgs"; echo "$n" >>"$S/explicit"; log "-U $n" ;; esac; done ;;
    esac ;;
  git)
    if [ "$1" = clone ]; then d=${*: -1}; mkdir -p "$d/.git"; cp "$S/aur/$(basename "$d")/"* "$d/"; log "clone $(basename "$d")"; fi ;;
  makepkg)
    p=$(basename "$PWD")
    case ${1:-} in
      --printsrcinfo) cat SRCINFO ;;
      --packagelist) echo "$PWD/$p-1-1-x86_64.pkg.tar.zst"; echo "$PWD/$p-debug-1-1-x86_64.pkg.tar.zst" ;;
      *) : >"$p-1-1-x86_64.pkg.tar.zst"; : >"$p-debug-1-1-x86_64.pkg.tar.zst"; log "build $p" ;;
    esac ;;
esac
STUB
  chmod +x "$T/stub"
}

# world: a host whose settings all differ from system.conf (the test copy below), and whose packages miss one repo
# package (sunshine) and one AUR package (zen-bin, depending on gtk3, which is missing, and glibc).
world() {
  S=$T/st R=$T/root
  mkdir -p "$S/aur/zen-bin" "$R/etc/nix" "$R/etc/ssh/sshd_config.d" "$R/etc/greetd" "$R/var/lib/systemd/linger" \
    "$T/bin" "$T/host" "$T_HOME/.config/dotfiles"
  write_stub
  for c in id sudo systemctl loginctl getent chsh nmcli ufw sshd findmnt pacman git makepkg; do ln -s "$T/stub" "$T/bin/$c"; done
  printf 'nix\n# the stream host\nsunshine\n' >"$T/host/pacman.txt"
  printf '# notes\nzen-bin\n' >"$T/host/aur.txt"
  printf '# base\nbase\nfirefox\n' >"$T/host/cachyos-base.txt"
  cat >"$T/host/system.conf" <<'CONF'
SYSTEM_UNITS=(nix-daemon.socket paccache.timer)
SYSTEM_UNITS_OFF=(warp-svc.service)
USER_UNITS=(sunshine.service syncthing.service)
LINGER=yes
LOGIN_SHELL=/usr/bin/zsh
SSHD_KEYS_ONLY=yes
NIX_CONF=("experimental-features = nix-command flakes" "substituters = https://a https://b")
GREETD_AUTOLOGIN="uwsm start hyprland.desktop"
WOL_CONNECTION="Wired connection 1"
UFW_RULES=("tcp 47984,47989 sunshine" "udp 8376 tern")
CONF
  echo 'UFW_SUBNETS="10.1.0.0/24 10.2.0.0/24"' >"$T_HOME/.config/dotfiles/arch-system.env"
  printf 'nix-daemon.socket enabled active\npaccache.timer disabled inactive\nwarp-svc.service enabled active\nsshd.service enabled active\n' >"$S/units"
  printf 'sunshine.service enabled active\n' >"$S/uunits"
  printf 'base\nfirefox\nnix\nglibc\n' >"$S/pkgs"
  printf 'base\nfirefox\nnix\n' >"$S/explicit"
  echo /bin/bash >"$S/shell"
  echo default >"$S/wol"
  echo "ufw allow from 10.1.0.0/24 to any port 47984,47989 proto tcp" >"$S/ufw"
  echo "Status: active" >"$S/ufwstatus"
  echo "/dev/x[/@nix]" >"$S/nixsrc"
  echo 0 >"$S/uid"
  : >"$S/calls"
  printf '# managed elsewhere\nbuild-users-group = nixbld\nsubstituters = https://old\n' >"$R/etc/nix/nix.conf"
  cat >"$R/etc/greetd/config.toml" <<'TOML'
[terminal]
vt = 1

[default_session]
command = "/usr/bin/greeter"
user = "greeter"

# an old note about autologin
[initial_session]
command = "old"
user = "rex"
TOML
  printf 'pkgname = zen-bin\n\tdepends = gtk3\n\tdepends = glibc>=2.28\n\tmakedepends = git\n' >"$S/aur/zen-bin/SRCINFO"
  echo git >>"$S/pkgs"
}

# arch MODE [ARGS...]: run the script with the stubs first on PATH, stdin not a terminal (as from an agent);
# stdout and stderr land in $T/out and $T/err; prints the exit status.
arch() {
  (
    export PATH="$T/bin:$PATH" STUB_STATE="$T/st" STUB_HOME="$T_HOME" ARCH_SYSTEM_ROOT="$T/root" HOME="$T_HOME" \
      XDG_CACHE_HOME="$T/cache"
    bash "$ROOT/hosts/linux/arch-system.sh" "$@"
  ) >"$T/out" 2>"$T/err" </dev/null
  echo $?
}
sys() { arch system "$@" "$T/host" rex; }
fsum() { cat "$T/root/etc/nix/nix.conf" "$T/root/etc/greetd/config.toml" "$T/root/etc/ssh/sshd_config.d/"* 2>/dev/null | shasum | cut -c1-40; }
calls() { cat "$T/st/calls"; }

test_a_drifted_system_is_fixed_then_left_alone() {
  world
  assert_rc "apply" "$(sys)" 0
  assert_has "paccache.timer enabled and started" "$T/st/calls" "systemctl  enable paccache.timer"
  assert_lacks "nix-daemon.socket left alone" "$T/st/calls" "enable nix-daemon.socket"
  assert_has "warp-svc disabled and stopped" "$T/st/calls" "systemctl  disable warp-svc.service"
  assert_has "linger" "$T/st/calls" "loginctl enable-linger rex"
  assert_eq "login shell" "/usr/bin/zsh" "$(cat "$T/st/shell")"
  assert_eq "Wake-on-LAN" "magic" "$(cat "$T/st/wol")"
  assert_eq "ufw: the 3 missing rules added, the existing one not again" "3" "$(grep -c '^ufw allow' "$T/st/calls")"
  assert_has "ufw: a missing rule carries its comment" "$T/st/calls" "ufw allow proto udp from 10.2.0.0/24 to any port 8376 comment tern"
  assert_has "sshd: keys only" "$T/root/etc/ssh/sshd_config.d/10-keys-only.conf" "PasswordAuthentication no"
  assert_has "sshd reloaded" "$T/st/calls" "systemctl reload sshd.service"
  assert_eq "nix.conf: substituters replaced in place, not added twice" "1" "$(grep -c '^substituters' "$T/root/etc/nix/nix.conf")"
  assert_has "nix.conf: the new value" "$T/root/etc/nix/nix.conf" "substituters = https://a https://b"
  assert_has "nix.conf: other lines kept" "$T/root/etc/nix/nix.conf" "build-users-group = nixbld"
  assert_eq "nix.conf: order kept" "build-users-group = nixbld" "$(sed -n 2p "$T/root/etc/nix/nix.conf")"
  assert_has "nix.conf: missing key appended" "$T/root/etc/nix/nix.conf" "experimental-features = nix-command flakes"
  assert_has "nix daemon restarted" "$T/st/calls" "systemctl try-restart nix-daemon.service"
  assert_eq "greetd: one [initial_session]" "1" "$(grep -c '^\[initial_session\]' "$T/root/etc/greetd/config.toml")"
  assert_has "greetd: the command" "$T/root/etc/greetd/config.toml" 'command = "uwsm start hyprland.desktop"'
  assert_lacks "greetd: the old note above it is gone" "$T/root/etc/greetd/config.toml" "an old note"
  assert_has "greetd: the greeter untouched" "$T/root/etc/greetd/config.toml" 'command = "/usr/bin/greeter"'
  local before sum
  before=$(calls) sum=$(fsum)
  assert_rc "apply again" "$(sys)" 0
  assert_eq "second run changes nothing" "$before" "$(calls)"
  assert_eq "second run rewrites no file" "$sum" "$(fsum)"
  assert_eq "second run prints only ok lines" "" "$(grep -v '^ok: ' "$T/out")"
}

test_check_reports_drift_and_changes_nothing() {
  world
  local sum
  sum=$(fsum)
  assert_rc "check on a drifted host" "$(sys --check)" 1
  for what in "paccache.timer" "warp-svc.service" "linger" "login shell" "Wake-on-LAN" "ufw" "sshd" "nix.conf" "greetd"; do
    assert_has "drift reported: $what" "$T/out" "$what"
  done
  assert_eq "no change made" "" "$(calls)"
  assert_eq "no file written" "$sum" "$(fsum)"
  assert_rc "apply" "$(sys)" 0
  assert_rc "check after apply" "$(sys --check)" 0
}

test_a_rejected_sshd_dropin_is_rolled_back() {
  world
  printf 'old drop-in\n' >"$T/root/etc/ssh/sshd_config.d/10-keys-only.conf"
  echo 1 >"$T/st/sshd_rc"
  assert_rc "apply" "$(sys)" 1
  assert_eq "the old drop-in is back" "old drop-in" "$(cat "$T/root/etc/ssh/sshd_config.d/10-keys-only.conf")"
  assert_lacks "sshd not reloaded" "$T/st/calls" "reload sshd"
  assert_has "the error says why" "$T/err" "sshd -t"
}

test_without_subnets_ufw_is_skipped_and_the_run_fails() {
  world
  rm "$T_HOME/.config/dotfiles/arch-system.env"
  assert_rc "apply" "$(sys)" 1
  assert_has "says what is missing" "$T/out" "UFW_SUBNETS"
  assert_lacks "no ufw rule added" "$T/st/calls" "ufw allow"
  assert_has "the other steps still ran" "$T/st/calls" "loginctl enable-linger rex"
}

test_a_missing_nix_subvolume_is_reported_not_created() {
  world
  echo "/dev/x[/@]" >"$T/st/nixsrc"
  assert_rc "apply" "$(sys)" 1
  assert_has "reported as a manual step" "$T/out" "manual: /nix"
}

test_system_mode_refuses_a_non_root_user() {
  world
  echo 1000 >"$T/st/uid"
  assert_rc "apply as a user" "$(sys)" 1
  assert_eq "no change made" "" "$(calls)"
}

test_packages_installs_only_what_is_missing() {
  world
  echo 1000 >"$T/st/uid"
  assert_rc "apply" "$(arch packages "$T/host")" 0
  assert_has "the missing repo package" "$T/st/calls" "pacman -S sunshine"
  assert_has "the AUR package's missing repo dependency, as a dependency" "$T/st/calls" "pacman -S --asdeps gtk3"
  assert_lacks "a present dependency not reinstalled" "$T/st/calls" "glibc"
  assert_has "built as the user" "$T/st/calls" "makepkg build zen-bin"
  assert_has "the package installed" "$T/st/calls" "pacman -U zen-bin"
  assert_lacks "not its debug package" "$T/st/calls" "zen-bin-debug"
  local before
  before=$(calls)
  assert_rc "apply again" "$(arch packages "$T/host")" 0
  assert_eq "second run changes nothing" "$before" "$(calls)"
  assert_rc "check after apply" "$(arch packages --check "$T/host")" 0
}

test_packages_check_reports_missing_and_unlisted() {
  world
  echo 1000 >"$T/st/uid"
  echo brave-bin >>"$T/st/explicit"
  assert_rc "check" "$(arch packages --check "$T/host")" 1
  assert_has "a missing repo package" "$T/out" "drift: missing from pacman: sunshine"
  assert_has "a missing AUR package" "$T/out" "drift: missing from the AUR: zen-bin"
  assert_has "an unlisted package" "$T/out" "drift: unlisted: brave-bin"
  assert_lacks "the base is not unlisted" "$T/out" "unlisted: firefox"
  assert_eq "no change made" "" "$(calls)"
}

test_packages_refuses_root() {
  world
  assert_rc "apply as root" "$(arch packages "$T/host")" 1
  assert_has "says why" "$T/err" "not as root"
  assert_eq "no change made" "" "$(calls)"
}

test_user_mode_enables_missing_user_units() {
  world
  echo 1000 >"$T/st/uid"
  assert_rc "check" "$(arch user --check "$T/host")" 1
  assert_has "the missing unit reported" "$T/out" "drift: user unit syncthing.service"
  assert_rc "apply" "$(arch user "$T/host")" 0
  assert_has "enabled and started" "$T/st/calls" "systemctl u enable syncthing.service"
  assert_lacks "the running one left alone" "$T/st/calls" "enable sunshine.service"
  assert_rc "check after apply" "$(arch user --check "$T/host")" 0
}

tl_init_pure
tl_run_all
tl_done
