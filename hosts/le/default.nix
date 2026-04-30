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
  # Host config for "le".
  # Software loadout (Homebrew, dev tools, UI prefs) lives in the profiles
  # enabled by flake.nix#darwinConfigurations.le. Anything below should be
  # genuinely host-specific.

  imports = [
    ../common/default.nix
  ];

  # Host identification
  networking.hostName = "le";
  networking.computerName = "le";

  # User configuration (host owner)
  users.users.le = {
    home = "/Users/le";
    description = "Apinant U-suwantim";
  };

  # Set primary user for system-wide activation
  system.primaryUser = "le";

  # Set this MacBook's built-in display to its native resolution.
  # mode 13 (2560x1600) is correct for THIS machine — different MacBook =
  # different display ID and mode. Re-derive with `displayplacer list`.
  system.activationScripts.extraActivation.text = ''
    echo "Setting display to maximum resolution..."
    if command -v displayplacer >/dev/null 2>&1; then
      displayplacer "id:1 mode:13 degree:0" 2>/dev/null || {
        echo "Warning: Failed to set display resolution with contextual ID, this is normal on first run"
      }
    else
      echo "displayplacer not found, skipping display configuration"
    fi
  '';
}
