# Template for creating validated modules
# Copy this file and replace the placeholders with your module-specific values
#
# Placeholders to replace:
# - CATEGORY: Module category (darwin, home, shared)
# - MODULE_NAME: Name of your module
# - MODULE_DESCRIPTION: Description of what the module does
# - DEPENDENCIES: List of required modules (optional)
# - CONFLICTS: List of conflicting modules (optional)
# - PLATFORMS: List of supported platforms (optional)
{
  config,
  lib,
  pkgs,
  validation ? null,
  ...
}: let
  cfg = config.modules.CATEGORY.MODULE_NAME;

  # Module validation rules
  moduleValidation = {
    dependencies = [
      # "modules.other.required-module"
    ];
    conflicts = [
      # "modules.other.conflicting-module"
    ];
    platforms = [
      # "aarch64-darwin"
      # "x86_64-darwin"
      # "aarch64-linux"
      # "x86_64-linux"
    ];
    customValidation = cfg: {
      # Add custom validation logic here
      # Return { valid = true/false; errors = []; }
      valid = true;
      errors = [];
    };
  };

  # Perform module-specific validation
  moduleValidationResult =
    if validation != null
    then moduleValidation.customValidation cfg
    else {
      valid = true;
      errors = [];
    };
in {
  options.modules.CATEGORY.MODULE_NAME = {
    enable = lib.mkEnableOption "MODULE_DESCRIPTION";

    # Standard options that most modules should have
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.defaultPackage; # Replace with actual default package
      description = "Package to use for MODULE_DESCRIPTION";
    };

    settings = lib.mkOption {
      type = lib.types.attrs;
      default = {};
      description = "Configuration settings for MODULE_DESCRIPTION";
    };

    extraConfig = lib.mkOption {
      type = lib.types.attrs;
      default = {};
      description = "Additional configuration options for MODULE_DESCRIPTION";
    };

    # Add module-specific options here
    # Example:
    # customOption = lib.mkOption {
    #   type = lib.types.str;
    #   default = "default-value";
    #   description = "Description of custom option";
    # };
  };

  config = lib.mkMerge [
    # Validation assertions
    {
      assertions = lib.mkIf cfg.enable (
        # Standard dependency/conflict assertions
        (map (dep: {
            assertion = (lib.getAttrFromPath (lib.splitString "." dep) config).enable or false;
            message = "Module 'modules.CATEGORY.MODULE_NAME' requires '${dep}' to be enabled";
          })
          moduleValidation.dependencies)
        ++ (map (conflict: {
            assertion = !((lib.getAttrFromPath (lib.splitString "." conflict) config).enable or false);
            message = "Module 'modules.CATEGORY.MODULE_NAME' conflicts with '${conflict}' - both cannot be enabled";
          })
          moduleValidation.conflicts)
        ++
        # Custom validation assertions
        (
          if !moduleValidationResult.valid
          then
            map (error: {
              assertion = false;
              message = "Module validation error in 'modules.CATEGORY.MODULE_NAME': ${error}";
            })
            moduleValidationResult.errors
          else []
        )
      );
    }

    # Main module implementation
    (lib.mkIf cfg.enable {
      # Add your module implementation here
      # Example:
      # programs.someProgram = {
      #   enable = true;
      #   package = cfg.package;
      #   settings = cfg.settings;
      # } // cfg.extraConfig;

      # For home-manager modules:
      # home.packages = [ cfg.package ];

      # For darwin modules:
      # system.defaults.someSettings = cfg.settings;

      # For shared modules:
      # environment.systemPackages = [ cfg.package ];
    })
  ];

  # Module metadata for documentation and validation
  meta.modules.CATEGORY.MODULE_NAME = {
    description = "MODULE_DESCRIPTION";
    category = "CATEGORY";
    dependencies = moduleValidation.dependencies;
    conflicts = moduleValidation.conflicts;
    platforms = moduleValidation.platforms;

    # Documentation
    documentation = ''
      # MODULE_NAME Module

      MODULE_DESCRIPTION

      ## Options

      - `enable`: Enable MODULE_DESCRIPTION
      - `package`: Package to use for MODULE_DESCRIPTION
      - `settings`: Configuration settings
      - `extraConfig`: Additional configuration options

      ## Dependencies

      ${lib.concatStringsSep "\n" (map (dep: "- ${dep}") moduleValidation.dependencies)}

      ## Conflicts

      ${lib.concatStringsSep "\n" (map (conflict: "- ${conflict}") moduleValidation.conflicts)}

      ## Supported Platforms

      ${lib.concatStringsSep "\n" (map (platform: "- ${platform}") moduleValidation.platforms)}

      ## Example Usage

      ```nix
      modules.CATEGORY.MODULE_NAME = {
        enable = true;
        # Add example configuration here
      };
      ```
    '';
  };
}
