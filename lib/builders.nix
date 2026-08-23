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
    system ? "aarch64-darwin",
    modules ? [],
    profiles ? {},
    extraSpecialArgs ? {},
  }: let
    # Darwin build workarounds.
    #   - libcdio-paranoia 2.0.2: bundled src/getopt.{h,c} declare K&R-style
    #     `extern int getopt ();` / `extern char *getenv ();` which under clang's
    #     default -std=gnu23 mean `(void)` and conflict with the macOS SDK
    #     prototypes. Drop the stray declarations; unistd.h/stdlib.h provide them.
    #   - kvazaar / chromaprint: CTest invokes ffmpeg helpers that get SIGKILL'd
    #     inside the Darwin sandbox. Skip the check phase.
    #   - direnv: its `make test-go test-bash test-fish test-zsh` check phase
    #     runs `test/direnv-test.zsh` which hangs forever inside the Nix sandbox
    #     (no terminal/PROMPT_COMMAND). Skip checks.
    #   - obsidian: 1.13.x DMGs name their HFS volume "Obsidian <version>-universal",
    #     so 7zz extracts the app under that volume-label directory. The pinned
    #     derivation hardcodes sourceRoot = "Obsidian.app" and copies "." into the
    #     app dir, which breaks on the new layout. Mirror upstream's fix: drop the
    #     hardcoded sourceRoot and copy the app bundle by name.
    #   - frei0r-plugins: the new nixpkgs package pulls gavl, but gavl 2.0.1
    #     does not build on darwin (configure hard-requires glibc's getaddrinfo_a,
    #     and its buildInputs list libdrm, which is Linux-only). gavl is optional
    #     for frei0r (WITHOUT_GAVL), so disable it on darwin — matching the
    #     pre-gavl-init behavior of the old nixpkgs pin.
    #   - curl-impersonate: upstream ships @rpath/libcurl-impersonate.4.dylib
    #     and the package never ran fixDarwinDylibNames. curl-cffi (yt-dlp dep)
    #     then records that @rpath with no LC_RPATH and dies at pythonImportsCheck
    #     ("no LC_RPATH's found"). Mirror nixpkgs#554592: rewrite the install
    #     name to the absolute store path. curl-cffi 0.15.0 then fails one WS
    #     send test (unaligned 500k frame); 0.16.0 fixes it but breaks yt-dlp
    #     2026.07.04 (nixpkgs#554405). Skip that test until the pin moves.
    #     Drop both once nixpkgs-unstable carries #554592 + a compatible bump.
    darwinBuildFixes = final: prev: {
      libcdio-paranoia = prev.libcdio-paranoia.overrideAttrs (old: {
        postPatch =
          (old.postPatch or "")
          + ''
            sed -i '/^extern int getopt ();$/d' src/getopt.h
            sed -i '/^extern char \*getenv ();$/d' src/getopt.c
          '';
      });
      kvazaar = prev.kvazaar.overrideAttrs (_: {
        doCheck = !prev.stdenv.hostPlatform.isDarwin;
      });
      chromaprint = prev.chromaprint.overrideAttrs (_: {
        doCheck = !prev.stdenv.hostPlatform.isDarwin;
      });
      direnv = prev.direnv.overrideAttrs (_: {
        doCheck = !prev.stdenv.hostPlatform.isDarwin;
      });
      obsidian = prev.obsidian.overrideAttrs (_: {
        sourceRoot = null;
        installPhase = ''
          runHook preInstall
          mkdir -p $out/{Applications,bin}
          cp -R Obsidian.app $out/Applications
          makeWrapper $out/Applications/Obsidian.app/Contents/MacOS/Obsidian $out/bin/obsidian
          makeWrapper $out/Applications/Obsidian.app/Contents/MacOS/obsidian-cli $out/bin/obsidian-cli
          runHook postInstall
        '';
      });
      frei0r = prev.frei0r.overrideAttrs (old: {
        buildInputs =
          if prev.stdenv.hostPlatform.isDarwin
          then
            builtins.filter
            (p: !(lib.hasPrefix "gavl-" (p.name or "")))
            (old.buildInputs or [])
          else old.buildInputs;
        cmakeFlags =
          (old.cmakeFlags or [])
          ++ lib.optionals prev.stdenv.hostPlatform.isDarwin [
            "-DWITHOUT_GAVL=ON"
          ];
      });
      curl-impersonate = prev.curl-impersonate.overrideAttrs (old: {
        nativeBuildInputs =
          (old.nativeBuildInputs or [])
          ++ lib.optionals prev.stdenv.hostPlatform.isDarwin [
            prev.fixDarwinDylibNames
          ];
      });
      pythonPackagesExtensions =
        prev.pythonPackagesExtensions
        ++ [
          (pyfinal: pyprev:
            lib.optionalAttrs (pyprev ? curl-cffi) {
              curl-cffi = pyprev.curl-cffi.overrideAttrs (old: {
                disabledTests =
                  (old.disabledTests or [])
                  ++ [
                    "test_large_message_echo"
                  ];
              });
            })
        ];
    };

    unstablePkgs = import inputs.nixpkgs-unstable {
      inherit system;
      config.allowUnfree = true;
      overlays = [darwinBuildFixes];
    };

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

          # Auto-derive user identity from the username arg so host files
          # don't have to. Host files may still override `description`.
          users.users.${username} = {
            home = "/Users/${username}";
          };
          system.primaryUser = username;

          # Add nodejs overlay to fix build issues
          nixpkgs.overlays = [
            (final: prev: {
              nodejs = prev.nodejs_22;
              nodejs-slim = prev.nodejs-slim_22;
            })
            darwinBuildFixes
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
              "steveyegge/homebrew-beads" = homebrew-steveyegge-beads;
              "telepresenceio/homebrew-telepresence" = homebrew-telepresenceio-telepresence;
              "AlexsJones/homebrew-llmfit" = homebrew-alexsjones-llmfit;
              "xykong/homebrew-tap" = homebrew-xykong-tap;
              "zennotes/homebrew-tap" = homebrew-zennotes-tap;
              "BarutSRB/homebrew-tap" = homebrew-barutsrb-tap;
              "zseven-w/homebrew-openpencil" = homebrew-zseven-w-openpencil;
              "kgarner7/homebrew-feishin" = homebrew-kgarner7-feishin;
              "abue-ammar/homebrew-tinycast" = homebrew-abue-ammar-tinycast;
            };

            # Declarative tap trust for third-party taps (required by newer Homebrew).
            # Without this, `brew bundle` refuses to load casks/formulae from untrusted taps.
            # See: https://docs.brew.sh/Tap-Trust
            trust = {
              taps = [
                "steveyegge/beads"
                "telepresenceio/telepresence"
                "AlexsJones/llmfit"
                "xykong/tap"
                "zennotes/tap"
                "BarutSRB/tap"
                "zseven-w/openpencil"
                "kgarner7/feishin"
                "abue-ammar/tinycast"
              ];
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
