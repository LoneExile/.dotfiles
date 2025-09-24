{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.modules.darwin.packages;
in {
  options.modules.darwin.packages = {
    enable = lib.mkEnableOption "Darwin system packages";

    cliPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = with pkgs; [
        comma
        hcloud
        just
        lima
        nix
        aerospace
        colima
        docker
        lazydocker
        wezterm
        k9s
        logseq
        obsidian
        syncthing-macos
        talosctl
        yq-go
        fluxcd
        kubernetes-helm
        yazi
        aws-vault
        awscli2
        kubevirt
      ];
      description = "CLI packages to install system-wide";
    };

    unstablePackages = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "yt-dlp"
        "get_iplayer"
        "colmena"
      ];
      description = "Packages to install from unstable channel (by attribute name)";
    };

    fonts = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = with pkgs; [
        nerd-fonts.fira-code
        nerd-fonts.fira-mono
        nerd-fonts.hack
        nerd-fonts.jetbrains-mono
      ];
      description = "Fonts to install system-wide";
    };

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [];
      description = "Additional packages to install";
    };

    nixRegistry = {
      enableShortcuts = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable 'n' and 'u' shortcuts for stable and unstable nixpkgs";
      };

      stablePath = lib.mkOption {
        type = lib.types.str;
        default = "nixpkgs";
        description = "Path to stable nixpkgs input";
      };

      unstablePath = lib.mkOption {
        type = lib.types.str;
        default = "nixpkgs-unstable";
        description = "Path to unstable nixpkgs input";
      };
    };

    extraConfig = lib.mkOption {
      type = lib.types.attrs;
      default = {};
      description = "Additional package configuration";
    };
  };

  config =
    lib.mkIf cfg.enable {
      # System packages
      environment.systemPackages =
        cfg.cliPackages
        ++ cfg.extraPackages
        ++
        # Add unstable packages if available
        (lib.optionals (config ? inputs && config.inputs ? nixpkgs-unstable)
          (map (pkg: config.inputs.nixpkgs-unstable.legacyPackages.${pkgs.system}.${pkg}) cfg.unstablePackages));

      # Fonts
      fonts.packages = cfg.fonts;

      # Nix registry shortcuts
      nix.registry = lib.mkIf cfg.nixRegistry.enableShortcuts (lib.mkMerge [
        (lib.mkIf (config ? inputs && config.inputs ? ${cfg.nixRegistry.stablePath}) {
          n.to = {
            type = "path";
            path = config.inputs.${cfg.nixRegistry.stablePath};
          };
        })

        (lib.mkIf (config ? inputs && config.inputs ? ${cfg.nixRegistry.unstablePath}) {
          u.to = {
            type = "path";
            path = config.inputs.${cfg.nixRegistry.unstablePath};
          };
        })
      ]);
    }
    // cfg.extraConfig;
}
