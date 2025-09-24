{ config, lib, pkgs, ... }:
let
  cfg = config.modules.darwin.system;
in {
  options.modules.darwin.system = {
    enable = lib.mkEnableOption "Darwin system configuration";
    
    hostname = lib.mkOption {
      type = lib.types.str;
      default = "darwin-system";
      description = "System hostname";
    };
    
    stateVersion = lib.mkOption {
      type = lib.types.int;
      default = 5;
      description = "Darwin system state version";
    };
    
    primaryUser = lib.mkOption {
      type = lib.types.str;
      default = "le";
      description = "Primary user for system-wide activation";
    };
    
    allowUnfree = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Allow unfree packages";
    };
    
    keyboard = {
      enableKeyMapping = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable keyboard key mapping";
      };
      
      remapCapsLockToEscape = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Remap Caps Lock to Escape";
      };
    };
    
    nix = {
      enableFlakes = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Nix flakes and nix-command";
      };
      
      warnDirty = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Warn about dirty Git repositories";
      };
      
      enableChannel = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Nix channels";
      };
    };
    
    programs = {
      enableZsh = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Zsh shell system-wide";
      };
      
      enableNixIndex = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable nix-index for command-not-found";
      };
    };
    
    extraConfig = lib.mkOption {
      type = lib.types.attrs;
      default = {};
      description = "Additional system configuration";
    };
  };
  
  config = lib.mkIf cfg.enable {
    # Basic system configuration
    system.stateVersion = cfg.stateVersion;
    system.primaryUser = cfg.primaryUser;
    
    # User configuration
    users.users.${cfg.primaryUser}.home = "/Users/${cfg.primaryUser}";
    
    # Nix configuration
    nix = {
      settings = {
        experimental-features = lib.mkIf cfg.nix.enableFlakes [ "nix-command" "flakes" ];
        warn-dirty = cfg.nix.warnDirty;
      };
      channel.enable = cfg.nix.enableChannel;
    };
    
    # Nixpkgs configuration
    nixpkgs = {
      config.allowUnfree = cfg.allowUnfree;
      hostPlatform = lib.mkDefault config.nixpkgs.system;
    };
    
    # Keyboard configuration
    system.keyboard = {
      enableKeyMapping = cfg.keyboard.enableKeyMapping;
      remapCapsLockToEscape = cfg.keyboard.remapCapsLockToEscape;
    };
    
    # Programs
    programs.zsh = lib.mkIf cfg.programs.enableZsh {
      enable = true;
      enableCompletion = true;
    };
    
    programs.nix-index.enable = cfg.programs.enableNixIndex;
    
    # Apply extra configuration
  } // cfg.extraConfig;
}