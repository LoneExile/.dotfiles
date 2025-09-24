# Module Template
# This file serves as a template for creating new modules in the configuration.
# Copy this file and modify it according to your module's needs.
{
  config,
  lib,
  pkgs,
  ...
}: let
  # Define the configuration path for this module
  # Replace 'category.modulename' with your actual module path
  cfg = config.modules.category.modulename;
in {
  # Module options definition
  options.modules.category.modulename = {
    # Enable option - every module should have this
    enable = lib.mkEnableOption "description of what this module provides";

    # Package option - for modules that install software
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.defaultPackage; # Replace with actual default package
      description = "Package to use for this module";
    };

    # Settings option - for module-specific configuration
    settings = lib.mkOption {
      type = lib.types.attrs;
      default = {};
      description = "Additional settings for this module";
      example = lib.literalExpression ''
        {
          option1 = "value1";
          option2 = true;
        }
      '';
    };

    # Extra configuration option - for advanced users
    extraConfig = lib.mkOption {
      type = lib.types.attrs;
      default = {};
      description = "Extra configuration options passed directly to the underlying service";
    };

    # Example of a boolean option
    enableFeature = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable optional feature";
    };

    # Example of a string option with validation
    configPath = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/.config/modulename";
      description = "Path to configuration directory";
    };

    # Example of a list option
    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [];
      description = "Additional packages to install with this module";
    };
  };

  # Module implementation
  config = lib.mkIf cfg.enable {
    # Add your module implementation here
    # This section should only be evaluated when the module is enabled

    # Example: Install packages
    # home.packages = [ cfg.package ] ++ cfg.extraPackages;

    # Example: Create configuration files
    # home.file.".config/modulename/config.conf".text = ''
    #   # Generated configuration
    #   ${lib.generators.toINI {} cfg.settings}
    # '';

    # Example: Enable services
    # systemd.user.services.modulename = {
    #   description = "Module Name Service";
    #   serviceConfig = {
    #     ExecStart = "${cfg.package}/bin/modulename";
    #   };
    # } // cfg.extraConfig;

    # Example: Conditional configuration
    # programs.modulename = lib.mkIf cfg.enableFeature {
    #   enable = true;
    #   settings = cfg.settings;
    # };
  };
}
