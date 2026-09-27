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
  # Identity (hostname, computerName, user, home) comes from flake.nix `hosts`
  # and hosts/common; the software loadout from the profiles enabled in
  # flake.nix. Anything below should be genuinely host-specific.

  imports = [
    ../common/default.nix
  ];

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
