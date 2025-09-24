{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.modules.darwin.homebrew;
in {
  options.modules.darwin.homebrew = {
    enable = lib.mkEnableOption "Homebrew package management";

    brews = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "bitwarden-cli"
        "displayplacer"
        "gh"
      ];
      description = "List of Homebrew packages to install";
    };

    casks = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "audacity"
        "discord"
        "firefox"
        "flameshot"
        "font-fira-code"
        "font-fira-code-nerd-font"
        "font-fira-mono-for-powerline"
        "font-hack-nerd-font"
        "font-jetbrains-mono-nerd-font"
        "font-meslo-lg-nerd-font"
        "google-chrome"
        "iina"
        "obs"
        "raycast"
        "signal"
        "slack"
        "spotify"
        "tailscale"
        "nordvpn"
        "mtmr"
        "raspberry-pi-imager"
        "brave-browser"
        "trex"
        "numi"
        "postman"
        "telegram"
        "anki"
        "mongodb-compass"
        "openvpn-connect"
        "cloudflare-warp"
        "kiro"
        "vnc-viewer"
        "visual-studio-code"
      ];
      description = "List of Homebrew casks to install";
    };

    taps = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "List of Homebrew taps to add";
    };

    masApps = lib.mkOption {
      type = lib.types.attrsOf lib.types.int;
      default = {
        "Bitwarden" = 1352778147;
        "Keynote" = 409183694;
        "Numbers" = 409203825;
        "Pages" = 409201541;
        "Line" = 539883307;
        "Amphetamine" = 937984704;
        "Dropover" = 1355679052;
        "Runcat" = 1429033973;
      };
      description = "Mac App Store applications to install";
    };

    onActivation = {
      cleanup = lib.mkOption {
        type = lib.types.enum ["none" "uninstall" "zap"];
        default = "zap";
        description = "Cleanup strategy for Homebrew on activation";
      };

      autoUpdate = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Auto-update Homebrew on activation";
      };

      upgrade = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Upgrade packages on activation";
      };
    };

    global = {
      autoUpdate = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable global auto-update for Homebrew";
      };
    };

    extraConfig = lib.mkOption {
      type = lib.types.attrs;
      default = {};
      description = "Additional Homebrew configuration";
    };
  };

  config = lib.mkIf cfg.enable {
    homebrew =
      {
        enable = true;

        brews = cfg.brews;
        casks = cfg.casks;
        taps = cfg.taps ++ (builtins.attrNames config.nix-homebrew.taps or {});
        masApps = cfg.masApps;

        onActivation = {
          cleanup = cfg.onActivation.cleanup;
          autoUpdate = cfg.onActivation.autoUpdate;
          upgrade = cfg.onActivation.upgrade;
        };

        global.autoUpdate = cfg.global.autoUpdate;
      }
      // cfg.extraConfig;
  };
}
