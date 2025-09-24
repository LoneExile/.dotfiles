# Test data generators and fixtures
{
  lib,
  pkgs,
  ...
}: let
  # Generate test configurations for different scenarios
  generateTestConfig = {
    hostname ? "test-host",
    username ? "test-user",
    system ? "aarch64-darwin",
    profiles ? {},
    modules ? {},
    extraConfig ? {},
  }:
    {
      inherit hostname username system profiles modules;
    }
    // extraConfig;

  # Generate test module configurations
  generateTestModule = {
    name,
    category ? "test",
    enable ? true,
    settings ? {},
    extraOptions ? {},
  }: {
    ${category}.${name} =
      {
        inherit enable;
        inherit settings;
      }
      // extraOptions;
  };

  # Common test fixtures
  fixtures = {
    # Basic host configurations
    hosts = {
      minimal = generateTestConfig {
        hostname = "minimal-test";
        profiles.minimal.enable = true;
      };

      development = generateTestConfig {
        hostname = "dev-test";
        profiles.development.enable = true;
      };

      work = generateTestConfig {
        hostname = "work-test";
        profiles.work.enable = true;
      };

      personal = generateTestConfig {
        hostname = "personal-test";
        profiles.personal.enable = true;
      };

      full = generateTestConfig {
        hostname = "full-test";
        profiles = {
          minimal.enable = true;
          development.enable = true;
          work.enable = true;
          personal.enable = true;
        };
      };
    };

    # Module configurations
    modules = {
      darwin = {
        system = generateTestModule {
          name = "system";
          category = "darwin";
          settings = {
            hostname = "test-system";
            stateVersion = 5;
          };
        };

        homebrew = generateTestModule {
          name = "homebrew";
          category = "darwin";
          settings = {
            brews = ["git" "curl"];
            casks = ["firefox"];
          };
        };

        security = generateTestModule {
          name = "security";
          category = "darwin";
          settings = {
            touchId = true;
          };
        };
      };

      home = {
        zsh = generateTestModule {
          name = "zsh";
          category = "home.shell";
          settings = {
            enableAutosuggestions = true;
            historySize = 10000;
          };
        };

        git = generateTestModule {
          name = "git";
          category = "home.development";
          settings = {
            userName = "Test User";
            userEmail = "test@example.com";
          };
        };

        terminal = generateTestModule {
          name = "terminal";
          category = "home.desktop";
          settings = {
            defaultTerminal = "wezterm";
          };
        };
      };
    };

    # Profile combinations
    profileCombinations = {
      single = [
        {minimal.enable = true;}
        {development.enable = true;}
        {work.enable = true;}
        {personal.enable = true;}
      ];

      pairs = [
        {
          minimal.enable = true;
          development.enable = true;
        }
        {
          development.enable = true;
          work.enable = true;
        }
        {
          work.enable = true;
          personal.enable = true;
        }
        {
          development.enable = true;
          personal.enable = true;
        }
      ];

      triples = [
        {
          minimal.enable = true;
          development.enable = true;
          work.enable = true;
        }
        {
          development.enable = true;
          work.enable = true;
          personal.enable = true;
        }
        {
          minimal.enable = true;
          development.enable = true;
          personal.enable = true;
        }
      ];

      all = [
        {
          minimal.enable = true;
          development.enable = true;
          work.enable = true;
          personal.enable = true;
        }
      ];
    };
  };

  # Generate test data for specific scenarios
  scenarios = {
    # Generate upgrade path test data
    generateUpgradePath = startConfig: steps: let
      applyStep = config: step: lib.recursiveUpdate config step;
    in
      lib.foldl applyStep startConfig steps;

    # Generate module combination test data
    generateModuleCombinations = moduleList: let
      # Generate all possible combinations of modules
      combinations = lib.genList (
        i:
          lib.genList (
            j:
              if lib.bitAnd i (lib.bitShiftL 1 j) != 0
              then lib.elemAt moduleList j
              else null
          ) (lib.length moduleList)
      ) (lib.bitShiftL 1 (lib.length moduleList));

      # Filter out null values and empty combinations
      validCombinations = map (combo: lib.filter (x: x != null) combo) combinations;
      nonEmptyCombinations = lib.filter (combo: combo != []) validCombinations;
    in
      nonEmptyCombinations;

    # Generate performance test configurations
    generatePerformanceConfigs = baseConfig: complexityLevels:
      map (
        level:
          baseConfig
          // {
            hostname = "${baseConfig.hostname}-${level.name}";
            modules = level.modules;
            profiles = level.profiles or {};
          }
      )
      complexityLevels;

    # Generate error test cases
    generateErrorCases = {
      invalidHostnames = [
        ""
        "invalid hostname with spaces"
        "hostname-with-@-symbols"
        "very-long-hostname-that-exceeds-reasonable-limits-and-should-cause-issues"
      ];

      invalidUsernames = [
        ""
        "user with spaces"
        "user@domain"
        "root" # Potentially problematic
      ];

      invalidSystems = [
        "invalid-system"
        "linux"
        "windows"
        "x86_64-linux" # Wrong for Darwin-only config
      ];

      invalidModuleConfigs = [
        {enable = "not-a-boolean";}
        {
          enable = true;
          package = "not-a-package";
        }
        {
          enable = true;
          settings = "not-an-attrs";
        }
      ];
    };
  };

  # Test data validation
  validation = {
    # Validate that test configuration is well-formed
    validateTestConfig = config: let
      hasRequiredFields =
        lib.hasAttr "hostname" config
        && lib.hasAttr "username" config
        && lib.hasAttr "system" config;

      validTypes =
        lib.isString config.hostname
        && lib.isString config.username
        && lib.isString config.system;

      validProfiles =
        if lib.hasAttr "profiles" config
        then lib.isAttrs config.profiles
        else true;

      validModules =
        if lib.hasAttr "modules" config
        then lib.isAttrs config.modules
        else true;
    in {
      valid = hasRequiredFields && validTypes && validProfiles && validModules;
      errors = lib.flatten [
        (lib.optional (!hasRequiredFields) "Missing required fields")
        (lib.optional (!validTypes) "Invalid field types")
        (lib.optional (!validProfiles) "Invalid profiles structure")
        (lib.optional (!validModules) "Invalid modules structure")
      ];
    };

    # Validate test module configuration
    validateTestModule = moduleConfig: let
      hasEnable = lib.hasAttr "enable" moduleConfig;
      enableIsBoolean = hasEnable && lib.isBool moduleConfig.enable;

      settingsValid =
        if lib.hasAttr "settings" moduleConfig
        then lib.isAttrs moduleConfig.settings
        else true;
    in {
      valid = hasEnable && enableIsBoolean && settingsValid;
      errors = lib.flatten [
        (lib.optional (!hasEnable) "Missing enable field")
        (lib.optional (!enableIsBoolean) "Enable field must be boolean")
        (lib.optional (!settingsValid) "Settings must be attribute set")
      ];
    };
  };
in {
  inherit generateTestConfig generateTestModule fixtures scenarios validation;
}
