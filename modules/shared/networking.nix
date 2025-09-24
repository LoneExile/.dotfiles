{ config, lib, pkgs, ... }:
let
  cfg = config.modules.shared.networking;
in {
  options.modules.shared.networking = {
    enable = lib.mkEnableOption "Networking configuration";
    
    dns = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "DNS servers to use";
    };
  };
  
  config = lib.mkIf cfg.enable {
    # Networking configuration will be implemented in later tasks
  };
}