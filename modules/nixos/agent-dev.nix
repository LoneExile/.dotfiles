# The agent-dev module: a development machine for a coding agent, picked per VM by its role
# (`agent`, see infra/vm-config.sh). `nixosModules.agent-dev` in the flake. Not enabled by default:
# the clean role does not import it, and importing it changes nothing until
# `dotfiles.agent.enable = true`.
#
# What it adds on top of whatever NixOS role it is imported into:
#   - a normal user, not in `wheel`, no sudo, that lingers (its user services start at boot and
#     survive logout); it logs in with the keys that root has (a root-owned copy, see below);
#   - Home Manager for that user (home/linux/agent.nix): zsh, starship, git, direnv, mise;
#   - nix-ld, so glibc programs that were not built for NixOS run (mise's runtimes, omp, Tern);
#   - omp, pinned by hash (agent-dev/omp.nix), with its config files copied in writable;
#   - the gh CLI with git's credential helper for github.com (the user logs in by hand: `gh auth login`),
#     rootless podman, zram swap;
#   - Tern's remote service reachable on the LAN (UDP 8376), with its relay and iroh off.
#   - the sync from the Mac (options `dotfiles.agent.sync.*`, run by `just vm-sync` and by vm-deploy):
#     the captured omp plugins (manifests plus a user service that installs them, and harper-cli),
#     rsync for the skills the Mac mirrors in, and the zsh side of the Hindsight URL and key (the
#     file itself is written from the vault); /etc/dotfiles-agent-sync.json tells vm-sync which of
#     the three.
#   - Mason's language servers for omp (option `dotfiles.agent.mason.enable`): neovim and mason.nvim
#     from nixpkgs, and a user service that installs the servers of home/omp/mason-lsp.txt into
#     ~/.local/share/nvim/mason, where the pi-mason-bridge plugin finds them. Nothing else of Neovim;
#     plus shellcheck (nixpkgs) on lex's PATH, because bash-language-server takes its diagnostics from it.
#   - rootless Docker with Compose (option `dotfiles.agent.docker.enable`): the daemon is a user service of lex, there is no
#     rootful daemon, no docker group and no /var/run/docker.sock (that group would be root on the machine); DOCKER_HOST
#     points every login at the rootless socket. Rootless podman stays beside it.
#   - just, lazygit and lazydocker as packages of lex (option `dotfiles.agent.tools.enable`).
#   - lex's interactive zsh gets the Mac's aliases, options, keybindings and zsh plugins (option `dotfiles.agent.zsh.enable`, home/linux/zsh.nix):
#     the files of home/zsh/config as they are, the plugins from nixpkgs, one cached compinit; /etc/zshrc's own compinit is off then.
# Every piece but the base has an option that follows `dotfiles.agent.enable`.
inputs: {
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.dotfiles.agent;

  piece = what:
    lib.mkOption {
      type = lib.types.bool;
      default = cfg.enable;
      defaultText = lib.literalExpression "config.dotfiles.agent.enable";
      description = "Whether to set up ${what}.";
    };

  # Packages that nixos-25.11 lacks or has too old: mise (see below), harper (only the unstable one
  # builds harper-cli, 25.11's has harper-ls alone) and bun and node (the plugin install service
  # reads a lockfile that a current bun wrote).
  unstable = inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system};
