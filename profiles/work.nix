{
  config,
  lib,
  ...
}: {
  # Work-specific configuration profile
  # This profile is optimized for professional work environments
  # Suitable for: corporate environments, team collaboration, work-focused setups

  # Work environment services (nix-daemon is managed automatically)

  # Work-focused system packages
  environment.systemPackages = with lib; [
    # Work-specific tools can be added here
  ];

  # Work environment variables
  environment.variables = {
    EDITOR = lib.mkForce "nvim";
    # Work-specific environment variables
  };

  # Work-specific system preferences
  system.defaults = {
    dock = {
      autohide = lib.mkDefault true; # Clean workspace
      show-recents = lib.mkDefault false; # Professional appearance
    };

    finder = {
      ShowPathbar = lib.mkDefault true; # Enhanced file navigation
      ShowStatusBar = lib.mkDefault true;
    };
  };
}
