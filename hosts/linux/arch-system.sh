#!/usr/bin/env bash
# arch-system.sh MODE [--check] HOSTDIR [USER]: the packages and root settings of a non-NixOS Arch host (CachyOS),
# from HOSTDIR (hosts/linux/<host>/; README: Non-NixOS Linux hosts). The justfile's arch-* recipes run it.
#   packages  as the user: install what HOSTDIR/pacman.txt and aur.txt list and the host lacks. An AUR package is
#             built with makepkg as the user (its repo dependencies installed first, as dependencies) and installed
#             with pacman -U. Explicit packages that no list names (cachyos-base.txt included) are reported.
#   system    as root, for USER: the settings of HOSTDIR/system.conf (units, linger, login shell, sshd keys only,
#             nix.conf, ufw, greetd autologin, Wake-on-LAN), and a check that /nix is its own Btrfs subvolume.
#   user      as the user: the user units of HOSTDIR/system.conf.
# Each step checks first and changes only what differs, printing "ok:" or "changed:". With --check nothing changes:
# it prints "drift:" lines and exits 1 when anything differs. Nothing is ever uninstalled or removed. The LAN
# subnets for ufw are server values, not in the repo: UFW_SUBNETS in ~USER/.config/dotfiles/arch-system.env.
# ARCH_SYSTEM_ROOT prefixes /etc and /var (the tests).
set -euo pipefail

mode=${1:-}
shift || true
check=0
if [ "${1:-}" = --check ]; then
  check=1
  shift
fi
hostdir=${1:-}
R=${ARCH_SYSTEM_ROOT:-}
problems=0

die() {
  echo "arch-system: $*" >&2
  exit 1
}
ok() { echo "ok: $*"; }
# act WHAT CMD...: run CMD and print "changed: WHAT"; with --check print "drift: WHAT" instead.
act() {
  local what=$1
  shift
  if [ "$check" = 1 ]; then
    echo "drift: $what"
    problems=1
  else
    "$@"
    echo "changed: $what"
  fi
}
# list FILE: the package names of a list (first word of each line; # comments and blank lines skipped).
list() { [ -f "$1" ] && awk '{sub(/#.*/, "")} NF {print $1}' "$1"; }

[ -n "$hostdir" ] && [ -d "$hostdir" ] || die "usage: arch-system.sh packages|system|user [--check] HOSTDIR [USER]"

# ---- packages -------------------------------------------------------------------------------------------------

sudo_ready=0
# as_root CMD...: CMD through sudo, asking for the password once (from the terminal, or stdin when there is none).
# Called from this shell, not a subshell, so the sudo credential of the first call is reused; aur_install keeps it
# fresh while a build runs, as a source build can outlast sudo's cache (5 minutes by default).
as_root() {
  if [ "$sudo_ready" = 0 ]; then
    if [ -t 0 ]; then sudo -v; else sudo -S -p '' -v; fi
    sudo_ready=1
  fi
  sudo "$@"
}

