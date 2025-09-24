{
  lib,
  config,
  pkgs,
  ...
}: {
  # Security module imports
  imports = [
    ./gpg.nix
    ./ssh.nix
  ];
}
