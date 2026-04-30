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

  imports = [
    ../common/default.nix
  ];

  # Host identification
  networking.hostName = "lex";
  networking.computerName = "lex";

  # User configuration
  users.users.USERNAME = {
    home = "/Users/lex";
    description = "Apinant U-suwantim";
  };

  # Set primary user for system-wide activation
  system.primaryUser = "lex";

}
