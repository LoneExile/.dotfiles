{
  config,
  lib,
  ...
}: {
  # Full development environment profile
  # This profile includes comprehensive development tools and environments
  # Suitable for: software developers, DevOps engineers, full-stack development

  # Enable development services (nix-daemon is managed automatically)

  # Development-focused system packages
  environment.systemPackages = with lib; [
    # Additional development tools can be specified here
  ];

  # Development environment variables
  environment.variables = {
    EDITOR = lib.mkForce "nvim";
    BROWSER = lib.mkForce "open";
  };
}
