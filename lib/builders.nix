{
  inputs,
  outputs,
  stateVersion,
  ...
}: let
  inherit (inputs.nixpkgs) lib;
in {
  # Enhanced mkDarwin function with modular system support
  mkDarwin = {
    hostname,
    username ? "le",
    system ? "aarch64-darwin",
    modules ? [],
    profiles ? {},
    extraSpecialArgs ? {},
  }: let
    unstablePkgs = inputs.nixpkgs-unstable.legacyPackages.${system};

    # Load host-specific configuration if it exists
    hostConfigPath = ../hosts/${hostname};
    hostConfig =
      if builtins.pathExists hostConfigPath
      then [(hostConfigPath + "/default.nix")]
      else [];

    # Load common configuration
    commonConfig = [
      ../hosts/common/default.nix
    ];

    # Load profile modules based on enabled profiles
    profileModules = lib.flatten (lib.mapAttrsToList (
        profileName: enabled:
          if enabled
          then [../profiles/${profileName}.nix]
          else []
      )
      profiles);

    # Combine all modules
    allModules =
      commonConfig
      ++ hostConfig
      ++ profileModules
      ++ modules
      ++ [
        # Core system configuration
        {
          networking.hostName = hostname;

          # Add nodejs overlay to fix build issues
          nixpkgs.overlays = [
            (final: prev: {
              nodejs = prev.nodejs_22;
              nodejs-slim = prev.nodejs-slim_22;
            })
            inputs.neovim-nightly-overlay.overlays.default
          ];

          # Enable Nix flakes and new command interface
          nix.settings = {
            experimental-features = ["nix-command" "flakes"];
            trusted-users = [username "root"];
          };

          # System state version
          system.stateVersion = 5;
        }

        # SOPS integration for secrets management
        inputs.sops-nix.darwinModules.sops

        # Home Manager integration
        inputs.home-manager.darwinModules.home-manager
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            backupFileExtension = "backup";
            extraSpecialArgs =
              {
                inherit inputs unstablePkgs;
              }
              // extraSpecialArgs;
            users.${username} = {
              imports = [../home/${username}.nix];

              # Home Manager state version
              home.stateVersion = "24.11";
            };
          };
        }

        # Homebrew integration
        inputs.nix-homebrew.darwinModules.nix-homebrew
        {
          nix-homebrew = {
            enable = true;
            enableRosetta = true;
            autoMigrate = true;
            mutableTaps = true;
            user = username;
            taps = with inputs; {
              "homebrew/homebrew-core" = homebrew-core;
              "homebrew/homebrew-cask" = homebrew-cask;
              "homebrew/homebrew-bundle" = homebrew-bundle;
            };
          };
        }
      ];
  in
    inputs.nix-darwin.lib.darwinSystem {
      inherit system;
      specialArgs =
        {
          inherit system inputs username unstablePkgs;
        }
        // extraSpecialArgs;
      modules = allModules;
    };

  # Create configuration profiles with predefined feature sets
  mkProfile = {
    name,
    description ? "Configuration profile: ${name}",
    modules ? [],
    enabledFeatures ? {},
    settings ? {},
  }: {
    inherit name description;

    config = {
      config,
      lib,
      pkgs,
      ...
    }: {
      imports = modules;

      # Apply feature toggles
      options = lib.mkMerge (lib.mapAttrsToList (
          featurePath: enabled:
            lib.setAttrByPath (lib.splitString "." featurePath) (lib.mkDefault enabled)
        )
        enabledFeatures);

      # Apply profile-specific settings
      config = lib.mkMerge [
        settings
        {
          # Profile metadata
          system.profile = {
            name = name;
            description = description;
          };
        }
      ];
    };
  };

  # Helper for creating consistent module definitions
  mkModule = {
    name,
    description ? "Module: ${name}",
    category ? "custom",
    options ? {},
    config ? {},
    imports ? [],
    extraOptions ? {},
  }: {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = lib.getAttrFromPath (lib.splitString "." "modules.${category}.${name}") config;

    # Standard module options
    standardOptions = {
      enable = lib.mkEnableOption description;

      package = lib.mkOption {
        type = lib.types.nullOr lib.types.package;
        default = null;
        description = "Package to use for ${name}. Set to null to use default.";
      };

      settings = lib.mkOption {
        type = lib.types.attrs;
        default = {};
        description = "Additional settings for ${name}";
      };

      extraConfig = lib.mkOption {
        type = lib.types.attrs;
        default = {};
        description = "Extra configuration options for ${name}";
      };
    };

    # Merge with custom options
    allOptions = lib.recursiveUpdate standardOptions (options // extraOptions);
  in {
    inherit imports;

    options =
      lib.setAttrByPath
      (lib.splitString "." "modules.${category}.${name}")
      allOptions;

    config = lib.mkIf cfg.enable (lib.mkMerge [
      config
      cfg.extraConfig
      {
        # Module metadata
        system.modules.${category}.${name} = {
          enabled = true;
          description = description;
          package = cfg.package;
        };
      }
    ]);
  };
}
