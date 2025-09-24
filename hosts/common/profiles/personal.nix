{
  config,
  lib,
  ...
}: {
  # Personal host profile configuration
  # This profile is optimized for personal use and hobby development

  imports = [
    ../../../profiles/personal.nix
  ];

  # Personal-specific host overrides
  # These settings optimize for personal comfort and customization

  # Personal environment variables
  environment.variables = {
    EDITOR = lib.mkForce "nvim";
    PERSONAL_MODE = "true";
  };

  # Personal system settings
  system.defaults = {
    dock = {
      autohide = lib.mkDefault false; # Personal preference for visibility
      show-recents = lib.mkDefault true; # Convenient for personal use
      magnification = lib.mkDefault true; # Visual enhancement
      tilesize = lib.mkDefault 48; # Larger icons for personal comfort
    };

    finder = {
      ShowPathbar = lib.mkDefault true;
      ShowStatusBar = lib.mkDefault true;
      AppleShowAllExtensions = lib.mkDefault true; # Power user preference
    };

    # Personal trackpad and mouse settings
    trackpad = {
      Clicking = lib.mkDefault true; # Tap to click
      TrackpadThreeFingerDrag = lib.mkDefault true; # Three finger drag
    };
  };

  # Personal security settings (more relaxed than work)
  security.pam.services.sudo_local = {
    touchIdAuth = lib.mkDefault true;
    reattach = lib.mkDefault true;
  };

  # Personal-specific system preferences
  system.keyboard = {
    enableKeyMapping = lib.mkDefault true;
    remapCapsLockToEscape = lib.mkDefault false; # Personal preference
  };
}
