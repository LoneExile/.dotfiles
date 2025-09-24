{ config, lib, pkgs, ... }:
let
  cfg = config.modules.darwin.security;
in {
  options.modules.darwin.security = {
    enable = lib.mkEnableOption "Darwin security configuration";
    
    touchId = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable TouchID for sudo authentication";
    };
    
    reattach = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable reattach for TouchID authentication";
    };
    
    quarantine = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable quarantine for new applications (Are you sure? dialog)";
    };
    
    guestUser = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable guest user account";
    };
    
    extraConfig = lib.mkOption {
      type = lib.types.attrs;
      default = {};
      description = "Additional security configuration";
    };
  };
  
  config = lib.mkIf cfg.enable {
    # TouchID configuration for sudo
    security.pam.services.sudo_local = {
      touchIdAuth = cfg.touchId;
      reattach = cfg.reattach;
    };
    
    # System security defaults
    system.defaults = {
      LaunchServices.LSQuarantine = cfg.quarantine;
      loginwindow.GuestEnabled = cfg.guestUser;
    };
  } // cfg.extraConfig;
}