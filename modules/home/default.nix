{
  lib,
  config,
  pkgs,
  ...
}: {
  # Home Manager module imports
  imports = [
    ./shell
    ./development
    ./desktop
    ./security
  ];
}
