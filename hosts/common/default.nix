{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: {
  # Common configuration shared across all hosts.
  # Anything that should be true on every Mac in this flake lives here.
  # Host-specific identity and display setup goes in hosts/<name>/default.nix.
  # Per-loadout software/UI preferences go in profiles/<name>.nix.

  # System state version
  system.stateVersion = lib.mkDefault 5;

  # Nix daemon settings
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

    # Convenience registry shortcuts: `nix run n#hello`, `nix run u#hello`
    registry = {
      n.to = {
        type = "path";
        path = inputs.nixpkgs;
      };
      u.to = {
        type = "path";
        path = inputs.nixpkgs-unstable;
      };
    };
  };

  # Common nixpkgs configuration
  nixpkgs = {
    config.allowUnfree = true;
  };

  # Common shell
  programs = {
    nix-index.enable = false;
    zsh.enable = true;
  };

  # Use TouchID for sudo (any Mac with a Touch Bar / Touch ID sensor)
  security.pam.services.sudo_local.touchIdAuth = true;
  security.pam.services.sudo_local.reattach = true;

  # Keyboard
  system.keyboard.enableKeyMapping = true;
  system.keyboard.remapCapsLockToEscape = false;

  # Common typing/UI tweaks that apply on every Mac
  system.defaults.NSGlobalDomain = {
    InitialKeyRepeat = lib.mkDefault 25;
    KeyRepeat = lib.mkDefault 2;
    ApplePressAndHoldEnabled = lib.mkDefault false;
    NSAutomaticSpellingCorrectionEnabled = lib.mkDefault false;
    NSUseAnimatedFocusRing = lib.mkDefault false;
    AppleShowAllExtensions = lib.mkDefault true;
    AppleShowAllFiles = lib.mkDefault true;
    AppleFontSmoothing = lib.mkDefault 2;
    NSWindowShouldDragOnGesture = lib.mkDefault true;
    "com.apple.swipescrolldirection" = lib.mkDefault false;
    "com.apple.mouse.tapBehavior" = lib.mkDefault 1;
  };
}
