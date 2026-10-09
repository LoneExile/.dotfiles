#!/usr/bin/env bash
# Guards the roles: the clean guest (proxmox-guest) must stay clean, and the agent (proxmox-agent)
# must stay confined and carry its sync pieces (gh credential helper, plugin install, harper, rsync,
# /etc/dotfiles-agent-sync.json) only while the dotfiles.agent.sync options are on. One `nix eval` of
# the configurations, then plain assertions. No VM, no vault, no network beyond what evaluating the
# flake needs. Run it from anywhere: roles-check.sh [flake-dir].
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
      harper = builtins.any (p: (p.pname or "") == "harper") cfg.environment.systemPackages;
      # rsync is not a role signal: the clean guest has it too (the module still names it for the skills sync).
      syncFile = if cfg.environment.etc ? "dotfiles-agent-sync.json" then builtins.fromJSON cfg.environment.etc."dotfiles-agent-sync.json".text else null;
      userSync =
        if cfg ? home-manager && cfg.home-manager.users ? lex
        then let u = cfg.home-manager.users.lex; in {
          service = u.systemd.user.services ? omp-plugins-install;
          activation = u.home.activation ? ompPlugins;
          helper = u.programs.git.settings.credential."https://github.com".helper or null;
          before = u.home.activation.ompPlugins.before or null;
          execStart = u.systemd.user.services.omp-plugins-install.Service.ExecStart or null;
          wantedBy = u.systemd.user.services.omp-plugins-install.Install.WantedBy or null;
          restart = u.systemd.user.services.omp-plugins-install.Service.Restart or null;
        }
        else null;
    };
    syncOff = { dotfiles.agent.sync = { gh = false; plugins = false; skills = false; }; };
  in {
    guest = summary c.proxmox-guest.config;
    agent = summary c.proxmox-agent.config;
    agentOff = summary (c.proxmox-agent.extendModules { modules = [ syncOff ]; }).config;
  }
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
check "clean: none of the sync (no harper, no sync file, no user wiring)" '(.guest | [.harper, (.syncFile != null), (.userSync != null)] | any) | not'
check "agent: the sync options are on by default" '.agent.syncFile == {"gh": true, "plugins": true, "skills": true}'
check "agent: harper (harper-cli) is installed" '.agent.harper'
check "agent: plugin install service and activation, gh as git credential helper" '.agent.userSync.service and .agent.userSync.activation and (.agent.userSync.helper | test("^!/nix/store/[^ ]+/bin/gh auth git-credential$"))'
check "agent: the manifests are placed before the user units reload, and the unit carries the hash of the captured files" '.agent.userSync.before == ["reloadSystemd"] and ([.agent.userSync.execStart] | flatten | map(test(" [0-9a-f]{64}$")) | any)'
check "agent: the plugin install unit starts with the user manager at boot and is retried on failure" '.agent.userSync.wantedBy == ["default.target"] and .agent.userSync.restart == "on-failure"'
check "agent with every sync option off: no harper, no service, no activation, no helper" '.agentOff | (.syncFile == {"gh": false, "plugins": false, "skills": false}) and ([.harper, .userSync.service, .userSync.activation] | any | not) and (.userSync.helper == null)'
exit "$fail"
