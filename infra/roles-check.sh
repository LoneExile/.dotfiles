#!/usr/bin/env bash
# Guards the roles: the clean guest (proxmox-guest) must stay clean, and the agent (proxmox-agent)
# must stay confined. One `nix eval` of both configurations, then plain assertions. No VM, no vault,
# no network beyond what evaluating the flake needs. Run it from anywhere: roles-check.sh [flake-dir].
set -uo pipefail
repo=${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}

facts=$(nix eval --json "$repo#nixosConfigurations" --apply '
  c: let
    summary = cfg: {
      tcp = cfg.networking.firewall.allowedTCPPorts;
      udp = cfg.networking.firewall.allowedUDPPorts;
      normalUsers = builtins.attrNames (builtins.removeAttrs (builtins.mapAttrs (n: u: u.isNormalUser) cfg.users.users) (builtins.filter (n: !cfg.users.users.${n}.isNormalUser) (builtins.attrNames cfg.users.users)));
      wheel = builtins.filter (n: builtins.elem "wheel" cfg.users.users.${n}.extraGroups) (builtins.attrNames cfg.users.users);
      linger = builtins.filter (n: cfg.users.users.${n}.linger == true) (builtins.attrNames cfg.users.users);
      nixLd = cfg.programs.nix-ld.enable;
      podman = cfg.virtualisation.podman.enable;
      zram = cfg.zramSwap.enable;
      omp = builtins.any (p: (p.pname or "") == "omp") cfg.environment.systemPackages;
      homeManager = builtins.hasAttr "home-manager" cfg && cfg.home-manager.users != { };
      rootLogin = cfg.services.openssh.settings.PermitRootLogin;
      passwordAuth = cfg.services.openssh.settings.PasswordAuthentication;
    };
  in { guest = summary c.proxmox-guest.config; agent = summary c.proxmox-agent.config; }
') || {
  echo "roles-check: nix eval failed" >&2
  exit 2
}

fail=0
check() { # check LABEL JQ-EXPRESSION
  if printf '%s' "$facts" | jq -e "$2" >/dev/null; then
    printf '  ok   %s\n' "$1"
  else
    printf '  FAIL %s\n' "$1"
    fail=1
  fi
}
check "clean: firewall TCP 22 only" '.guest.tcp == [22]'
check "clean: no UDP port open" '.guest.udp == []'
check "clean: no normal user" '.guest.normalUsers == []'
check "clean: no lingering user" '.guest.linger == []'
check "clean: no nix-ld, podman, zram, omp, Home Manager" '(.guest | [.nixLd, .podman, .zram, .omp, .homeManager] | any) | not'
check "agent: firewall TCP 22 and UDP 8376 only" '.agent.tcp == [22] and .agent.udp == [8376]'
check "agent: exactly one normal user, lingering, outside wheel" '(.agent.normalUsers | length) == 1 and .agent.linger == .agent.normalUsers and (.agent.wheel | length) == 0'
check "agent: nix-ld, podman, zram, omp, Home Manager on" '.agent | [.nixLd, .podman, .zram, .omp, .homeManager] | all'
check "both: root by key only, no password login" '[.guest, .agent] | all(.rootLogin == "prohibit-password" and .passwordAuth == false)'
exit "$fail"
