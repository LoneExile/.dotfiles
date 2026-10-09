#!/usr/bin/env bash
# Guards the roles: the clean guest (proxmox-guest) must stay clean, and the agent (proxmox-agent)
# must stay confined and carry its sync pieces (plugin install, harper, rsync, /etc/dotfiles-agent-sync.json,
# the Hindsight zsh side) only while the dotfiles.agent.sync options are on, and keep gh as git's credential helper with no Home Manager hand on ~/.config/gh. The agent carries the Mason language server install
# (a user service with an exact PATH, neovim on no PATH, nothing of ~/.config/nvim) only while dotfiles.agent.mason.enable is on, whatever the sync options say. Docker is rootless or absent in
# every role (no rootful daemon, no docker group, no docker socket, podman not posing as docker) and comes, with just, lazygit and lazydocker as user packages, only while
# dotfiles.agent.docker.enable and dotfiles.agent.tools.enable are on. The browser (headless Chromium behind /opt/google/chrome/chrome, no service, the sandbox on) comes only while
# dotfiles.agent.browser.enable is on. One `nix eval` of
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
      neovim = builtins.any (p: builtins.match "neovim.*" (p.pname or "") != null) cfg.environment.systemPackages;
      shellcheck = builtins.any (p: builtins.match "[Ss]hell[Cc]heck" (p.pname or "") != null) cfg.environment.systemPackages;
      # Docker: rootless or nothing. The rootful daemon, a docker group (root on the machine), a docker socket and podman posing as docker must not exist in any role.
      dockerRootful = cfg.virtualisation.docker.enable;
      dockerRootless = cfg.virtualisation.docker.rootless.enable;
      dockerSocketVar = cfg.virtualisation.docker.rootless.setSocketVariable;
      # an assertion that fails (its message): none in a role as built, one for a jumphost without Docker
      failedAssertions = map (a: a.message) (builtins.filter (a: !a.assertion) cfg.assertions);
      dockerVersion = cfg.virtualisation.docker.rootless.package.version;
      dockerVulnerabilities = cfg.virtualisation.docker.rootless.package.meta.knownVulnerabilities or [ ];
      dockerSystemPackage = builtins.any (p: (p.pname or "") == "docker") cfg.environment.systemPackages;
      dockerGroup = cfg.users.groups ? docker;
      dockerGroupMembers = cfg.users.groups.docker.members or [ ];
      dockerUsers = builtins.filter (n: builtins.elem "docker" cfg.users.users.${n}.extraGroups) (builtins.attrNames cfg.users.users);
      dockerSocketUnits = builtins.filter (n: builtins.match ".*docker.*" n != null) (builtins.attrNames cfg.systemd.sockets);
      dockerUnit =
        if cfg.systemd.user.services ? docker
        then let svc = cfg.systemd.user.services.docker; in {
          execStart = svc.serviceConfig.ExecStart;
          wantedBy = svc.wantedBy;
          notRoot = svc.unitConfig.ConditionUser;
          restart = svc.serviceConfig.Restart;
        }
        else null;
      podmanDockerCompat = cfg.virtualisation.podman.dockerCompat;
      podmanDockerSocket = cfg.virtualisation.podman.dockerSocket.enable;
      extraInit = cfg.environment.extraInit;
      zshSystem = cfg.programs.zsh.enable;
      zshGlobalCompInit = cfg.programs.zsh.enableGlobalCompInit;
      # just, lazygit and lazydocker are user packages of lex on the agent; as system packages they are in no role.
      systemTools = builtins.listToAttrs (map (n: { name = n; value = builtins.any (p: (p.pname or "") == n) cfg.environment.systemPackages; }) [ "just" "lazygit" "lazydocker" ]);
      # The browser piece (dotfiles.agent.browser). chromium is a package of no role: it is reached through the link that systemd-tmpfiles makes, so these
      # facts look at the rules, the option wrapper, the units, and what confines the user (groups, setuid wrappers, sysctl for user namespaces).
      chromiumSystemPackage = builtins.any (p: (p.pname or "") == "chromium") cfg.environment.systemPackages;
      browserOption = cfg.dotfiles.agent.browser.enable or false;
      browserTmpfiles = builtins.filter (r: builtins.match ".*(/opt/google|[Cc]hrom).*" r != null) cfg.systemd.tmpfiles.rules;
      browserWrapper = let p = cfg.dotfiles.agent.browser.package or null; in
        if p == null then null else { inherit (p) pname version; path = p.outPath; command = p.drvAttrs.buildCommand; };
      browserUnits = let
          hit = n: builtins.match ".*([Cc]hrom|axi|[Dd]evtools|[Bb]rowser|[Pp]uppeteer).*" n != null;
          lexUser = if cfg ? home-manager && cfg.home-manager.users ? lex then cfg.home-manager.users.lex else null;
          hmNames = if lexUser == null then [ ] else builtins.concatMap (k: builtins.attrNames lexUser.systemd.user.${k}) [ "services" "sockets" "timers" ];
        in builtins.filter hit (builtins.concatLists (map (k: builtins.attrNames cfg.systemd.${k}) [ "services" "sockets" "timers" ] ++ map (k: builtins.attrNames cfg.systemd.user.${k}) [ "services" "sockets" "timers" ] ++ [ hmNames ]));
      suidSandbox = cfg.security.chromiumSuidSandbox.enable;
      chromeWrappers = builtins.filter (n: builtins.match ".*[Cc]hrom.*" n != null) (builtins.attrNames cfg.security.wrappers);
      usernsSysctl = builtins.filter (k: builtins.match ".*(userns|user_namespaces|namespaces).*" k != null) (builtins.attrNames cfg.boot.kernel.sysctl);
      normalUserGroups = builtins.concatMap (n: cfg.users.users.${n}.extraGroups) (builtins.filter (n: cfg.users.users.${n}.isNormalUser) (builtins.attrNames cfg.users.users));
      # What the browser piece must not touch, by value and not by name: all of it is compared with the same agent with the option off, so a rule, unit, wrapper, sysctl, group, package,
      # variable or sudo entry that the piece adds under any name shows up as a difference.
      confine = let
          lexUser = if cfg ? home-manager && cfg.home-manager.users ? lex then cfg.home-manager.users.lex else null;
          normalNames = builtins.filter (n: cfg.users.users.${n}.isNormalUser) (builtins.attrNames cfg.users.users);
          pkgName = p: p.name or (p.pname or "unnamed");
          unitNames = attrs: builtins.concatMap (k: if attrs ? ${k} && builtins.isAttrs attrs.${k} then builtins.attrNames attrs.${k} else [ ]) [ "services" "sockets" "timers" "paths" "targets" "slices" ];
          flat = builtins.replaceStrings [ "\n" ] [ " " ] cfg.security.sudo.configFile;
        in {
          setuidWrappers = builtins.filter (n: let w = cfg.security.wrappers.${n}; in (w.setuid or false) || (w.setgid or false) || ((w.capabilities or "") != "")) (builtins.attrNames cfg.security.wrappers);
          sysctl = cfg.boot.kernel.sysctl;
          tmpfilesRules = cfg.systemd.tmpfiles.rules;
          tmpfilesSettings = cfg.systemd.tmpfiles.settings;
          units = {
            system = unitNames cfg.systemd;
            user = unitNames cfg.systemd.user;
            hm = if lexUser == null then [ ] else unitNames lexUser.systemd.user;
          };
          envVariables = cfg.environment.variables;
          envSession = cfg.environment.sessionVariables;
          hmSession = if lexUser == null then { } else lexUser.home.sessionVariables;
          userManagerSession = cfg.systemd.user.extraConfig;
          systemPackages = map pkgName cfg.environment.systemPackages;
          userPackages = builtins.concatMap (n: map pkgName cfg.users.users.${n}.packages) normalNames;
          hmPackages = if lexUser == null then [ ] else map pkgName lexUser.home.packages;
          userGroups = builtins.sort builtins.lessThan (builtins.concatMap (n: cfg.users.users.${n}.extraGroups) normalNames
            ++ builtins.filter (g: builtins.any (n: builtins.elem n (cfg.users.groups.${g}.members or [ ])) normalNames) (builtins.attrNames cfg.users.groups));
          wheelMembers = cfg.users.groups.wheel.members or [ ];
          sudoConfig = cfg.security.sudo.configFile;
          sudoNamesTheUser = builtins.any (n: builtins.match (".*[^A-Za-z0-9_]" + n + "[^A-Za-z0-9_].*") flat != null) normalNames;
        };
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
          zshenv = u.programs.zsh.envExtra;
          mason =
            if u.systemd.user.services ? mason-lsp-install
            then let svc = u.systemd.user.services.mason-lsp-install; in {
              execStart = svc.Service.ExecStart;
              environment = svc.Service.Environment;
              type = svc.Service.Type;
              restart = svc.Service.Restart;
              wantedBy = svc.Install.WantedBy;
            }
            else null;
          # neovim as a user package, and anything of the user that Home Manager would place under ~/.config/nvim (a link or programs.neovim)
          neovimPackaged = builtins.any (p: builtins.match "neovim.*" (p.pname or "") != null) u.home.packages;
          # shellcheck as a user package (pkgs.shellcheck has pname ShellCheck and name shellcheck-0.11.0; the pattern takes both cases): bash-language-server runs it for its diagnostics
          shellcheck = builtins.any (p: builtins.match "[Ss]hell[Cc]heck" (p.pname or "") != null) u.home.packages;
          # just, lazygit and lazydocker as user packages (the agent-tools piece)
          tools = builtins.listToAttrs (map (n: { name = n; value = builtins.any (p: (p.pname or "") == n) u.home.packages; }) [ "just" "lazygit" "lazydocker" ]);
          # the interactive zsh piece: the whole ~/.zshrc (Home Manager merges the ordered pieces into initContent), fzf, and the step that starts Docker
          zshrc = u.programs.zsh.initContent;
          fzf = builtins.any (p: (p.pname or "") == "fzf") u.home.packages;
          # the Docker contexts, the ssh entry and key of the jumphost, and lazydocker as the wrapper for ssh:// contexts
          dockerContexts = if u.home.activation ? dockerContexts then { after = u.home.activation.dockerContexts.after; data = u.home.activation.dockerContexts.data; } else null;
          jumphostKey = if u.home.activation ? jumphostKey then { after = u.home.activation.jumphostKey.after; before = u.home.activation.jumphostKey.before; data = u.home.activation.jumphostKey.data; } else null;
          sshEnabled = u.programs.ssh.enable or false;
          sshDefaultConfig = u.programs.ssh.enableDefaultConfig or null;
          sshBlocks = builtins.attrNames (u.programs.ssh.matchBlocks or { });
          sshJumphost =
            if (u.programs.ssh.matchBlocks or { }) ? jumphost_server
            then let e = u.programs.ssh.matchBlocks.jumphost_server; b = e.data or e; in {
              inherit (b) hostname user identityFile identitiesOnly userKnownHostsFile extraOptions;
            }
            else null;
          knownHosts = if u.home.file ? ".ssh/known_hosts.d/jumphost_server" then u.home.file.".ssh/known_hosts.d/jumphost_server".text else null;
          lazydockerWrapped = builtins.any (p: (p.pname or "") == "lazydocker" && (p.wrapped or false)) u.home.packages;
          dockerStart = if u.home.activation ? dockerRootlessStart then { after = u.home.activation.dockerRootlessStart.after; data = u.home.activation.dockerRootlessStart.data; } else null;
          nvimConfigOwned = (u.programs.neovim.enable or false)
            || builtins.any (f: builtins.match "(.*/)?\\.config/nvim(/.*)?" f.target != null) (builtins.attrValues u.home.file)
            || builtins.any (n: builtins.match "nvim(/.*)?" n != null) (builtins.attrNames u.xdg.configFile);
          # home.file is keyed by the absolute path for xdg.configFile entries: match the normalised target, and the xdg names
          ghOwned = (u.programs.gh.enable or false)
            || builtins.any (f: builtins.match "(.*/)?\\.config/gh(/.*)?" f.target != null) (builtins.attrValues u.home.file)
            || builtins.any (n: builtins.match "gh(/.*)?" n != null) (builtins.attrNames u.xdg.configFile);
        }
        else null;
    };
    syncOff = { dotfiles.agent.sync = { plugins = false; skills = false; hindsight = false; }; };
    masonOff = { dotfiles.agent.mason.enable = false; };
    dockerOff = { dotfiles.agent.docker.enable = false; };
    toolsOff = { dotfiles.agent.tools.enable = false; };
    zshOff = { dotfiles.agent.zsh.enable = false; };
    jumphostOff = { dotfiles.agent.jumphost.enable = false; };
    browserOff = { dotfiles.agent.browser.enable = false; };
  in {
    guest = summary c.proxmox-guest.config;
    agent = summary c.proxmox-agent.config;
    agentOff = summary (c.proxmox-agent.extendModules { modules = [ syncOff ]; }).config;
    masonOff = summary (c.proxmox-agent.extendModules { modules = [ masonOff ]; }).config;
    dockerOff = summary (c.proxmox-agent.extendModules { modules = [ dockerOff ]; }).config;
    toolsOff = summary (c.proxmox-agent.extendModules { modules = [ toolsOff ]; }).config;
    zshOff = summary (c.proxmox-agent.extendModules { modules = [ zshOff ]; }).config;
    jumphostOff = summary (c.proxmox-agent.extendModules { modules = [ jumphostOff ]; }).config;
    browserOff = summary (c.proxmox-agent.extendModules { modules = [ browserOff ]; }).config;
  }