aur_install() {
  local p=$1 dir deps need files bp t=0 every=${ARCH_SYSTEM_SUDO_REFRESH:-60}
  dir=${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles/aur/$p
  if [ -d "$dir/.git" ]; then
    git -C "$dir" pull -q --ff-only
  else
    mkdir -p "$(dirname "$dir")"
    git clone -q "https://aur.archlinux.org/$p.git" "$dir"
  fi
  # Not makepkg -s: its own sudo would ask for the password again.
  mapfile -t deps < <(cd "$dir" && makepkg --printsrcinfo |
    awk -F' = ' '/^\t(make|check)?depends(_x86_64)? = /{print $2}' | LC_ALL=C sort -u)
  need=()
  if [ "${#deps[@]}" -gt 0 ]; then
    mapfile -t need < <(pacman -T "${deps[@]}" || true)
  fi
  if [ "${#need[@]}" -gt 0 ]; then
    as_root pacman -S --needed --noconfirm --asdeps "${need[@]%%[<>=]*}" ||
      die "$p: a dependency is not in the repos (an AUR one?): ${need[*]}"
  fi
  # The build runs in the background while this shell refreshes the credential (`sudo -n -v`: the same shell, so the
  # same timestamp record; never a prompt), so the pacman -U after a long build needs no second password. --clean
  # drops src/ and pkg/ after a good build (gigabytes for a Rust build); the sources and the package file stay.
  (cd "$dir" && makepkg --noconfirm --force --cleanbuild --clean) >"$dir/build.log" 2>&1 &
  bp=$!
  while kill -0 "$bp" 2>/dev/null; do
    if [ "$sudo_ready" = 1 ] && [ $((t % every)) = 0 ]; then sudo -n -v 2>/dev/null || :; fi
    sleep 1
    t=$((t + 1))
  done
  wait "$bp" || die "$p: makepkg failed (log: $dir/build.log)"
  mapfile -t files < <(cd "$dir" && makepkg --packagelist | grep -v -- '-debug-')
  as_root pacman -U --noconfirm "${files[@]}"
}

packages() {
  [ "$(id -u)" != 0 ] || die "packages: run as the user, not as root (makepkg refuses root; pacman goes through sudo)"
  local p missing=() want=() aur=() known
  mapfile -t want < <(list "$hostdir/pacman.txt")
  mapfile -t aur < <(list "$hostdir/aur.txt")
  for p in "${want[@]}"; do pacman -Qq "$p" >/dev/null 2>&1 || missing+=("$p"); done
  if [ "${#missing[@]}" -eq 0 ]; then
    ok "pacman: ${#want[@]} packages"
  else
    act "missing from pacman: ${missing[*]}" as_root pacman -S --needed --noconfirm "${missing[@]}"
  fi
  for p in "${aur[@]}"; do
    if pacman -Qq "$p" >/dev/null 2>&1; then ok "AUR: $p"; else act "missing from the AUR: $p" aur_install "$p"; fi
  done
  known=$({ list "$hostdir/cachyos-base.txt"; printf '%s\n' "${want[@]}" "${aur[@]}"; } | LC_ALL=C sort -u)
  while read -r p; do
    [ -n "$p" ] || continue
    if [ "$check" = 1 ]; then
      echo "drift: unlisted: $p (add it to pacman.txt or aur.txt)"
      problems=1
    else
      echo "note: unlisted: $p (add it to pacman.txt or aur.txt)"
    fi
  done < <(LC_ALL=C comm -23 <(pacman -Qqe | LC_ALL=C sort -u) <(echo "$known"))
}

# ---- system ---------------------------------------------------------------------------------------------------

# rewrite FILE NEWFILE WHAT: replace FILE with NEWFILE when they differ (a backup of FILE first), else ok. Returns
# 0 when it changed FILE, 1 when it did not.
rewrite() {
  local f=$1 new=$2 what=$3
  if [ -f "$f" ] && cmp -s "$f" "$new"; then
    ok "$what"
    return 1
  fi
  if [ "$check" = 1 ]; then
    echo "drift: $what"
    problems=1
    return 1
  fi
  if [ -f "$f" ]; then cp -p "$f" "$f.dotfiles-backup"; fi
  mkdir -p "$(dirname "$f")"
  cat "$new" >"$f"
  echo "changed: $what"
}

# unit_on UNIT [--user LABEL]: enabled and running.
unit_on() {
  local u=$1 label=${3:-unit} scope=()
  if [ -n "${2:-}" ]; then scope=("$2"); fi
  if [ "$(systemctl "${scope[@]}" is-enabled "$u" 2>/dev/null)" = enabled ] && systemctl "${scope[@]}" is-active -q "$u"; then
    ok "$label $u"
  else
    act "$label $u (enable and start)" systemctl "${scope[@]}" enable --now "$u"
  fi
}

unit_off() {
  local u=$1
  if [ "$(systemctl is-enabled "$u" 2>/dev/null)" = enabled ] || systemctl is-active -q "$u"; then
    act "unit $u (disable and stop)" systemctl disable --now "$u"
  else
    ok "unit $u off"
  fi
}

# nix.conf: each "key = value" replaces the line of that key in place (later duplicates dropped), or is appended.
nix_conf() {
  local f=$R/etc/nix/nix.conf src new
  src=$f
  [ -f "$src" ] || src=/dev/null
  new=$(mktemp)
  printf '%s\n' "${NIX_CONF[@]}" >"$new.want"
  awk -v want="$new.want" '
    BEGIN { while ((getline l < want) > 0) { k = l; sub(/[ \t]*=.*/, "", k); W[k] = l; order[++n] = k } }
    { k = $0; sub(/^[ \t]+/, "", k)
      if (k !~ /^#/ && k != "") { sub(/[ \t]*=.*/, "", k)
        if (k in W) { if (!(k in done)) { print W[k]; done[k] = 1 }; next } }
      print }
    END { for (i = 1; i <= n; i++) if (!(order[i] in done)) print W[order[i]] }' "$src" >"$new"
  if rewrite "$f" "$new" "nix.conf"; then systemctl try-restart nix-daemon.service; fi
  rm -f "$new" "$new.want"
}

sshd_keys_only() {
  local f=$R/etc/ssh/sshd_config.d/10-keys-only.conf new had=0
  new=$(mktemp)
  cat >"$new" <<'EOF'
# Keys only: the dotfiles (hosts/linux/arch-system.sh, system.conf SSHD_KEYS_ONLY). Read before 20-* and 99-*, and
# sshd keeps the first value it reads.
PasswordAuthentication no
EOF
  if [ -f "$f" ]; then had=1; fi
  if rewrite "$f" "$new" "sshd keys only"; then
    if ! sshd -t; then
      if [ "$had" = 1 ]; then mv -f "$f.dotfiles-backup" "$f"; else rm -f "$f"; fi
      rm -f "$new"
      die "sshd -t rejected the new drop-in; the old one is back"
    fi
    if systemctl is-active -q sshd.service; then systemctl reload sshd.service; fi
  fi
  rm -f "$new"
}

# greetd: the [initial_session] section, with the comment lines right above it, is the dotfiles' own block.
greetd() {
  local f=$R/etc/greetd/config.toml new cmd
  if [ ! -f "$f" ]; then
    echo "skip: greetd (no $f)"
    problems=1
    return
  fi
  cmd=${GREETD_AUTOLOGIN//\\/\\\\}
  cmd=${cmd//\"/\\\"}
  new=$(mktemp)
  cat >"$new.block" <<EOF
# Autologin once per boot (greetd's runfile), so the user services start without a login at the machine. Set by
# the dotfiles: hosts/linux/arch-system.sh, GREETD_AUTOLOGIN in system.conf.
[initial_session]
command = "$cmd"
user = "$target"
EOF
  awk -v block="$new.block" '
    function flush() { for (i = 1; i <= nc; i++) print C[i]; nc = 0 }
    function put() { while ((getline l < block) > 0) print l; close(block); done = 1 }
    skip && /^[ \t]*\[/ { skip = 0; print "" }
    skip { next }
    /^[ \t]*#/ { C[++nc] = $0; next }
    /^[ \t]*\[initial_session\][ \t]*$/ { nc = 0; put(); skip = 1; next }
    { flush(); print }
    END { flush(); if (!done) { print ""; put() } }' "$f" >"$new"
  rewrite "$f" "$new" "greetd autologin" || :
  rm -f "$new" "$new.block"
}

ufw_rules() {
  local envf home s rule proto ports comment have line found l
  home=$(getent passwd "$target" | cut -d: -f6)
  envf=$home/.config/dotfiles/arch-system.env
  UFW_SUBNETS=""
  # shellcheck disable=SC1090
  if [ -f "$envf" ]; then . "$envf"; fi
  if [ -z "$UFW_SUBNETS" ]; then
    echo "skip: ufw (set UFW_SUBNETS in $envf, e.g. UFW_SUBNETS=\"<subnet> <subnet>\")"
    problems=1
    return
  fi
  # Not `ufw status | grep -q`: grep quits early, ufw gets SIGPIPE, and pipefail reads an active firewall as off.
  if [[ $(ufw status) != *"Status: active"* ]]; then
    echo "manual: ufw is not active (enable it by hand, with an SSH rule first)"
    problems=1
  fi
  have=$(ufw show added)
  for s in $UFW_SUBNETS; do
    for rule in "${UFW_RULES[@]}"; do
      read -r proto ports comment <<<"$rule"
      line="ufw allow from $s to any port $ports proto $proto"
      found=0
      while IFS= read -r l; do
        if [ "$l" = "$line" ] || [[ $l == "$line comment "* ]]; then found=1; fi
      done <<<"$have"
      if [ "$found" = 1 ]; then
        ok "ufw $proto $ports from $s"
      else
        act "ufw $proto $ports from $s ($comment)" ufw allow proto "$proto" from "$s" to any port "$ports" comment "$comment"
      fi
    done
  done
}

system_settings() {
  [ "$(id -u)" = 0 ] || die "system: run as root (just arch-system goes through sudo)"
  target=${2:-}
  [ -n "$target" ] || die "system: name the user (USER)"
  # shellcheck disable=SC1091
  . "$hostdir/system.conf"
  local u src
  for u in "${SYSTEM_UNITS[@]}"; do unit_on "$u"; done
  for u in "${SYSTEM_UNITS_OFF[@]}"; do unit_off "$u"; done
  if [ "${LINGER:-}" = yes ]; then
    if [ -e "$R/var/lib/systemd/linger/$target" ]; then ok "linger for $target"; else act "linger for $target" loginctl enable-linger "$target"; fi
  fi
  if [ -n "${LOGIN_SHELL:-}" ]; then
    if [ "$(getent passwd "$target" | cut -d: -f7)" = "$LOGIN_SHELL" ]; then ok "login shell $LOGIN_SHELL"; else act "login shell $LOGIN_SHELL" chsh -s "$LOGIN_SHELL" "$target"; fi
  fi
  if [ "${SSHD_KEYS_ONLY:-}" = yes ]; then sshd_keys_only; fi
  if [ "${#NIX_CONF[@]}" -gt 0 ]; then nix_conf; fi
  if [ -n "${GREETD_AUTOLOGIN:-}" ]; then greetd; fi
  if [ -n "${WOL_CONNECTION:-}" ]; then
    if [ "$(nmcli -g 802-3-ethernet.wake-on-lan con show "$WOL_CONNECTION")" = magic ]; then
      ok "Wake-on-LAN on $WOL_CONNECTION"
    else
      act "Wake-on-LAN on $WOL_CONNECTION (from its next activation)" nmcli con modify "$WOL_CONNECTION" 802-3-ethernet.wake-on-lan magic
    fi
  fi
  if [ "${#UFW_RULES[@]}" -gt 0 ]; then ufw_rules; fi
  src=$(findmnt -no SOURCE /nix 2>/dev/null || true)
  if [[ $src == *"[/@nix]" ]]; then
    ok "/nix is the @nix subvolume"
  else
    echo "manual: /nix is not its own Btrfs subvolume (README: One-time root steps, step 1)"
    problems=1
  fi
}

user_units() {
  [ "$(id -u)" != 0 ] || die "user: run as the user, not as root"
  # shellcheck disable=SC1091
  . "$hostdir/system.conf"
  local u
  for u in "${USER_UNITS[@]}"; do unit_on "$u" --user "user unit"; done
}

SYSTEM_UNITS=() SYSTEM_UNITS_OFF=() USER_UNITS=() NIX_CONF=() UFW_RULES=()
case $mode in
  packages) packages ;;
  system) system_settings "$@" ;;
  user) user_units ;;
  *) die "usage: arch-system.sh packages|system|user [--check] HOSTDIR [USER]" ;;
esac
exit "$problems"
