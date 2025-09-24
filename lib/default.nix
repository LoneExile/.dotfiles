{
  inputs,
  outputs,
  stateVersion,
  ...
}: let
  builders = import ./builders.nix {inherit inputs outputs stateVersion;};
  utils = import ./utils.nix {inherit inputs outputs stateVersion;};
  validation = import ./validation.nix {inherit inputs outputs stateVersion;};
  errorHandling = import ./error-handling.nix {inherit inputs outputs stateVersion;};
  integration = import ./integration.nix {inherit inputs outputs stateVersion;};
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

  # Enhanced validation system
  inherit
    (validation)
    moduleValidation
    configValidation
    validationAssertions
    ;

  # Error handling and diagnostics
  inherit
    (errorHandling)
    errorHandling
    diagnostics
    debug
    recovery
    ;

  # Integration utilities
  inherit
    (integration)
    mkValidatedDarwin
    withValidation
    safeImportModule
    checkConfigHealth
    devUtils
    ;

  # Integration recovery utilities (renamed to avoid conflict)
  integrationRecovery = integration.recovery;
}
