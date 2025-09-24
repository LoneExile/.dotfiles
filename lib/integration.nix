# Integration utilities for error handling and validation
{
  inputs,
  outputs,
  stateVersion,
  ...
}: let
  inherit (inputs.nixpkgs) lib;

  # Import our libraries
  validationLib = import ./validation.nix {inherit inputs outputs stateVersion;};
  errorLib = import ./error-handling.nix {inherit inputs outputs stateVersion;};
in {
  # Enhanced system builder with validation
  mkValidatedDarwin = {
    hostname,
    system,
    username,
    modules ? [],
    extraModules ? [],
    enableValidation ? true,
    validationLevel ? "error", # "error", "warning", "info"
    enableDiagnostics ? true,
  }: let
    # Base configuration
    baseConfig = {
      inherit system;

      modules =
        [
          # Core nix-darwin modules
          inputs.home-manager.darwinModules.home-manager

          # Our custom modules
          ../modules/darwin
          ../modules/home
          ../modules/shared

          # Host-specific configuration
          ../hosts/${hostname}

          # Additional modules
        ]
        ++ modules
        ++ extraModules
        ++ [
          # Always include validation and diagnostics if enabled
          (lib.mkIf enableValidation {
            modules.shared.validation = {
              enable = true;
              enforceValidation = validationLevel == "error";
              generateReport = true;
            };
          })

          (lib.mkIf enableDiagnostics {
            modules.shared.diagnostics = {
              enable = true;
              debugLevel = validationLevel;
              enableHealthCheck = true;
              generateReports = true;
            };
          })

          # System configuration
          {
            networking.hostName = hostname;
            networking.computerName = hostname;

            users.users.${username} = {
              name = username;
              home = "/Users/${username}";
            };

            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              users.${username} = import ../home/${username}.nix;

              # Pass our libraries to home-manager
              extraSpecialArgs = {
                inherit inputs outputs stateVersion;
                validation = validationLib;
                errorHandling = errorLib;
                diagnostics = errorLib.diagnostics;
              };
            };

            # Pass libraries to system modules
            _module.args = {
              inherit inputs outputs stateVersion;
              validation = validationLib;
              errorHandling = errorLib;
              diagnostics = errorLib.diagnostics;
            };
          }
        ];
    };

    # Build the system
    system = inputs.nix-darwin.lib.darwinSystem baseConfig;

    # Add validation metadata
    systemWithValidation =
      system
      // {
        meta =
          (system.meta or {})
          // {
            validation = {
              enabled = enableValidation;
              level = validationLevel;
              diagnostics = enableDiagnostics;
            };
          };
      };
  in
    systemWithValidation;

  # Validation wrapper for any configuration
  withValidation = config: system: validationLevel: let
    # Run validation
    validationResult = validationLib.configValidation.validateFullConfig config system;

    # Create validation assertions based on level
    validationAssertions =
      if validationLevel == "error"
      then validationLib.validationAssertions.mkValidationAssertions validationResult
      else [];

    # Create warnings for non-error levels
    validationWarnings =
      if validationLevel == "warning" && !validationResult.valid
      then map (error: lib.warn "Configuration validation: ${error}" null) validationResult.errors
      else [];
  in
    config
    // {
      # Add assertions if error level
      assertions = (config.assertions or []) ++ validationAssertions;

      # Add warnings
      warnings =
        (config.warnings or [])
        ++ (
          if validationLevel == "warning" && !validationResult.valid
          then ["Configuration has ${toString validationResult.summary.totalErrors} validation issues"]
          else []
        );

      # Add validation metadata
      _module.args =
        (config._module.args or {})
        // {
          validationResult = validationResult;
        };
    };

  # Error-safe module loading
  safeImportModule = path: fallback:
    if builtins.pathExists path
    then let
      result = builtins.tryEval (import path);
    in
      if result.success
      then result.value
      else fallback
    else lib.warn "Module not found: ${path}" fallback;

  # Configuration health checker
  checkConfigHealth = config: system: let
    healthResult = errorLib.diagnostics.healthCheck config system;
  in {
    inherit (healthResult) score status;

    # Add health-based warnings
    warnings =
      if healthResult.score < 50
      then ["Configuration health is poor (${toString healthResult.score}/100)"]
      else if healthResult.score < 75
      then ["Configuration health could be improved (${toString healthResult.score}/100)"]
      else [];

    # Add recommendations as warnings
    recommendations =
      map (
        recommendation:
          lib.warn "Recommendation: ${recommendation}" null
      )
      healthResult.recommendations;
  };

  # Development utilities
  devUtils = {
    # Create development shell with validation tools
    mkDevShell = pkgs: {
      buildInputs = with pkgs; [
        # Nix tools
        nixpkgs-fmt
        nil

        # Validation and diagnostic tools
        jq

        # Custom scripts
        (writeShellScriptBin "validate" ''
          exec ${../scripts/validate-config.sh} "$@"
        '')

        (writeShellScriptBin "diagnose" ''
          exec ${../scripts/diagnose-config.sh} "$@"
        '')

        (writeShellScriptBin "health-check" ''
          exec ${../scripts/diagnose-config.sh} health "$@"
        '')

        (writeShellScriptBin "config-debug" ''
          exec ${../scripts/diagnose-config.sh} debug "$@"
        '')
      ];

      shellHook = ''
        echo "🔧 Nix Configuration Development Environment"
        echo "==========================================="
        echo ""
        echo "Available commands:"
        echo "  validate      - Validate configuration"
        echo "  diagnose      - Run diagnostics"
        echo "  health-check  - Quick health check"
        echo "  config-debug  - Debug specific modules"
        echo ""
        echo "Run 'diagnose --help' for more options"
        echo ""
      '';
    };

    # Create CI/CD checks
    mkChecks = system: configs: let
      pkgs = inputs.nixpkgs.legacyPackages.${system};
    in {
      # Validation check
      validation = pkgs.runCommand "config-validation" {} ''
        echo "Running configuration validation..."

        # Run validation for each config
        ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: config: ''
            echo "Validating ${name}..."
            ${../scripts/validate-config.sh} -H ${name} -s ${system} --no-report
          '')
          configs)}

        touch $out
        echo "All configurations validated successfully"
      '';

      # Health check
      health = pkgs.runCommand "config-health" {} ''
        echo "Running health checks..."

        ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: config: ''
            echo "Health check for ${name}..."
            ${../scripts/diagnose-config.sh} health -H ${name} -s ${system}
          '')
          configs)}

        touch $out
        echo "All health checks passed"
      '';

      # Build test
      build-test = pkgs.runCommand "config-build-test" {} ''
        echo "Testing configuration builds..."

        # Test that configurations can be built
        ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: config: ''
            echo "Testing build for ${name}..."
            nix build --no-link .#darwinConfigurations.${name}.system
          '')
          configs)}

        touch $out
        echo "All configurations build successfully"
      '';
    };
  };

  # Error recovery utilities
  recovery = {
    # Safe configuration merger with error handling
    safeConfigMerge = configs: let
      mergeConfig = acc: config: let
        result = builtins.tryEval (lib.recursiveUpdate acc config);
      in
        if result.success
        then result.value
        else acc;
    in
      lib.foldl' mergeConfig {} configs;

    # Fallback module loader
    loadModuleWithFallback = primary: fallback: let
      result = builtins.tryEval (import primary);
    in
      if result.success
      then result.value
      else (import fallback);

    # Configuration repair suggestions
    suggestConfigRepairs = validationResult: let
      repairMap = {
        "Missing required field" = {
          action = "add-field";
          description = "Add the missing required field to your configuration";
        };
        "conflicts with" = {
          action = "resolve-conflict";
          description = "Disable one of the conflicting modules or resolve the conflict";
        };
        "requires" = {
          action = "enable-dependency";
          description = "Enable the required dependency module";
        };
        "not supported on platform" = {
          action = "remove-module";
          description = "Remove or conditionally disable platform-incompatible modules";
        };
      };

      findRepair = error: let
        matchingKey = lib.findFirst (key: lib.hasInfix key error) null (builtins.attrNames repairMap);
      in
        if matchingKey != null
        then repairMap.${matchingKey}
        else {
          action = "manual-review";
          description = "Manually review the error and configuration";
        };
    in
      map (error: {
        error = error;
        repair = findRepair error;
      })
      validationResult.errors;
  };
}
