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
  # Host configuration template.
  #
  # To create a new host:
  #   1. Copy this directory:  cp -r hosts/_template hosts/<your-hostname>
  #   2. Replace HOSTNAME / USERNAME / "Full Name" below with real values.
  #   3. Register the host in flake.nix under darwinConfigurations:
  #        <your-hostname> = lib.mkDarwin {
  #          hostname = "<your-hostname>";
  #          username = "<your-username>";
  #          system = "aarch64-darwin";  # or "x86_64-darwin"
  #          profiles = { development = true; personal = true; };
  #        };
  #   4. Build:  just build <your-hostname>
  #   5. Switch: just switch <your-hostname>

  imports = [
    ../common/default.nix
  ];

  # `networking.hostName`, `users.users.<username>.home`, and
  # `system.primaryUser` are set automatically by lib.mkDarwin from the
  # hostname/username args you pass in flake.nix. You only need to set
  # display-name overrides like the two below.
  networking.computerName = "HOSTNAME"; # what shows in System Settings → About
  users.users.USERNAME.description = "Full Name";

  # Host-specific system packages (optional)
  environment.systemPackages = with pkgs; [
    # Add host-specific packages here
  ];

  # Host-specific fonts (optional)
  fonts.packages = with pkgs; [
    # Add host-specific fonts here
  ];

  # Host-specific Homebrew configuration (optional)
  # See hosts/le/default.nix for an example with brews/casks/taps.
  homebrew = {
    enable = false;
  };

  # Host-specific macOS defaults (optional, overrides profile defaults)
  system.defaults = {
    # NSGlobalDomain.AppleInterfaceStyle = "Dark";
  };

  # Host-specific activation scripts (optional)
  # system.activationScripts.extraActivation.text = ''
  #   echo "Host-specific activation for HOSTNAME"
  # '';
}
