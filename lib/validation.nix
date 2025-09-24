{
  inputs,
  outputs,
  stateVersion,
  ...
}: let
  inherit (inputs.nixpkgs) lib;

  # Module validation system
  moduleValidation = {
    # Define validation rules for modules
    validationRules = {
      # Core module structure requirements
      coreStructure = {
        required = [
          "enable"
        ];
        optionalStandard = [
          "package"
          "settings"
          "extraConfig"
        ];
      };

      # Module dependencies and conflicts
      dependencies = {
        # Darwin modules dependencies
        "modules.darwin.homebrew" = {
          requires = [];
          conflicts = [];
          platforms = ["aarch64-darwin" "x86_64-darwin"];
        };

        "modules.darwin.security" = {
          requires = [];
          conflicts = [];
          platforms = ["aarch64-darwin" "x86_64-darwin"];
        };

        # Home modules dependencies
        "modules.home.development.git" = {
          requires = [];
          conflicts = [];
          platforms = ["aarch64-darwin" "x86_64-darwin" "aarch64-linux" "x86_64-linux"];
        };

        "modules.home.development.editors" = {
          requires = [];
          conflicts = [];
          platforms = ["aarch64-darwin" "x86_64-darwin" "aarch64-linux" "x86_64-linux"];
        };

        "modules.home.shell.zsh" = {
          requires = [];
          conflicts = ["modules.home.shell.bash" "modules.home.shell.fish"];
          platforms = ["aarch64-darwin" "x86_64-darwin" "aarch64-linux" "x86_64-linux"];
        };

        "modules.home.desktop.terminal" = {
          requires = ["modules.home.shell.zsh"];
          conflicts = [];
          platforms = ["aarch64-darwin" "x86_64-darwin"];
        };

        "modules.home.desktop.window-manager" = {
          requires = [];
          conflicts = [];
          platforms = ["aarch64-darwin"];
        };

        # Security modules
        "modules.home.security.gpg" = {
          requires = [];
          conflicts = [];
          platforms = ["aarch64-darwin" "x86_64-darwin" "aarch64-linux" "x86_64-linux"];
        };

        "modules.home.security.ssh" = {
          requires = [];
          conflicts = [];
          platforms = ["aarch64-darwin" "x86_64-darwin" "aarch64-linux" "x86_64-linux"];
        };
      };

      # Platform-specific validation rules
      platformRules = {
        "aarch64-darwin" = {
          allowedModules = [
            "modules.darwin.*"
            "modules.home.*"
            "modules.shared.*"
          ];
          requiredModules = [];
        };

        "x86_64-darwin" = {
          allowedModules = [
            "modules.darwin.*"
            "modules.home.*"
            "modules.shared.*"
          ];
          requiredModules = [];
        };

        "aarch64-linux" = {
          allowedModules = [
            "modules.home.*"
            "modules.shared.*"
          ];
          requiredModules = [];
        };

        "x86_64-linux" = {
          allowedModules = [
            "modules.home.*"
            "modules.shared.*"
          ];
          requiredModules = [];
        };
      };
    };

    # Validate individual module structure
    validateModuleStructure = modulePath: moduleConfig: let
      rules = moduleValidation.validationRules.coreStructure;

      # Check required fields
      missingRequired =
        lib.filter (
          field:
            !(lib.hasAttr field moduleConfig)
        )
        rules.required;

      # Check enable field type
      enableTypeError =
        if lib.hasAttr "enable" moduleConfig && !(lib.isBool moduleConfig.enable)
        then ["Field 'enable' must be boolean"]
        else [];

      # Check package field type if present
      packageTypeError =
        if lib.hasAttr "package" moduleConfig && !(lib.isDerivation moduleConfig.package)
        then ["Field 'package' must be a derivation"]
        else [];

      # Check settings field type if present
      settingsTypeError =
        if lib.hasAttr "settings" moduleConfig && !(lib.isAttrs moduleConfig.settings)
        then ["Field 'settings' must be an attribute set"]
        else [];

      allErrors = lib.flatten [
        (map (field: "Missing required field: ${field}") missingRequired)
        enableTypeError
        packageTypeError
        settingsTypeError
      ];
    in {
      valid = allErrors == [];
      errors = allErrors;
      modulePath = modulePath;
    };

    # Validate module dependencies
    validateModuleDependencies = config: system: let
      rules = moduleValidation.validationRules.dependencies;

      # Get all enabled modules
      enabledModules = let
        collectEnabledModules = path: value:
          if lib.isAttrs value && lib.hasAttr "enable" value && value.enable
          then [path]
          else if lib.isAttrs value
          then
            lib.flatten (lib.mapAttrsToList (
                name: subValue:
                  collectEnabledModules "${path}.${name}" subValue
              )
              value)
          else [];
      in
        lib.flatten (lib.mapAttrsToList (
          name: value:
            collectEnabledModules "modules.${name}" value
        ) (config.modules or {}));

      # Check each enabled module's dependencies
      checkModuleDeps = modulePath: moduleConfig: let
        moduleRules =
          rules.${modulePath}
          or {
            requires = [];
            conflicts = [];
            platforms = [];
          };

        # Check platform compatibility
        platformErrors =
          if moduleRules.platforms != [] && !(lib.elem system moduleRules.platforms)
          then ["Module '${modulePath}' is not supported on platform '${system}'"]
          else [];

        # Check required dependencies
        depErrors = lib.flatten (map (
            dep: let
              depConfig = lib.getAttrFromPath (lib.splitString "." dep) config;
            in
              if !(depConfig.enable or false)
              then ["Module '${modulePath}' requires '${dep}' to be enabled"]
              else []
          )
          moduleRules.requires);

        # Check conflicts
        conflictErrors = lib.flatten (map (
            conflict: let
              conflictConfig = lib.getAttrFromPath (lib.splitString "." conflict) config;
            in
              if conflictConfig.enable or false
              then ["Module '${modulePath}' conflicts with '${conflict}' - both cannot be enabled"]
              else []
          )
          moduleRules.conflicts);
      in
        platformErrors ++ depErrors ++ conflictErrors;

      # Collect all dependency errors
      allErrors = lib.flatten (lib.mapAttrsToList (
        path: moduleConfig:
          if lib.isAttrs moduleConfig && moduleConfig.enable or false
          then checkModuleDeps path moduleConfig
          else []
      ) (config.modules or {}));
    in {
      valid = allErrors == [];
      errors = allErrors;
    };

    # Validate platform-specific module usage
    validatePlatformModules = config: system: let
      platformRules =
        moduleValidation.validationRules.platformRules.${system}
        or {
          allowedModules = [];
          requiredModules = [];
        };

      # Get all enabled modules
      enabledModulePaths = let
        collectEnabledModules = path: value:
          if lib.isAttrs value && lib.hasAttr "enable" value && value.enable
          then [path]
          else if lib.isAttrs value
          then
            lib.flatten (lib.mapAttrsToList (
                name: subValue:
                  collectEnabledModules "${path}.${name}" subValue
              )
              value)
          else [];
      in
        lib.flatten (lib.mapAttrsToList (
          name: value:
            collectEnabledModules "modules.${name}" value
        ) (config.modules or {}));

      # Check if module is allowed on this platform
      checkModuleAllowed = modulePath: let
        isAllowed =
          lib.any (
            pattern:
              lib.hasPrefix (lib.removeSuffix "*" pattern) modulePath
              || modulePath == pattern
          )
          platformRules.allowedModules;
      in
        if !isAllowed
        then ["Module '${modulePath}' is not allowed on platform '${system}'"]
        else [];

      # Check required modules are enabled
      checkRequiredModules = lib.flatten (map (
          requiredModule: let
            moduleConfig = lib.getAttrFromPath (lib.splitString "." requiredModule) config;
          in
            if !(moduleConfig.enable or false)
            then ["Required module '${requiredModule}' is not enabled for platform '${system}'"]
            else []
        )
        platformRules.requiredModules);

      # Collect all platform errors
      allowedErrors = lib.flatten (map checkModuleAllowed enabledModulePaths);
      allErrors = allowedErrors ++ checkRequiredModules;
    in {
      valid = allErrors == [];
      errors = allErrors;
    };

    # Comprehensive module validation
    validateAllModules = config: system: let
      # Validate each module's structure
      structureResults = lib.mapAttrsToList (
        category: modules:
          lib.mapAttrsToList (
            name: moduleConfig:
              moduleValidation.validateModuleStructure "modules.${category}.${name}" moduleConfig
          )
          modules
      ) (config.modules or {});

      # Flatten structure results
      flatStructureResults = lib.flatten (lib.flatten structureResults);

      # Validate dependencies
      depResult = moduleValidation.validateModuleDependencies config system;

      # Validate platform compatibility
      platformResult = moduleValidation.validatePlatformModules config system;

      # Collect all errors
      structureErrors = lib.flatten (map (result: result.errors) flatStructureResults);
      allErrors = structureErrors ++ depResult.errors ++ platformResult.errors;

      # Categorize errors
      errorsByCategory = {
        structure = structureErrors;
        dependencies = depResult.errors;
        platform = platformResult.errors;
      };
    in {
      valid = allErrors == [];
      errors = allErrors;
      errorsByCategory = errorsByCategory;
      summary = {
        totalErrors = lib.length allErrors;
        structureErrors = lib.length structureErrors;
        dependencyErrors = lib.length depResult.errors;
        platformErrors = lib.length platformResult.errors;
      };
    };
  };

  # Configuration validation utilities
  configValidation = let
    # Validate host configuration
    validateHostConfig = hostConfig: system: let
      # Check required host fields
      requiredFields = ["hostname" "system" "username"];
      missingFields =
        lib.filter (
          field:
            !(lib.hasAttr field hostConfig)
        )
        requiredFields;

      # Validate system field
      systemError =
        if lib.hasAttr "system" hostConfig && hostConfig.system != system
        then ["Host system '${hostConfig.system}' does not match actual system '${system}'"]
        else [];

      # Validate hostname format
      hostnameError =
        if
          lib.hasAttr "hostname" hostConfig
          && !(lib.isString hostConfig.hostname)
          || hostConfig.hostname == ""
        then ["Hostname must be a non-empty string"]
        else [];

      # Validate username format
      usernameError =
        if
          lib.hasAttr "username" hostConfig
          && !(lib.isString hostConfig.username)
          || hostConfig.username == ""
        then ["Username must be a non-empty string"]
        else [];

      allErrors = lib.flatten [
        (map (field: "Missing required field: ${field}") missingFields)
        systemError
        hostnameError
        usernameError
      ];
    in {
      valid = allErrors == [];
      errors = allErrors;
    };

    # Validate profile configuration
    validateProfileConfig = profileConfig: let
      # Check that profiles is an attribute set
      profilesError =
        if
          lib.hasAttr "profiles" profileConfig
          && !(lib.isAttrs profileConfig.profiles)
        then ["Profiles must be an attribute set"]
        else [];

      # Validate individual profile settings
      profileErrors = lib.flatten (lib.mapAttrsToList (
        name: profile:
          if lib.isAttrs profile && lib.hasAttr "enable" profile
          then
            if !(lib.isBool profile.enable)
            then ["Profile '${name}' enable field must be boolean"]
            else []
          else ["Profile '${name}' must have an 'enable' field"]
      ) (profileConfig.profiles or {}));

      allErrors = profilesError ++ profileErrors;
    in {
      valid = allErrors == [];
      errors = allErrors;
    };

    # Comprehensive configuration validation
    validateFullConfig = config: system: let
      # Validate host configuration
      hostResult = validateHostConfig config system;

      # Validate profile configuration
      profileResult = validateProfileConfig config;

      # Validate modules
      moduleResult = moduleValidation.validateAllModules config system;

      # Collect all errors
      allErrors = hostResult.errors ++ profileResult.errors ++ moduleResult.errors;
    in {
      valid = allErrors == [];
      errors = allErrors;
      results = {
        host = hostResult;
        profiles = profileResult;
        modules = moduleResult;
      };
      summary = {
        totalErrors = lib.length allErrors;
        hostErrors = lib.length hostResult.errors;
        profileErrors = lib.length profileResult.errors;
        moduleErrors = lib.length moduleResult.errors;
      };
    };
  in {
    inherit validateHostConfig validateProfileConfig validateFullConfig;
  };

  # Validation assertion helpers
  validationAssertions = {
    # Create assertions from validation results
    mkValidationAssertions = validationResult:
      map (error: {
        assertion = false;
        message = "Configuration validation error: ${error}";
      })
      validationResult.errors;

    # Create warnings from validation results
    mkValidationWarnings = validationResult: warnings:
      map (
        warning:
          lib.warn "Configuration warning: ${warning}" null
      )
      warnings;

    # Assert configuration is valid
    assertValidConfig = config: system: let
      result = configValidation.validateFullConfig config system;
    in
      assert lib.assertMsg result.valid
      "Configuration validation failed with ${toString result.summary.totalErrors} errors:\n${lib.concatStringsSep "\n" result.errors}"; config;
  };
in {
  # Export all validation utilities
  inherit moduleValidation configValidation validationAssertions;
}
