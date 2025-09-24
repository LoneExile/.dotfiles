{
  lib,
  config,
  pkgs,
  ...
}: {
  # Development module imports
  imports = [
    ./git.nix
    ./editors
    ./languages.nix
    ./containers.nix
  ];
}