in {
  imports = [inputs.home-manager-nixos.nixosModules.home-manager];

  options.dotfiles.agent = {
    enable = lib.mkEnableOption "the agent development machine (user, shell, runtimes, omp, containers)";

    user = lib.mkOption {
      type = lib.types.str;
      default = "lex";
      description = "The login user. It is not in wheel and has no sudo.";
    };

    omp.enable = piece "omp, pinned, with its config files copied into ~/.omp/agent as writable files";
    mise.enable = piece "mise with the global tools (node, python, uv, go, rust, bun, pnpm)";
    tern.enable = piece "the Tern remote service: UDP 8376 open, served to the LAN only (no relay, no iroh)";
    gh.enable = piece "the GitHub CLI, with git's credential helper for github.com (the user logs in by hand with `gh auth login`)";
    mason.enable = piece "the Mason language servers of home/omp/mason-lsp.txt for omp's LSP tool, installed by a user service with a minimal Neovim (mason.nvim only; no Neovim config, no other plugin), and shellcheck for bash-language-server";
    podman.enable = piece "rootless podman";
    docker.enable = piece "rootless Docker with Compose: a user service of the user (no rootful daemon, no docker group, no /var/run/docker.sock), and DOCKER_HOST for the rootless socket in every login, so that lazydocker and the docker CLI find it";
    tools.enable = piece "just, lazygit and lazydocker, as packages of the user";
    zsh.enable = piece "the Mac's aliases, options, keybindings and zsh plugins (nixpkgs) in the interactive zsh of the user, with fzf, and one cached compinit";

    sync = {
      plugins = piece "the captured omp plugins (home/omp/plugins), installed by a user service, with harper-cli";
      skills = piece "the skills that `just vm-sync` mirrors from the Mac into ~/.omp/agent/skills (needs rsync on the VM)";
      hindsight = piece "the public Hindsight API for omp: zsh reads ~/.config/dotfiles/hindsight.env (written by `just vm-sync` from the vault) into HINDSIGHT_API_URL and HINDSIGHT_API_TOKEN, which omp prefers over its config file";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      users.users.${cfg.user} = {
        isNormalUser = true;
        # zsh is the login shell; Home Manager configures it.
        shell = pkgs.zsh;
        # User services (Tern's) start at boot and stay up after logout.
        linger = true;
      };

      # The system side of the login shell: /etc/shells and the global completion setup.
      programs.zsh.enable = true;

      # The user logs in with the keys of root. Root's authorized_keys is the one list of keys that
      # vm-install wrote, and it is not in the repo or the Nix store, so it is copied on the VM, at
      # every activation, to a root-owned file outside the user's reach that sshd reads for every
      # account (AuthorizedKeysFile). Root runs nothing inside the user's home, so the user cannot
      # steer it with a symlink, and a key removed from root's list is gone from this file at the
      # next activation. The user's own ~/.ssh/authorized_keys stays the user's: Tern's setup adds
      # its device key there, and keys the user adds there stay across deploys and reboots.
      system.activationScripts.agentDevAuthorizedKeys.text = ''
        if [ -s /root/.ssh/authorized_keys ]; then
          ${pkgs.coreutils}/bin/install -m 644 -o root -g root /root/.ssh/authorized_keys /etc/ssh/agent-authorized-keys
        fi
      '';
      services.openssh.authorizedKeysFiles = ["/etc/ssh/agent-authorized-keys"];

      # Prebuilt glibc programs (mise's node and python, rust, omp, Tern) look for the dynamic
      # loader at /lib64/ld-linux-x86-64.so.2. nix-ld puts a stub there that loads the real one
      # with the libraries of this list, on top of its defaults (zlib, zstd, libstdc++, openssl,
      # curl, bzip2, xz, libxml2 and a few more).
      programs.nix-ld = {
        enable = true;
        libraries = [pkgs.icu];
      };

      # Compressed RAM as swap: a few GB of agent work and a build can pass the VM's memory.
      zramSwap.enable = true;

      # The compilers that mise's rust and node's native modules link with.
      environment.systemPackages = with pkgs; [curl gcc gnumake];

      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        # A regular file that is in the way of a managed one is kept as <name>.hm-backup instead of
        # failing the whole switch.
        backupFileExtension = "hm-backup";
        users.${cfg.user} = {
          imports = [../../home/linux/agent.nix];
          dotfiles.agent = {
            omp.enable = cfg.omp.enable;
            mise = {
              inherit (cfg.mise) enable;
              # nixos-25.11's mise (2025.11.7) takes the free-threaded CPython build of
              # python-build-standalone for 3.13 and later and fails with "Python installation is
              # missing a `lib` directory" (measured on the VM). nixpkgs-unstable's mise (2026.8.6)
              # installs python 3.14 from the same release.
              package = unstable.mise;
            };
            tern.enable = cfg.tern.enable;
            gh.enable = cfg.gh.enable;
            tools.enable = cfg.tools.enable;
            docker.enable = cfg.docker.enable;
            zsh.enable = cfg.zsh.enable;
            sync = {
              inherit (cfg.sync) plugins hindsight;
              pluginPackages = [unstable.bun unstable.nodejs_24];
            };
            mason = {
              inherit (cfg.mason) enable;
              # What the install of the listed servers runs, measured with every one of them (README): curl for
              # the registry and the release assets, gzip and tar to unpack them, getconf for Mason's glibc
              # check (without it Mason takes NixOS for an unsupported platform), node with npm for the npm
              # packages, go for gopls, and for nil, which is built from a git tag, cargo with rustc (1.6 GiB
              # of closure), a C compiler, git and nix (its build script runs nix). Node is the one of the
              # plugin install, so that the closure holds one; gcc, git and nix are in the closure anyway.
              toolPackages = [unstable.nodejs_24 pkgs.go pkgs.getconf pkgs.curl pkgs.gzip pkgs.gnutar pkgs.cargo pkgs.rustc pkgs.gcc pkgs.git pkgs.nix];
            };
          };
        };
      };

      assertions = [
        {
          assertion = !cfg.sync.plugins || cfg.omp.enable;
          message = "dotfiles.agent.sync.plugins needs dotfiles.agent.omp.enable";
        }
        {
          assertion = !cfg.sync.hindsight || cfg.omp.enable;
          message = "dotfiles.agent.sync.hindsight needs dotfiles.agent.omp.enable";
        }
      ];

      # What the VM wants synced, read by vm-sync (infra/vm-sync-lib.sh). No secret, world readable.
      environment.etc."dotfiles-agent-sync.json".text = builtins.toJSON {inherit (cfg.sync) plugins skills hindsight;};
    }

    (lib.mkIf cfg.omp.enable {
      environment.systemPackages = [(pkgs.callPackage ./agent-dev/omp.nix {})];
    })

    (lib.mkIf cfg.gh.enable {
      environment.systemPackages = [pkgs.gh];
    })

    (lib.mkIf cfg.podman.enable {
      # Rootless: NixOS gives a normal user subuid and subgid ranges, and the setuid newuidmap and
      # newgidmap wrappers come with the shadow module.
      virtualisation.podman.enable = true;
    })

    (lib.mkIf cfg.docker.enable {
      # Rootless only. NixOS runs dockerd-rootless as a user service of every user (ConditionUser=!root) and
      # needs no group: the daemon, its socket (/run/user/<uid>/docker.sock) and its data (~/.local/share/docker)
      # belong to the user, so it is no more than the user is. The rootful daemon (virtualisation.docker.enable)
      # stays off on purpose: it listens on /var/run/docker.sock for the docker group, and that group is root on
      # the machine, which the user (no sudo, not in wheel) must not be. The nixos-25.11 default package,
      # pkgs.docker (28.5.2), is marked insecure (unmaintained since November 2025) and refuses to evaluate;
      # docker_29 (29.6.0) is the same nixpkgs and ships the compose plugin (`docker compose`) and buildx.
      # setSocketVariable puts DOCKER_HOST=unix://$XDG_RUNTIME_DIR/docker.sock into /etc/set-environment, which
      # every login shell of the system reads. dockerCompat of podman stays off: `docker` is Docker's.
      virtualisation.docker.rootless = {
        enable = true;
        setSocketVariable = true;
        package = pkgs.docker_29;
      };
    })

    (lib.mkIf cfg.zsh.enable {
      # /etc/zshrc runs compinit for every interactive zsh BEFORE ~/.zshrc: a completer that ~/.zshrc adds to the fpath
      # afterwards (zsh-completions) is never registered in $_comps. So the global call is off here, and the user's
      # ~/.zshrc (home/linux/zsh.nix) makes the one call, cached like the Mac's. enableCompletion stays on: it keeps
      # /share/zsh of the system profile linked, where the packages' completers are.
      programs.zsh.enableGlobalCompInit = false;
    })

    (lib.mkIf cfg.tern.enable {
      # Tern's remote service (a user service that `tern remote setup` installs from the Mac, see
      # home/linux/agent.nix) serves QUIC on UDP 8376 (measured: `ss` on the VM, and the unit
      # file's own header). The firewall stays default deny: TCP 22 and this one UDP port.
      networking.firewall.allowedUDPPorts = [8376];
    })

    (lib.mkIf cfg.sync.plugins {
      # pi-harper-grammar runs `harper-cli lint`.
      environment.systemPackages = [unstable.harper];
    })

    (lib.mkIf cfg.sync.skills {
      # The Mac's rsync talks to this one.
      environment.systemPackages = [pkgs.rsync];
    })
  ]);
}
