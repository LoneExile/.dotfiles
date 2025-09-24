{
  config,
  lib,
  ...
}: {
  # Work host profile configuration
  # This profile is optimized for professional work environments

  imports = [
    ../../../profiles/work.nix
  ];

  # Enable work profile
  config = {
    profiles.work.enable = true;

    # Work-specific host overrides
    # These settings optimize for professional productivity

    # Work environment variables
    environment.variables = {
      EDITOR = lib.mkDefault "nvim";
      WORK_MODE = "true";
    };

    # Work-optimized system settings
    system.defaults = {
      dock = {
        autohide = lib.mkDefault true; # Professional clean workspace
        show-recents = lib.mkDefault false; # No personal items in dock
        magnification = lib.mkDefault false; # Professional appearance
      };

      finder = {
        ShowPathbar = lib.mkDefault true; # Enhanced navigation
        ShowStatusBar = lib.mkDefault true;
        AppleShowAllExtensions = lib.mkDefault true; # File type awareness
      };

      # Work-specific trackpad settings
      trackpad = {
        Clicking = lib.mkDefault true; # Efficient interaction
        TrackpadThreeFingerDrag = lib.mkDefault false; # Prevent accidental drags
      };
    };

    # Work-specific security settings
    security.pam.services.sudo_local = {
      touchIdAuth = lib.mkDefault true; # Secure but convenient
      reattach = lib.mkDefault true;
    };
  };
}
