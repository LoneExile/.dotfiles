{
  config,
  lib,
  ...
}: {
  # Minimal profile with essential tools only
  # This profile provides the bare minimum for a functional macOS system
  # Suitable for: servers, CI environments, or users who prefer minimal setups

  # Disable non-essential services by default (nix-daemon is managed automatically)

  # Minimal system packages
  environment.systemPackages = with lib; [
    # Only include absolutely essential packages
  ];
}
