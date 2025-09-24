{
  inputs,
  outputs,
  stateVersion,
  ...
}: let
  inherit (inputs.nixpkgs) lib;
in {
  # File management utilities
  fileUtils = {
    # Check if a file exists and is readable
    fileExists = path: builtins.pathExists path && builtins.readFileType path == "regular";

    # Check if a directory exists
    dirExists = path: builtins.pathExists path && builtins.readFileType path == "directory";

    # Safely read a file with fallback
    readFileSafe = path: fallback:
      if builtins.pathExists path
      then builtins.readFile path
      else fallback;

    # Import a Nix file if it exists, otherwise return default
    importIfExists = path: default:
      if builtins.pathExists path
      then import path
      else default;

    # Get all .nix files in a directory
    getNixFiles = dir:
      if builtins.pathExists dir
      then lib.filter (name: lib.hasSuffix ".nix" name) (builtins.attrNames (builtins.readDir dir))
      else [];

    # Import all .nix files from a directory as a list
    importNixFiles = dir: let
      nixFiles = fileUtils.getNixFiles dir;
    in
      map (file: import (dir + "/${file}")) nixFiles;
  };

  # Configuration merging utilities
  configUtils = {
    # Deep merge configurations with conflict resolution
    mergeConfigs = configs:
      lib.foldl' (acc: config: lib.recursiveUpdate acc config) {} configs;

    # Merge configurations with priority (later configs override earlier ones)
    mergeConfigsWithPriority = configs:
      lib.foldl' lib.recursiveUpdate {} configs;

    # Merge attribute sets but concatenate lists instead of replacing
    mergeWithLists = left: right:
      lib.recursiveUpdate left (lib.mapAttrs (
          name: value:
            if lib.isList value && lib.hasAttr name left && lib.isList left.${name}
            then left.${name} ++ value
            else value
        )
        right);

    # Filter configuration by enabled modules
    filterByEnabled = config: enabledModules:
      lib.filterAttrsRecursive (
        path: value:
          if lib.hasAttr "enable" value
          then value.enable or false
          else true
      )
      config;

    # Apply overrides to a configuration
    applyOverrides = baseConfig: overrides:
      lib.recursiveUpdate baseConfig overrides;

    # Extract module configuration by path
    getModuleConfig = config: modulePath:
      lib.getAttrFromPath (lib.splitString "." modulePath) config;
  };

  # Validation functions for module configurations
  validation = {
    # Validate that required options are set
    validateRequired = config: requiredPaths: let
      missing =
        lib.filter (
          path:
            !(lib.hasAttrByPath (lib.splitString "." path) config)
        )
        requiredPaths;
    in
      if missing == []
      then {
        valid = true;
        errors = [];
      }
      else {
        valid = false;
        errors = map (path: "Required option '${path}' is missing") missing;
      };

    # Validate module dependencies
    validateDependencies = config: dependencies: let
      checkDep = dep: let
        modulePath = lib.splitString "." dep.module;
        moduleConfig = lib.getAttrFromPath modulePath config;
      in
        if moduleConfig.enable or false
        then {
          valid = true;
          error = null;
        }
        else {
          valid = false;
          error = "Module '${dep.module}' is required but not enabled";
        };

      results = map checkDep dependencies;
      errors = lib.filter (r: !r.valid) results;
    in
      if errors == []
      then {
        valid = true;
        errors = [];
      }
      else {
        valid = false;
        errors = map (e: e.error) errors;
      };

    # Validate that conflicting modules are not both enabled
    validateConflicts = config: conflicts: let
      checkConflict = conflict: let
        module1Enabled = (lib.getAttrFromPath (lib.splitString "." conflict.module1) config).enable or false;
        module2Enabled = (lib.getAttrFromPath (lib.splitString "." conflict.module2) config).enable or false;
      in
        if module1Enabled && module2Enabled
        then {
          valid = false;
          error = "Modules '${conflict.module1}' and '${conflict.module2}' conflict and cannot both be enabled";
        }
        else {
          valid = true;
          error = null;
        };

      results = map checkConflict conflicts;
      errors = lib.filter (r: !r.valid) results;
    in
      if errors == []
      then {
        valid = true;
        errors = [];
      }
      else {
        valid = false;
        errors = map (e: e.error) errors;
      };

    # Comprehensive configuration validation
    validateConfig = config: validationRules: let
      requiredResult = validation.validateRequired config (validationRules.required or []);
      depsResult = validation.validateDependencies config (validationRules.dependencies or []);
      conflictsResult = validation.validateConflicts config (validationRules.conflicts or []);

      allErrors = requiredResult.errors ++ depsResult.errors ++ conflictsResult.errors;
    in {
      valid = requiredResult.valid && depsResult.valid && conflictsResult.valid;
      errors = allErrors;
      summary =
        if allErrors == []
        then "Configuration is valid"
        else "Configuration has ${toString (lib.length allErrors)} error(s)";
    };
  };

  # Helper functions for common Nix operations
  nixUtils = {
    # Create an option with a default value and description
    mkDefaultOption = type: default: description: {
      inherit type default description;
    };

    # Create an enable option with description
    mkEnableOption = description: lib.mkEnableOption description;

    # Create a package option with default
    mkPackageOption = pkgs: packageName: description:
      lib.mkOption {
        type = lib.types.package;
        default = lib.getAttrFromPath (lib.splitString "." packageName) pkgs;
        description = description;
      };

    # Create a string option with validation
    mkStringOption = default: description: validation:
      lib.mkOption {
        type = lib.types.strMatching validation;
        inherit default description;
      };

    # Create a list option with element type
    mkListOption = elementType: default: description:
      lib.mkOption {
        type = lib.types.listOf elementType;
        inherit default description;
      };

    # Create an attribute set option
    mkAttrsOption = default: description:
      lib.mkOption {
        type = lib.types.attrs;
        inherit default description;
      };

    # Conditionally include configuration
    mkIf = condition: config: lib.mkIf condition config;

    # Merge multiple configurations
    mkMerge = configs: lib.mkMerge configs;

    # Set attribute by path safely
    setAttrByPath = path: value: attrs:
      lib.recursiveUpdate attrs (lib.setAttrByPath path value);

    # Get attribute by path with default
    getAttrByPath = path: default: attrs:
      if lib.hasAttrByPath path attrs
      then lib.getAttrFromPath path attrs
      else default;
  };

  # System utilities
  systemUtils = {
    # Get system architecture
    getSystemArch = system:
      if lib.hasPrefix "aarch64" system
      then "arm64"
      else if lib.hasPrefix "x86_64" system
      then "x64"
      else "unknown";

    # Check if system is Darwin (macOS)
    isDarwin = system: lib.hasSuffix "darwin" system;

    # Check if system is Linux
    isLinux = system: lib.hasSuffix "linux" system;

    # Get platform-specific configuration
    getPlatformConfig = system: configs:
      if systemUtils.isDarwin system
      then configs.darwin or {}
      else if systemUtils.isLinux system
      then configs.linux or {}
      else configs.default or {};
  };

  # Module utilities for standardized module creation
  moduleUtils = {
    # Create a standard module with consistent options
    mkModule = {
      name,
      category,
      description,
      defaultPackage ? null,
      extraOptions ? {},
    }: {
      config,
      lib,
      pkgs,
      ...
    }: let
      cfg = lib.getAttrFromPath (lib.splitString "." "modules.${category}.${name}") config;

      # Standard options that every module should have
      standardOptions = {
        enable = lib.mkEnableOption description;

        package = lib.mkIf (defaultPackage != null) (lib.mkOption {
          type = lib.types.package;
          default = defaultPackage;
          description = "Package to use for ${description}";
        });

        settings = lib.mkOption {
          type = lib.types.attrs;
          default = {};
          description = "Configuration settings for ${description}";
        };

        extraConfig = lib.mkOption {
          type = lib.types.attrs;
          default = {};
          description = "Additional configuration options for ${description}";
        };
      };

      # Merge standard options with module-specific options
      allOptions = lib.recursiveUpdate standardOptions extraOptions;
    in {
      options = lib.setAttrByPath (lib.splitString "." "modules.${category}.${name}") allOptions;
    };

    # Validate module structure
    validateModuleStructure = modulePath: moduleConfig: let
      hasEnable = lib.hasAttr "enable" moduleConfig;
      hasValidEnable = hasEnable && lib.isBool moduleConfig.enable;

      errors = lib.flatten [
        (lib.optional (!hasEnable) "Module '${modulePath}' missing required 'enable' option")
        (lib.optional (hasEnable && !hasValidEnable) "Module '${modulePath}' 'enable' option must be boolean")
      ];
    in {
      valid = errors == [];
      inherit errors;
    };

    # Create module assertions for dependencies and conflicts
    mkModuleAssertions = cfg: modulePath: {
      dependencies ? [],
      conflicts ? [],
      customAssertions ? [],
    }: let
      # Dependency assertions
      depAssertions =
        map (dep: {
          assertion = !cfg.enable || (lib.getAttrFromPath (lib.splitString "." dep) config).enable or false;
          message = "Module '${modulePath}' requires '${dep}' to be enabled";
        })
        dependencies;

      # Conflict assertions
      conflictAssertions = lib.flatten (map (conflict: {
          assertion = !cfg.enable || !((lib.getAttrFromPath (lib.splitString "." conflict) config).enable or false);
          message = "Module '${modulePath}' conflicts with '${conflict}' - both cannot be enabled";
        })
        conflicts);

      # All assertions
      allAssertions = depAssertions ++ conflictAssertions ++ customAssertions;
    in
      lib.mkIf cfg.enable {
        assertions = allAssertions;
      };

    # Helper to create consistent module documentation
    mkModuleDoc = {
      name,
      description,
      category,
      options ? {},
      examples ? [],
      notes ? [],
    }: let
      optionDocs =
        lib.mapAttrsToList (
          optName: optConfig: "- `${optName}`: ${optConfig.description or "No description provided"}"
        )
        options;

      exampleDocs =
        map (
          example: "```nix\n${example}\n```"
        )
        examples;

      noteDocs = map (note: "- ${note}") notes;
    in ''
      # ${name} Module

      ${description}

      **Category:** ${category}

      ## Options

      ${lib.concatStringsSep "\n" optionDocs}

      ${lib.optionalString (examples != []) ''
        ## Examples

        ${lib.concatStringsSep "\n\n" exampleDocs}
      ''}

      ${lib.optionalString (notes != []) ''
        ## Notes

        ${lib.concatStringsSep "\n" noteDocs}
      ''}
    '';

    # Create a module with standard validation and documentation
    mkStandardModule = {
      name,
      category,
      description,
      implementation,
      dependencies ? [],
      conflicts ? [],
      extraOptions ? {},
      examples ? [],
      notes ? [],
    }: {
      config,
      lib,
      pkgs,
      ...
    }: let
      modulePath = "modules.${category}.${name}";
      cfg = lib.getAttrFromPath (lib.splitString "." modulePath) config;

      # Standard options
      standardOptions = {
        enable = lib.mkEnableOption description;

        settings = lib.mkOption {
          type = lib.types.attrs;
          default = {};
          description = "Configuration settings for ${description}";
        };

        extraConfig = lib.mkOption {
          type = lib.types.attrs;
          default = {};
          description = "Additional configuration options for ${description}";
        };
      };

      # Module documentation
      moduleDoc = moduleUtils.mkModuleDoc {
        inherit name description category examples notes;
        options = lib.recursiveUpdate standardOptions extraOptions;
      };
    in {
      # Module options
      options =
        lib.setAttrByPath (lib.splitString "." modulePath)
        (lib.recursiveUpdate standardOptions extraOptions);

      # Module implementation with validation
      config = lib.mkMerge [
        # Assertions for dependencies and conflicts
        (moduleUtils.mkModuleAssertions cfg modulePath {
          inherit dependencies conflicts;
        })

        # Main module implementation
        (lib.mkIf cfg.enable implementation)
      ];

      # Module metadata (for documentation generation)
      meta.modules.${category}.${name} = {
        inherit description dependencies conflicts;
        documentation = moduleDoc;
      };
    };
  };

  # Debug and logging utilities
  debugUtils = {
    # Debug print with context
    debugPrint = context: value:
      builtins.trace "[DEBUG:${context}] ${builtins.toJSON value}" value;

    # Warn about deprecated options
    warnDeprecated = oldOption: newOption: value:
      lib.warn "Option '${oldOption}' is deprecated, use '${newOption}' instead" value;

    # Assert condition with message
    assertMsg = condition: message: value:
      assert lib.assertMsg condition message; value;

    # Validate and trace configuration
    traceConfig = name: config:
      builtins.trace "Configuration for ${name}: ${builtins.toJSON config}" config;
  };
}
