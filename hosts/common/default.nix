{
  config,
  lib,
  pkgs,
  ...
}: {
  # Common configuration shared across all hosts
  # This file contains base settings that apply to all machines

  # Import all module categories
  imports = [
    # Temporarily disabled to fix circular dependency
    # ../../modules/darwin
    # ../../modules/shared
  ];

  # Common system settings
  system = {
    stateVersion = lib.mkDefault 5;
  };

  # Common Nix settings
  nix = {
    settings = {
      experimental-features = ["nix-command" "flakes"];
      warn-dirty = false;
    };

    optimise.automatic = true;

    gc = {
      automatic = true;
      interval = {
        Weekday = 0;
        Hour = 2;
        Minute = 0;
      };
      options = "--delete-older-than 30d";
    };

    channel.enable = false;
  };

  # Common nixpkgs configuration
  nixpkgs = {
    config.allowUnfree = true;
  };

  # Common programs
  programs = {
    nix-index.enable = true;
    zsh = {
      enable = true;
      enableCompletion = true;
    };
  };

  # Profile selection is handled through imports in host configurations
}
