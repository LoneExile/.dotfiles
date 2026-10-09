#!/usr/bin/env bash
# Guards the roles: the clean guest (proxmox-guest) must stay clean, and the agent (proxmox-agent)
# must stay confined and carry its sync pieces (plugin install, harper, rsync, /etc/dotfiles-agent-sync.json,
# the Hindsight zsh side) only while the dotfiles.agent.sync options are on, and keep gh as git's credential helper with no Home Manager hand on ~/.config/gh. The agent carries the Mason language server install
# (a user service with an exact PATH, neovim on no PATH, nothing of ~/.config/nvim) only while dotfiles.agent.mason.enable is on, whatever the sync options say. Docker is rootless or absent in
# every role (no rootful daemon, no docker group, no docker socket, podman not posing as docker) and comes, with just, lazygit and lazydocker as user packages, only while
# dotfiles.agent.docker.enable and dotfiles.agent.tools.enable are on. One `nix eval` of
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
  in {
    guest = summary c.proxmox-guest.config;
    agent = summary c.proxmox-agent.config;
    agentOff = summary (c.proxmox-agent.extendModules { modules = [ syncOff ]; }).config;
    masonOff = summary (c.proxmox-agent.extendModules { modules = [ masonOff ]; }).config;
    dockerOff = summary (c.proxmox-agent.extendModules { modules = [ dockerOff ]; }).config;
    toolsOff = summary (c.proxmox-agent.extendModules { modules = [ toolsOff ]; }).config;
    zshOff = summary (c.proxmox-agent.extendModules { modules = [ zshOff ]; }).config;
  }
') || {
  echo "roles-check: nix eval failed" >&2
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
check "agent: Docker is rootless (the rootless daemon is on, the rootful one is off) and every login gets DOCKER_HOST for the rootless socket" '.agent | .dockerRootless and (.dockerRootful | not) and .dockerSocketVar and (.extraInit | test("DOCKER_HOST=\"unix://\\$XDG_RUNTIME_DIR/docker\\.sock\""))'
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

# The init file that the unit hands to nvim: mason.nvim and Neovim's own runtime, nothing else.
initcode=$(grep -v '^--' "$init")
icheck() { # icheck LABEL EXIT-STATUS
  if [ "$2" -eq 0 ]; then printf '  ok   %s\n' "$1"; else printf '  FAIL %s\n' "$1"; fail=1; fi
}
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
else
  echo "  skip zsh snippet checks: zsh is not installed"
fi
exit "$fail"
