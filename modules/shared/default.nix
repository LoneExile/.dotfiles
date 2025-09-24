{
  lib,
  config,
  pkgs,
  ...
}: {
  # Shared module imports
  imports = [
    ./fonts.nix
    ./networking.nix
    ./validation.nix
    ./diagnostics.nix
  ];
}
