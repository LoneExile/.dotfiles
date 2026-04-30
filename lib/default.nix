{
  inputs,
  outputs,
  stateVersion,
  ...
}: let
  builders = import ./builders.nix {inherit inputs outputs stateVersion;};
  utils = import ./utils.nix {inherit inputs outputs stateVersion;};
in {
  # Enhanced builders (using the new modular system)
  inherit
    (builders)
    mkDarwin
    mkProfile
    mkModule
    ;

  # Utility functions
  inherit
    (utils)
    fileUtils
    configUtils
    validation
    nixUtils
    systemUtils
    debugUtils
    moduleUtils
    ;
}
