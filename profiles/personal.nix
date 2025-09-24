{
  config,
  lib,
  ...
}: {
  # Personal use configuration profile
  # This profile is optimized for personal computing and hobby development
  # Suitable for: personal machines, hobby projects, learning environments

  # Personal environment services (nix-daemon is managed automatically)

  # Personal system packages
  environment.systemPackages = with lib; [
    # Personal tools and applications
  ];

  # Personal environment variables
  environment.variables = {
    EDITOR = lib.mkForce "nvim";
    # Personal environment customizations
  };

  # Personal system preferences
  system.defaults = {
    dock = {
      autohide = lib.mkDefault false; # Personal preference
      show-recents = lib.mkDefault true; # Convenient for personal use
      magnification = lib.mkDefault true; # Visual enhancement
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
}
