{
  config,
  lib,
  pkgs,
  inputs,
  outputs,
  hostname,
  system,
  username,
  unstablePkgs,
  ...
}: {
  # Optional host-only settings template.
  #
  # A new Mac needs only an entry in flake.nix `hosts`:
  #   <hostname> = {username = "<id -un on that Mac>";};
  # That sets networking.hostName, networking.computerName (defaults to the
  # hostname), users.users.<username>.home (/Users/<username>),
  # system.primaryUser, the owner's full name, Home Manager, Homebrew and nix
  # trusted-users. Copy this directory only for settings that belong to one
  # machine:
  #   cp -r hosts/_template hosts/<hostname>
  # Use the `username` / `hostname` module args instead of literal names.

  imports = [
    ../common/default.nix
  ];

  # Display name in System Settings → About, if not the hostname (optional)
  # networking.computerName = "Alice's MacBook Pro";

  # Host-specific system packages (optional)
  environment.systemPackages = with pkgs; [
    # Add host-specific packages here
  ];

  # Host-specific fonts (optional)
  fonts.packages = with pkgs; [
    # Add host-specific fonts here
  ];

  # Extra Homebrew apps for this Mac only (the personal profile enables
  # Homebrew and lists the shared ones in profiles/personal.nix) (optional)
  # homebrew.casks = ["some-app"];

  # Host-specific macOS defaults (optional, overrides profile defaults)
  system.defaults = {
    # NSGlobalDomain.AppleInterfaceStyle = "Dark";
  };

  # Host-specific activation scripts (optional)
  # system.activationScripts.extraActivation.text = ''
  #   echo "Host-specific activation for ${hostname}"
  # '';
}
