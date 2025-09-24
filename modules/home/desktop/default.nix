{
  lib,
  config,
  pkgs,
  ...
}: {
  # Desktop module imports
  imports = [
    ./terminal.nix
    ./window-manager.nix
    ./productivity.nix
  ];
}
