{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.modules.darwin.activation;
in {
  options.modules.darwin.activation = {
    enable = lib.mkEnableOption "Darwin system activation scripts";

    displayResolution = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable automatic display resolution setting";
      };

      mode = lib.mkOption {
        type = lib.types.int;
        default = 13;
        description = "Display mode to set (13 = 2560x1600 for MacBook)";
      };

      displayId = lib.mkOption {
        type = lib.types.int;
        default = 1;
        description = "Display ID to configure";
      };
    };

    customScripts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Custom activation scripts to run";
    };

    extraConfig = lib.mkOption {
      type = lib.types.attrs;
      default = {};
      description = "Additional activation configuration";
    };
  };

  config =
    lib.mkIf cfg.enable {
      system.activationScripts.extraActivation.text = lib.concatStringsSep "\n" (
        lib.optionals cfg.displayResolution.enable [
          ''
            # Set display to maximum resolution using displayplacer
            echo "Setting display to maximum resolution..."
            if command -v displayplacer >/dev/null 2>&1; then
              # Set MacBook built-in screen to maximum resolution
              displayplacer "id:${toString cfg.displayResolution.displayId} mode:${toString cfg.displayResolution.mode} degree:0" 2>/dev/null || {
                echo "Warning: Failed to set display resolution with contextual ID, this is normal on first run"
              }
            else
              echo "displayplacer not found, skipping display configuration"
            fi
          ''
        ]
        ++ cfg.customScripts
      );
    }
    // cfg.extraConfig;
}
