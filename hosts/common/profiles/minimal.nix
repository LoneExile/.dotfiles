{
  config,
  lib,
  ...
}: {
  # Minimal host profile configuration
  # This profile provides only essential functionality

  imports = [
    ../../../profiles/minimal.nix
  ];

  # Enable minimal profile
  config = {
    profiles.minimal.enable = true;

    # Minimal-specific host overrides
    # These settings optimize for minimal resource usage

    # Minimal environment variables
    environment.variables = {
      EDITOR = lib.mkDefault "nano"; # Lightweight editor
    };

    # Minimal system settings
    system.defaults = {
      dock = {
        autohide = lib.mkDefault true; # Save screen space
        show-recents = lib.mkDefault false; # Minimal dock items
        tilesize = lib.mkDefault 32; # Smaller dock icons
      };

      finder = {
        ShowPathbar = lib.mkDefault false; # Minimal UI
        ShowStatusBar = lib.mkDefault false;
      };
    };

    # Disable non-essential services
    services = {
      # Add minimal service configuration here
    };
  };
}
