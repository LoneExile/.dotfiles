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
    username,
    # macOS keeps a user's home at /Users/<short name>; pass this only for an
    # account whose home folder is named differently.
    homeDirectory ? "/Users/${username}",
    system ? "aarch64-darwin",
    modules ? [],
    profiles ? {},
    extraSpecialArgs ? {},
  }: let
    unstablePkgs = import inputs.nixpkgs-unstable {
      inherit system;
      config.allowUnfree = true;
    };

    # Load host-specific configuration if it exists (optional per host)
    hostConfigPath = ../hosts/${hostname}/default.nix;
    hostConfig = lib.optional (builtins.pathExists hostConfigPath) hostConfigPath;

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

          # Auto-derive user identity from the username arg so host files
          # don't have to.
          users.users.${username}.home = homeDirectory;
          system.primaryUser = username;

          # Only overlay a package while it is broken upstream, and drop the
          # override once Hydra builds it: overriding a package changes its hash
          # and the hash of every dependent, so none of them are substitutable
          # from the binary cache any more. (A direnv doCheck override plus
          # `nodejs = nodejs_22` compiled mise from source for ~35 min on every
          # nixpkgs bump; kvazaar/libcdio-paranoia overrides did the same to
          # jellyfin-ffmpeg for ~23 min.)
          nixpkgs.overlays = [
            inputs.neovim-nightly-overlay.overlays.default
          ];

          # Enable Nix flakes and new command interface
          nix.settings = {
            experimental-features = ["nix-command" "flakes"];
            trusted-users = [username "root"];

            # Extra binary caches. cache.nixos.org alone has incomplete
            # aarch64-darwin coverage, so uncached unstable packages build
            # from source locally. nix-community covers far more darwin/unstable
            # derivations — cuts most local compiles. Keep cache.nixos.org first.
            substituters = [
              "https://cache.nixos.org"
              "https://nix-community.cachix.org"
            ];
            trusted-public-keys = [
              "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
              "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
            ];
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
              imports = [../home/default.nix];

              # Home Manager state version
              home.stateVersion = "25.11";
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
              "telepresenceio/homebrew-telepresence" = homebrew-telepresenceio-telepresence;
              "AlexsJones/homebrew-llmfit" = homebrew-alexsjones-llmfit;
              "xykong/homebrew-tap" = homebrew-xykong-tap;
              "zennotes/homebrew-tap" = homebrew-zennotes-tap;
              "BarutSRB/homebrew-tap" = homebrew-barutsrb-tap;
              "zseven-w/homebrew-openpencil" = homebrew-zseven-w-openpencil;
              "kgarner7/homebrew-feishin" = homebrew-kgarner7-feishin;
              "abue-ammar/homebrew-tinycast" = homebrew-abue-ammar-tinycast;
              "lightpanda-io/homebrew-browser" = homebrew-lightpanda-io-browser;
            };
          };
        }
      ];
  in
    inputs.nix-darwin.lib.darwinSystem {
      inherit system;
      specialArgs =
        {
          inherit system inputs hostname username unstablePkgs;
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