') || {
  echo "roles-check: nix eval failed" >&2
  exit 2
}

# The jumphost's host values: the one file that the Mac (home/default.nix) and the agent VMs (home/linux/agent.nix) both read.
jh=$(nix eval --json --file "$repo/home/ssh/jumphost.nix") || {
  echo "roles-check: nix eval of home/ssh/jumphost.nix failed" >&2
  exit 2
}

fail=0
check() { # check LABEL JQ-EXPRESSION [JQ-ARGS...]
  if printf '%s' "$facts" | jq -e "${@:3}" "$2" >/dev/null; then
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
check "agent: the sync options are on by default" '.agent.syncFile == {"plugins": true, "skills": true, "hindsight": true}'
check "agent: harper (harper-cli) is installed" '.agent.harper'
check "agent: plugin install service and activation" '.agent.userSync.service and .agent.userSync.activation'
check "agent: gh is git's credential helper for github.com, and Home Manager owns nothing of ~/.config/gh" '(.agent.userSync.helper | test("^!/nix/store/[^ ]+/bin/gh auth git-credential$")) and (.agent.userSync.ghOwned | not)'
check "agent: the manifests are placed before the user units reload, and the unit carries the hash of the captured files" '.agent.userSync.before == ["reloadSystemd"] and ([.agent.userSync.execStart] | flatten | map(test(" [0-9a-f]{64}$")) | any)'
check "agent: the plugin install unit starts with the user manager at boot and is retried on failure" '.agent.userSync.wantedBy == ["default.target"] and .agent.userSync.restart == "on-failure"'
check "agent: zsh reads the hindsight file for every shell, and never ~/.omp/.env" '.agent.userSync.zshenv | (contains("config/dotfiles/hindsight.env") and (contains(".omp/.env") | not) and contains("set -a") and contains("set +a"))'
check "agent with every sync option off: no harper, no service, no activation, no hindsight in zsh; gh stays the credential helper" '.agentOff | (.syncFile == {"plugins": false, "skills": false, "hindsight": false}) and ([.harper, .userSync.service, .userSync.activation] | any | not) and (.userSync.helper | test("^!/nix/store/[^ ]+/bin/gh auth git-credential$")) and (.userSync.zshenv | contains("hindsight") | not)'

# The Mason piece. The list is the committed file; the unit must carry its hash and every name of it, in order.
list=$repo/home/omp/mason-lsp.txt
init=$repo/home/linux/mason-init.lua
listhash=$(shasum -a 256 <"$list" | cut -c1-64)
listnames=$(tr '\n' ' ' <"$list" | sed 's/ $//')
check "clean: no neovim" '.guest.neovim | not'
check "agent: the Mason install is a simple user unit, started with the user manager at boot and retried on failure" '.agent.userSync.mason | (.type == "simple" and .wantedBy == ["default.target"] and .restart == "on-failure")'
check "agent: the Mason unit carries the hash of home/omp/mason-lsp.txt, a store nvim, the store copy of the init file, and every name of the list in order" '[.agent.userSync.mason.execStart] | flatten | .[0] | split(" ") | (length > 4) and (.[1] == $hash) and (.[2] | test("^/nix/store/[a-z0-9]{32}-neovim-[0-9.]+/bin/nvim$")) and (.[3] | test("^/nix/store/[a-z0-9]{32}-mason-init.lua$")) and ((.[4:] | join(" ")) == $names)' --arg hash "$listhash" --arg names "$listnames"
check "agent: the PATH of the Mason unit is exactly what the install of the listed servers runs (curl, gzip, tar, getconf, node, go, cargo with rustc, gcc, git, nix; bash and coreutils for the script), and MASON_NVIM is mason.nvim" '.agent.userSync.mason.environment | (length == 2) and ((map(select(startswith("PATH="))) | .[0] | ltrimstr("PATH=") | split(":") | map(sub("^/nix/store/[a-z0-9]{32}-"; "") | sub("/bin$"; "") | sub("-[0-9].*$"; "")) | sort) == ["bash-interactive", "cargo", "coreutils", "curl", "gcc-wrapper", "getconf-glibc", "git", "gnutar", "go", "gzip", "nix", "nodejs", "rustc-wrapper"]) and (map(select(startswith("MASON_NVIM="))) | .[0] | test("^MASON_NVIM=/nix/store/[a-z0-9]{32}-vimplugin-mason.nvim-"))'
check "agent: neovim is on no PATH (not a system package, not a user package) and Home Manager owns nothing of ~/.config/nvim; the unit names no config path" '(.agent.neovim | not) and (.agent.userSync.neovimPackaged | not) and (.agent.userSync.nvimConfigOwned | not) and ([.agent.userSync.mason.execStart, .agent.userSync.mason.environment] | flatten | map(contains(".config")) | any | not)'
check "agent with the Mason option off: no Mason unit, and the plugin install stays" '.masonOff.userSync | (.mason == null) and .service'
check "agent with every sync option off: the Mason unit stays (it is not part of the sync)" '.agentOff.userSync.mason != null'
check "agent: shellcheck is a user package, on lex's login PATH (bash-language-server gets its diagnostics from it)" '.agent.userSync.shellcheck'
check "agent with the Mason option off: no shellcheck (it goes with the Mason servers), and the Mason unit's PATH never names it" '(.masonOff.userSync.shellcheck | not) and ([.agent.userSync.mason.environment] | flatten | map(ascii_downcase | contains("shellcheck")) | any | not)'
check "clean and agent: shellcheck is no system package (it is a user package of lex on the agent only)" '(.guest.shellcheck | not) and (.agent.shellcheck | not)'

# The Docker piece (rootless only) and the tools piece (just, lazygit, lazydocker). The agent has no sudo and is not in wheel; a docker group, or a rootful daemon,
# would be root on the machine for that user, so no role may have either.
check "clean: no Docker of any kind (no daemon, no unit, no docker group, no docker socket unit, no docker package) and none of just, lazygit, lazydocker" '.guest | ([.dockerRootful, .dockerRootless, .dockerSystemPackage, .dockerGroup, (.dockerSocketUnits != []), (.dockerUnit != null), ([.systemTools[]] | any)] | any) | not'
check "agent: Docker is rootless (the rootless daemon is on, the rootful one is off) and DOCKER_HOST is exported by no login (it would override Docker contexts)" '.agent | .dockerRootless and (.dockerRootful | not) and (.dockerSocketVar | not) and (.extraInit | contains("DOCKER_HOST") | not) and (.userSync.zshenv | contains("DOCKER_HOST") | not) and (.userSync.zshrc | contains("DOCKER_HOST") | not)'
check "agent: no docker group, nobody in it, no docker socket unit, podman is not docker (no dockerCompat, no docker socket), and the user is outside wheel" '.agent | (.dockerGroup | not) and (.dockerGroupMembers == []) and (.dockerUsers == []) and (.dockerSocketUnits == []) and (.podmanDockerCompat | not) and (.podmanDockerSocket | not) and (.wheel == [])'
check "agent: the daemon is Docker 29 (nixos-25.11 marks its default pkgs.docker, 28, insecure) and the docker CLI is a system package" '.agent | (.dockerVersion | startswith("29.")) and (.dockerVulnerabilities == []) and .dockerSystemPackage'
check "agent: the rootless daemon is a user unit that runs dockerd-rootless, starts with the user manager at boot, never for root, and restarts" '.agent.dockerUnit | (.execStart | test("/bin/dockerd-rootless ")) and (.wantedBy == ["default.target"]) and (.notRoot == "!root") and (.restart == "always")'
check "agent: just, lazygit and lazydocker are user packages of lex, and in no system package list of either role" '(.agent.userSync.tools == {"just": true, "lazygit": true, "lazydocker": true}) and ([.guest.systemTools, .agent.systemTools] | map([.[]] | any) | any | not)'
check "agent with the Docker option off: no Docker at all (no daemon, unit, package, DOCKER_HOST), while the tools and podman stay" '.dockerOff | ([.dockerRootless, .dockerRootful, .dockerSystemPackage, (.dockerUnit != null), (.extraInit | contains("DOCKER_HOST"))] | any | not) and ([.userSync.tools[]] | all) and .podman'
check "agent with the tools option off: none of just, lazygit, lazydocker, while Docker and podman stay" '.toolsOff | ([.userSync.tools[]] | any | not) and .dockerRootless and .podman'

# The interactive zsh piece (the Mac's files and plugins) and the start of the rootless Docker unit by Home Manager.
check "clean: no zsh set up (no system zsh), so /etc/zshrc and the rest are the clean guest's" '.guest.zshSystem | not'
check "agent: /etc/zshrc runs no compinit (the one call is in ~/.zshrc, after the fpath is extended); with the zsh option off it does, as before" '(.agent.zshGlobalCompInit | not) and .zshOff.zshGlobalCompInit'
check "agent: ~/.zshrc leaves at once for a shell without a terminal, then loads the three files of the Mac, the vim override of EDITOR, the plugins in the order of the Mac, and compinit, in that order" '.agent.userSync.zshrc as $z | (["[[ ! -t 0 || ! -t 1 ]]", "return 2>/dev/null || true", "-aliases.zsh", "-options.zsh", "-keybindings.zsh", "export EDITOR=vim VISUAL=vim", "zsh-syntax-highlighting-", "zsh-autosuggestions-", "zsh-completions-", "zsh-history-substring-search-", "zsh-fzf-tab-", "fzf-tab-source.plugin.zsh", "compinit -d"] | map(. as $n | $z | index($n))) as $at | ($at | all(. != null)) and ($at == ($at | sort))'
check "agent: the EDITOR override is for a machine without nvim only" '.agent.userSync.zshrc | contains("if (( ! $+commands[nvim] )); then\n  export EDITOR=vim VISUAL=vim\nfi")'
check "agent: one compinit (a daily full call and a cached -C call, nothing of Home Manager's own), never from /etc/zshrc" '.agent.userSync.zshrc | (([match("compinit -[dC]"; "g")] | length) == 2) and (contains("autoload -U compinit && compinit") | not)'
check "agent: the plugins come from the store, fzf-tab-source from its pinned source, none is fetched at shell start" '.agent.userSync.zshrc | (test("source /nix/store/[a-z0-9]{32}-zsh-syntax-highlighting-[0-9.]+/share/")) and (test("source /nix/store/[a-z0-9]{32}-zsh-fzf-tab-[0-9.]+/share/fzf-tab/fzf-tab.plugin.zsh")) and (test("source /nix/store/[a-z0-9]{32}-source/fzf-tab-source.plugin.zsh")) and (test("curl|wget|git clone|zap\\.zsh|zap-zsh") | not)'
check "agent: fzf is a user package of lex (fzf-tab needs it)" '.agent.userSync.fzf'
check "agent: none of it is in ~/.zshenv, which every shell reads (omp and the agents run zsh -c)" '.agent.userSync.zshenv | (test("syntax-highlighting|autosuggestions|fzf-tab|aliases\\.zsh|compinit") | not) and contains("hindsight.env")'
check "agent with the zsh option off: ~/.zshrc names none of the Mac's files or plugins, no compinit, no early exit, no fzf" '.zshOff | (.userSync.zshrc | (contains("aliases.zsh") or contains("compinit") or contains("zsh-autosuggestions") or contains("[[ ! -t 0")) | not) and (.userSync.fzf | not)'
check "agent: Home Manager starts the rootless Docker unit after reloadSystemd (a NixOS switch loads a new user unit but does not start it), with the systemctl of the store" '.agent.userSync.dockerStart | (.after == ["reloadSystemd"]) and (.data | (contains("start_user_unit()")) and test("\nstart_user_unit /nix/store/[a-z0-9]{32}-systemd-[0-9.]+/bin/systemctl docker\\.service\n"))'
check "agent with the Docker option off: no such start step" '.dockerOff.userSync.dockerStart == null'

# Docker contexts (no DOCKER_HOST): `rootless` is the local socket and the current context, `jumphost` is ssh://<alias>, made once by an activation step.
check "agent: the context rootless (the user's runtime socket) is made current, with the docker CLI of the daemon's package, after writeBoundary" '.agent.userSync.dockerContexts | (.after == ["writeBoundary"]) and (.data | (contains("ensure_docker_context()")) and test("\nensure_docker_context /nix/store/[a-z0-9]{32}-docker-29\\.[0-9.]+/bin/docker rootless \"unix:///run/user/\\$\\(id -u\\)/docker\\.sock\" current\n"))'
check "agent: the context jumphost is ssh://jumphost_server (the alias of home/ssh/jumphost.nix), not made current" '.agent.userSync.dockerContexts.data | test("\nensure_docker_context /nix/store/[a-z0-9]{32}-docker-29\\.[0-9.]+/bin/docker jumphost ssh://jumphost_server\n")' --argjson jh "$jh"
check "agent with the Docker option off: no Docker contexts" '.dockerOff.userSync.dockerContexts == null'
check "agent with the jumphost option off: the context rootless stays, the context jumphost goes" '.jumphostOff.userSync.dockerContexts.data | (contains(" rootless ")) and (contains("jumphost") | not)'
check "agent: the jumphost needs Docker (an assertion refuses the jumphost without it), and no assertion fails otherwise" '(.agent.failedAssertions == []) and (.dockerOff.failedAssertions | length == 1) and (.dockerOff.failedAssertions[0] | contains("jumphost"))'

# The jumphost piece: one ssh entry from the shared values, the VM's own key, a pinned host key, nothing of the Mac's `Host *` block.
check "agent: the ssh entry of the jumphost has the shared HostName and User, only the key made on the VM (IdentitiesOnly), strict host key checking against one pinned file and no global known_hosts" '.agent.userSync.sshJumphost as $j | $j.hostname == $jh.hostname and $j.user == $jh.user and ($j.identityFile == ["~/.ssh/id_ed25519_jumphost"]) and $j.identitiesOnly and ($j.userKnownHostsFile == "~/.ssh/known_hosts.d/jumphost_server") and ($j.extraOptions.StrictHostKeyChecking == "yes") and ($j.extraOptions.GlobalKnownHostsFile == "/dev/null")' --argjson jh "$jh"
check "agent: no other ssh entry, no Host * defaults of the Mac (no User root, no StrictHostKeyChecking no, no UseKeychain)" '.agent.userSync | .sshEnabled and (.sshDefaultConfig == false) and (.sshBlocks == ["jumphost_server"])'
check "agent: the pinned known_hosts file holds exactly the shared host key of the jumphost, under its address" '.agent.userSync.knownHosts == ($jh.hostname + " " + $jh.hostKey + "\n")' --argjson jh "$jh"
check "agent: the shared host key is an ed25519 public key (not a private key)" '$jh.hostKey | test("^ssh-ed25519 AAAAC3NzaC1lZDI1NTE5[A-Za-z0-9+/]{48}$")' --argjson jh "$jh"
check "agent: the VM makes its own jumphost key once (ensure_ssh_key, ed25519, never replaced) after writeBoundary and before the links of Home Manager, with the ssh-keygen of the store" '.agent.userSync.jumphostKey | (.after == ["writeBoundary"]) and (.before == ["linkGeneration"]) and (.data | (contains("ensure_ssh_key()")) and test("\nensure_ssh_key /nix/store/[a-z0-9]{32}-openssh-[^/]+/bin/ssh-keygen \"\\$HOME/\\.ssh/id_ed25519_jumphost\" docker-jumphost\n"))'
check "agent: lazydocker is the wrapper for ssh:// contexts" '.agent.userSync.lazydockerWrapped'
check "agent with the jumphost option off: no ssh entry or known_hosts file, no key, plain lazydocker; Docker, the tools and podman stay" '.jumphostOff | (.userSync | (.sshJumphost == null) and (.knownHosts == null) and (.jumphostKey == null) and (.lazydockerWrapped | not) and (.sshBlocks == []) and (.tools == {"just": true, "lazygit": true, "lazydocker": true})) and .dockerRootless and .podman'
check "agent with the Docker option off: the jumphost piece is refused by an assertion, never half-applied" '.dockerOff.failedAssertions | length == 1'
check "clean: no jumphost, no ssh entry, no key, no Docker context (no Home Manager user at all), and no failing assertion" '.guest | (.userSync == null) and (.failedAssertions == [])'

# The browser piece: chromium from the role's nixpkgs, reached through the link /opt/google/chrome/chrome (where the stable channel of chrome-devtools-mcp looks for it),
# headless by its wrapper, started by the CLI on demand. No service, no port, no change to what confines the user.
check "clean: no browser at all (no chromium package, no /opt/google or chrome rule, no browser option or wrapper, no unit, no setuid sandbox, no chrome wrapper)" '.guest | ([.chromiumSystemPackage, .browserOption, (.browserTmpfiles != []), (.browserUnits != []), (.browserWrapper != null), .suidSandbox, (.chromeWrappers != [])] | any) | not'
check "agent: the browser piece is on by default, and chromium is no system package: it is reached through exactly three tmpfiles rules, the directories of /opt/google/chrome (root, 0755) and the one link /opt/google/chrome/chrome to bin/chromium of the option's package" '.agent as $a | ($a.browserWrapper.path + "/bin/chromium") as $bin | $a.browserOption and ($a.chromiumSystemPackage | not) and (($a.browserTmpfiles | sort) == (["d /opt/google 0755 root root -", "d /opt/google/chrome 0755 root root -", "L+ /opt/google/chrome/chrome - - - - " + $bin] | sort))'
check "agent: the package is chromium of the role's nixpkgs (a four-part version), not a download" '.agent.browserWrapper | (.pname == "chromium") and (.version | test("^[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+$")) and (.path | test("^/nix/store/[a-z0-9]{32}-chromium-"))'
check "agent: the wrapper adds exactly --headless=new and --disable-gpu to chromium (the VM has no display; without a GPU Chromium's software GL fallback runs its GPU process with no seccomp filter) and nothing else: no flag that turns a sandbox off, opens a debug port, runs in one process or opts in to SwiftShader" '.agent.browserWrapper.command | ([scan("--add-flags \u0027([^\u0027]*)\u0027")] == [["--headless=new --disable-gpu"]])'
check "agent: no default of the piece turns the sandbox off (the tmpfiles rules, the wrapper, ~/.zshenv and the environment of the system, the session and Home Manager name no such flag and no PUPPETEER_DANGEROUS_NO_SANDBOX), and the zsh env sets the idle timeout of the CLI and no other variable of it (no flags, no executable path, no display)" '.agent | ([.browserTmpfiles[], .userSync.zshenv, .browserWrapper.command, (.confine.envVariables | tostring), (.confine.envSession | tostring), (.confine.hmSession | tostring)] | map(test("--(no|disable)-[a-z-]*sandbox|NO_SANDBOX|remote-debugging"; "i")) | any | not) and ([.userSync.zshenv | match("CHROME_DEVTOOLS_AXI_[A-Z_]+"; "g").string] == ["CHROME_DEVTOOLS_AXI_IDLE_TIMEOUT_MS"]) and (.userSync.zshenv | test("DISPLAY") | not)'
check "agent: the zsh env that every shell reads exports the idle timeout (exactly 900000 ms, a line of its own) next to the Hindsight snippet, so that a browser that nobody stopped is stopped by its CLI" '.agent.userSync.zshenv | test("(^|\n)export CHROME_DEVTOOLS_AXI_IDLE_TIMEOUT_MS=900000(\n|$)") and contains("hindsight.env")'
check "agent: the user stays outside wheel (no extra group, not a member of wheel by either list, no sudo entry that names the user), and the piece adds no chromium setuid sandbox and no setuid wrapper named for chrome or a kernel setting for user namespaces (the sandbox runs on the user namespaces that rootless Docker and podman use)" '.agent | (.wheel == []) and (.normalUserGroups == []) and (.confine.wheelMembers == []) and (.confine.userGroups | index("wheel") | not) and (.confine.sudoNamesTheUser | not) and (.suidSandbox | not) and (.chromeWrappers == []) and (.usernsSysctl == [])'
check "agent: the browser facts are populated (a comparison of two empty facts would prove nothing): units of the system, the user manager and Home Manager, wrappers, sysctl, tmpfiles rules, the session environment, the packages of the system and of Home Manager, sudo" '.agent.confine | ([(.units.system | length), (.units.user | length), (.units.hm | length), (.setuidWrappers | length), (.sysctl | length), (.tmpfilesRules | length), (.envSession | length), (.systemPackages | length), (.hmPackages | length), (.sudoConfig | length)] | all(. > 0))'
check "agent: the browser piece adds exactly three tmpfiles rules and one line of ~/.zshenv, and nothing else, whatever its name: every other fact (setuid or capability wrappers, kernel settings, tmpfiles settings, every unit, socket, timer, path and target of the system, the user manager and Home Manager, the environment variables of the system, the session and Home Manager, the packages of the system, of the user and of Home Manager, the groups of the user, sudo, the firewall) equals the agent with the option off" '(.agent.confine | del(.tmpfilesRules)) == (.browserOff.confine | del(.tmpfilesRules)) and ((.agent.confine.tmpfilesRules - .browserOff.confine.tmpfilesRules) | length) == 3 and ((.browserOff.confine.tmpfilesRules - .agent.confine.tmpfilesRules) | length) == 0 and ((.agent.userSync.zshenv | sub("export CHROME_DEVTOOLS_AXI_IDLE_TIMEOUT_MS=900000\n"; "") | gsub("\n\n+"; "\n") | ltrimstr("\n")) == (.browserOff.userSync.zshenv | gsub("\n\n+"; "\n") | ltrimstr("\n"))) and (.agent.tcp == .browserOff.tcp) and (.agent.udp == .browserOff.udp) and (.agent.wheel == .browserOff.wheel) and (.agent.linger == .browserOff.linger)'
check "no role has a browser service, socket or timer by name (system, user, or of the user's Home Manager), and the piece opens no port" '([.guest, .agent, .browserOff] | all(.browserUnits == [])) and (.browserOff.tcp == .agent.tcp) and (.browserOff.udp == .agent.udp)'
check "agent with the browser option off: no link, no chromium package, none of its variables in zsh (the Hindsight snippet stays)" '.browserOff | (.browserTmpfiles == []) and (.chromiumSystemPackage | not) and (.userSync.zshenv | (contains("CHROME_DEVTOOLS_AXI") | not) and contains("hindsight.env"))'

# The init file that the unit hands to nvim: mason.nvim and Neovim's own runtime, nothing else.
initcode=$(grep -v '^--' "$init")
icheck() { # icheck LABEL EXIT-STATUS
  if [ "$2" -eq 0 ]; then printf '  ok   %s\n' "$1"; else printf '  FAIL %s\n' "$1"; fail=1; fi
}
# No source of the Nix modules or of Home Manager names a flag that turns a sandbox of Chromium off (a comment would be found as well). The scan fails closed: grep's own errors are shown,
# its exit status 2 (a missing or unreadable directory) fails the check, and a positive control shows that it reads the two files that carry the piece.
scan_dirs=("$repo/modules" "$repo/home")
scan_raw=$(grep -rIEn -e '--(no|disable)-[a-z-]*sandbox' "${scan_dirs[@]}")
scan_rc=$?
bad=$(printf '%s' "$scan_raw" | cut -d: -f1,2 | sed "s#^$repo/##" | tr '\n' ' ')
[ "$scan_rc" -le 1 ] && [ -z "$bad" ]
scan_ok=$?
icheck "no file under modules/ or home/ names a flag that turns the Chromium sandbox off${bad:+ (found: $bad)}" "$scan_ok"
[ "$(grep -rIlF -e 'cfg.browser.enable' "${scan_dirs[@]}" | wc -l | tr -d ' ')" -eq 2 ]
pos_ok=$?
icheck "the sandbox scan reads the two files that carry the browser piece (positive control: both name cfg.browser.enable)" "$pos_ok"
printf '%s\n' "$initcode" | grep -qxF 'vim.opt.runtimepath = { mason, vim.env.VIMRUNTIME }'
icheck "init file: the runtime path is mason.nvim and Neovim's own runtime, so no ~/.config/nvim and no site plugin is read" $?
printf '%s\n' "$initcode" | grep -qxF 'vim.opt.packpath = {}'
icheck "init file: no package path" $?
[ "$(printf '%s\n' "$initcode" | grep -c 'require')" -eq 1 ] && printf '%s\n' "$initcode" | grep -qxF 'require("mason").setup()'
icheck "init file: it loads mason.nvim and nothing else" $?
! printf '%s\n' "$initcode" | grep -Eq 'stdpath|\.config|dofile|loadfile|source|packadd|vim\.cmd|vim\.fn\.system|os\.execute|io\.popen'
icheck "init file: no other path, no sourcing, no shell" $?

# The Mac's zsh files that the VM sources are the repo files, byte for byte (the flake names a store copy of each).
zshrc=$(printf '%s' "$facts" | jq -r '.agent.userSync.zshrc')
for zf in aliases options keybindings; do
  zp=$(printf '%s\n' "$zshrc" | sed -nE "s#^source (/nix/store/[a-z0-9]{32}-$zf\\.zsh)\$#\\1#p")
  [ -n "$zp" ] && [ "$(printf '%s\n' "$zp" | wc -l | tr -d ' ')" -eq 1 ] && [ -f "$zp" ] && cmp -s "$zp" "$repo/home/zsh/config/$zf.zsh"
  icheck "zsh: the $zf.zsh that the VM sources is home/zsh/config/$zf.zsh of the Mac, byte for byte" $?
done

# The zsh snippet of the hindsight piece, run for real with fixture files (no secret): the file's values reach a
# child process, no file means no output and no variables, and allexport is left as the shell had it.
snippet=$(printf '%s' "$facts" | jq -r '.agent.userSync.zshenv')
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/with/.config/dotfiles" "$work/without"
printf '# fixture\nHINDSIGHT_API_URL='"'https://hindsight.fixture.example'"'\nHINDSIGHT_API_TOKEN='"'fixture0token'"'\n' >"$work/with/.config/dotfiles/hindsight.env"
zrun() { # zrun HOME PRE SCRIPT: a clean zsh runs PRE, then the snippet, then SCRIPT; its output (stderr too) comes back
  env -i HOME="$1" PATH="$PATH" zsh -f -c "$2
$snippet
$3" 2>&1
}
if command -v zsh >/dev/null 2>&1; then
  zcheck() { # zcheck LABEL WANT GOT
    if [ "$2" = "$3" ]; then printf '  ok   %s\n' "$1"; else printf '  FAIL %s (got: %s)\n' "$1" "$3"; fail=1; fi
  }
  zcheck "zsh snippet: a child process sees both variables when the file exists" "https://hindsight.fixture.example fixture0token" "$(zrun "$work/with" true 'sh -c "echo \$HINDSIGHT_API_URL \$HINDSIGHT_API_TOKEN"')"
  zcheck "zsh snippet: no file, no output and no variables" "|" "$(zrun "$work/without" true 'echo "${HINDSIGHT_API_URL-}|${HINDSIGHT_API_TOKEN-}"')"
  zcheck "zsh snippet: allexport stays off afterwards" off "$(zrun "$work/with" true '[[ -o allexport ]] && echo on || echo off')"
  zcheck "zsh snippet: a shell that had allexport on keeps it on" on "$(zrun "$work/with" 'setopt allexport' '[[ -o allexport ]] && echo on || echo off')"
  zcheck "zsh snippet: the idle timeout of the browser CLI reaches a child process of the shell, and no other variable of the browser is set (no executable path, no flags, no display)" "900000:" "$(zrun "$work/without" true 'sh -c "echo \$CHROME_DEVTOOLS_AXI_IDLE_TIMEOUT_MS:\${CHROME_DEVTOOLS_AXI_CHROME_ARGS-}\${CHROME_DEVTOOLS_AXI_MCP_PATH-}\${CHROME_DEVTOOLS_AXI_CHANNEL-}\${DISPLAY-}"')"
else
  echo "  skip zsh snippet checks: zsh is not installed"
fi
# The Mac: the jumphost entry of home/default.nix takes HostName, User and the Host name from home/ssh/jumphost.nix (one source), with no literal address of its own.
gcheck() { # gcheck LABEL WANT GOT
  if [ "$2" = "$3" ]; then printf '  ok   %s\n' "$1"; else printf '  FAIL %s (got: %s)\n' "$1" "$3"; fail=1; fi
}
mac_jh=$(grep -c -E 'jumphost\.hostname|jumphost\.user|\$\{jumphost\.alias\}' "$repo/home/default.nix" || true)
gcheck "mac: home/default.nix reads the jumphost's host name, address and user from home/ssh/jumphost.nix (3 references)" 3 "$mac_jh"
mac_lit=$(grep -c -E '^[[:space:]]*"jumphost_server"[[:space:]]*=|192\.168\.50\.29' "$repo/home/default.nix" || true)
gcheck "mac: home/default.nix holds no literal jumphost Host name or address of its own" 0 "$mac_lit"
exit "$fail"
