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
#   - the gh CLI, rootless podman, zram swap;
#   - Tern's remote service reachable on the LAN (UDP 8376), with its relay and iroh off.
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
    gh.enable = piece "the GitHub CLI";
    podman.enable = piece "rootless podman";
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
              package = inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.mise;
            };
            tern.enable = cfg.tern.enable;
          };
        };
      };
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

    (lib.mkIf cfg.tern.enable {
      # Tern's remote service (a user service that `tern remote setup` installs from the Mac, see
      # home/linux/agent.nix) serves QUIC on UDP 8376 (measured: `ss` on the VM, and the unit
      # file's own header). The firewall stays default deny: TCP 22 and this one UDP port.
      networking.firewall.allowedUDPPorts = [8376];
    })
  ]);
}
