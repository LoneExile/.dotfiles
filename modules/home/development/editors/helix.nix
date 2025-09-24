{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.modules.home.development.editors;
in {
  options.modules.home.development.editors.helix = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Helix editor";
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.helix;
      description = "Helix package to use";
    };
  };

  config = lib.mkIf (cfg.enable && cfg.helix.enable) {
    # Helix configuration
    programs.helix = {
      enable = true;
      package = cfg.helix.package;

      settings = {
        theme = "catppuccin_mocha";

        editor = {
          line-number = "relative";
          mouse = true;
          cursor-shape = {
            insert = "bar";
            normal = "block";
            select = "underline";
          };

          file-picker = {
            hidden = false;
          };

          auto-save = true;

          indent-guides = {
            render = true;
            character = "┊";
          };
        };

        keys.normal = {
          space.w = ":w";
          space.q = ":q";
          space.x = ":wq";
        };
      };
    };


  };
}