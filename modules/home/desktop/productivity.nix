{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.modules.home.desktop.productivity;
in {
  options.modules.home.desktop.productivity = {
    enable = lib.mkEnableOption "Productivity applications";

    mtmr = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable My TouchBar My Rules";
    };
  };

  config = lib.mkIf cfg.enable {
    # Productivity applications configuration will be implemented in later tasks
  };
}
