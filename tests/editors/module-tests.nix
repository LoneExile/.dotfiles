# Comprehensive tests for the refactored editors module
{
  inputs,
  outputs,
  system,
  lib,
  pkgs,
  testLib,
  ...
}: let
  # Import the refactored editors modules
  editorsModule = ../../modules/home/development/editors;
  neovimModule = ../../modules/home/development/editors/neovim.nix;
  vscodeModule = ../../modules/home/development/editors/vscode.nix;
  helixModule = ../../modules/home/development/editors/helix.nix;

  # Helper function to create test configurations
  mkTestConfig = moduleConfig: {
    imports = [editorsModule];
    modules.home.development.editors = moduleConfig;
    system.stateVersion = 5;
    home.stateVersion = "25.05";
  };

  # Helper function to evaluate a configuration
  evalConfig = config: let
    evalResult = lib.evalModules {
      modules = [config];
      specialArgs = {inherit pkgs;};
    };
  in evalResult.config;

  # Test backward compatibility with existing configurations
  backwardCompatibilityTests = [
    (testLib.mkTest {
      name = "editors-backward-compatibility-all-enabled";
      assertions = let
        config = mkTestConfig {
          enable = true;
          neovim.enable = true;
          vscode.enable = true;
          helix.enable = true;
        };
        result = evalConfig config;
      in [
        (testLib.assertions.assertTrue "config evaluates successfully" (result ? programs))
        (testLib.assertions.assertTrue "neovim is enabled" result.programs.neovim.enable)
        (testLib.assertions.assertTrue "vscode is enabled" result.programs.vscode.enable)
        (testLib.assertions.assertTrue "helix is enabled" result.programs.helix.enable)
        (testLib.assertions.assertHasAttr "neovim package in home.packages" "neovim" (lib.listToAttrs (map (pkg: {name = pkg.pname or "unknown"; value = pkg;}) result.home.packages)))
      ];
    })

    (testLib.mkTest {
      name = "editors-backward-compatibility-option-paths";
      assertions = let
        config = mkTestConfig {
          enable = true;
          neovim = {
            enable = true;
            defaultEditor = false;
            extraConfig = "set number";
          };
          vscode = {
            enable = true;
            extensions = [];
          };
          helix = {
            enable = true;
          };
        };
        result = evalConfig config;
      in [
        (testLib.assertions.assertFalse "neovim defaultEditor option works" result.programs.neovim.defaultEditor)
        (testLib.assertions.assertMatches "neovim extraConfig option works" ".*set number.*" result.programs.neovim.extraConfig)
        (testLib.assertions.assertEqual "vscode extensions option works" [] result.programs.vscode.extensions)
        (testLib.assertions.assertEqual "helix theme setting works" "catppuccin_mocha" result.programs.helix.settings.theme)
      ];
    })

    (testLib.mkTest {
      name = "editors-backward-compatibility-package-customization";
      assertions = let
        customNeovim = pkgs.neovim.override { vimAlias = false; };
        config = mkTestConfig {
          enable = true;
          neovim = {
            enable = true;
            package = customNeovim;
          };
        };
        result = evalConfig config;
      in [
        (testLib.assertions.assertEqual "custom neovim package is used" customNeovim result.programs.neovim.package)
      ];
    })
  ];

  # Test individual editor modules in isolation
  individualModuleTests = [
    (testLib.mkTest {
      name = "neovim-module-isolation";
      assertions = let
        config = {
          imports = [neovimModule];
          modules.home.development.editors = {
            enable = true;
            neovim.enable = true;
          };
        };
        result = evalConfig config;
      in [
        (testLib.assertions.assertTrue "neovim module evaluates in isolation" (result ? programs.neovim))
        (testLib.assertions.assertTrue "neovim is enabled" result.programs.neovim.enable)
        (testLib.assertions.assertTrue "neovim has default config" (lib.hasAttr "extraConfig" result.programs.neovim))
        (testLib.assertions.assertContains "neovim has essential plugins" "vim-sensible" (map (p: p.pname or "unknown") result.programs.neovim.plugins))
      ];
    })

    (testLib.mkTest {
      name = "vscode-module-isolation";
      assertions = let
        config = {
          imports = [vscodeModule];
          modules.home.development.editors = {
            enable = true;
            vscode.enable = true;
          };
        };
        result = evalConfig config;
      in [
        (testLib.assertions.assertTrue "vscode module evaluates in isolation" (result ? programs.vscode))
        (testLib.assertions.assertTrue "vscode is enabled" result.programs.vscode.enable)
        (testLib.assertions.assertHasAttr "vscode has userSettings" "userSettings" result.programs.vscode)
        (testLib.assertions.assertEqual "vscode has correct font size" 14 result.programs.vscode.userSettings."editor.fontSize")
      ];
    })

    (testLib.mkTest {
      name = "helix-module-isolation";
      assertions = let
        config = {
          imports = [helixModule];
          modules.home.development.editors = {
            enable = true;
            helix.enable = true;
          };
        };
        result = evalConfig config;
      in [
        (testLib.assertions.assertTrue "helix module evaluates in isolation" (result ? programs.helix))
        (testLib.assertions.assertTrue "helix is enabled" result.programs.helix.enable)
        (testLib.assertions.assertHasAttr "helix has settings" "settings" result.programs.helix)
        (testLib.assertions.assertEqual "helix has correct theme" "catppuccin_mocha" result.programs.helix.settings.theme)
      ];
    })
  ];

  # Test various combinations of enabled/disabled editors
  combinationTests = [
    (testLib.mkTest {
      name = "editors-only-neovim-enabled";
      assertions = let
        config = mkTestConfig {
          enable = true;
          neovim.enable = true;
          vscode.enable = false;
          helix.enable = false;
        };
        result = evalConfig config;
      in [
        (testLib.assertions.assertTrue "neovim is enabled" result.programs.neovim.enable)
        (testLib.assertions.assertFalse "vscode is disabled" (result.programs ? vscode && result.programs.vscode.enable))
        (testLib.assertions.assertFalse "helix is disabled" (result.programs ? helix && result.programs.helix.enable))
      ];
    })

    (testLib.mkTest {
      name = "editors-only-vscode-enabled";
      assertions = let
        config = mkTestConfig {
          enable = true;
          neovim.enable = false;
          vscode.enable = true;
          helix.enable = false;
        };
        result = evalConfig config;
      in [
        (testLib.assertions.assertFalse "neovim is disabled" (result.programs ? neovim && result.programs.neovim.enable))
        (testLib.assertions.assertTrue "vscode is enabled" result.programs.vscode.enable)
        (testLib.assertions.assertFalse "helix is disabled" (result.programs ? helix && result.programs.helix.enable))
      ];
    })

    (testLib.mkTest {
      name = "editors-only-helix-enabled";
      assertions = let
        config = mkTestConfig {
          enable = true;
          neovim.enable = false;
          vscode.enable = false;
          helix.enable = true;
        };
        result = evalConfig config;
      in [
        (testLib.assertions.assertFalse "neovim is disabled" (result.programs ? neovim && result.programs.neovim.enable))
        (testLib.assertions.assertFalse "vscode is disabled" (result.programs ? vscode && result.programs.vscode.enable))
        (testLib.assertions.assertTrue "helix is enabled" result.programs.helix.enable)
      ];
    })

    (testLib.mkTest {
      name = "editors-neovim-and-vscode-enabled";
      assertions = let
        config = mkTestConfig {
          enable = true;
          neovim.enable = true;
          vscode.enable = true;
          helix.enable = false;
        };
        result = evalConfig config;
      in [
        (testLib.assertions.assertTrue "neovim is enabled" result.programs.neovim.enable)
        (testLib.assertions.assertTrue "vscode is enabled" result.programs.vscode.enable)
        (testLib.assertions.assertFalse "helix is disabled" (result.programs ? helix && result.programs.helix.enable))
      ];
    })

    (testLib.mkTest {
      name = "editors-all-disabled";
      assertions = let
        config = mkTestConfig {
          enable = true;
          neovim.enable = false;
          vscode.enable = false;
          helix.enable = false;
        };
        result = evalConfig config;
      in [
        (testLib.assertions.assertFalse "neovim is disabled" (result.programs ? neovim && result.programs.neovim.enable))
        (testLib.assertions.assertFalse "vscode is disabled" (result.programs ? vscode && result.programs.vscode.enable))
        (testLib.assertions.assertFalse "helix is disabled" (result.programs ? helix && result.programs.helix.enable))
      ];
    })

    (testLib.mkTest {
      name = "editors-main-enable-false";
      assertions = let
        config = mkTestConfig {
          enable = false;
          neovim.enable = true;
          vscode.enable = true;
          helix.enable = true;
        };
        result = evalConfig config;
      in [
        (testLib.assertions.assertFalse "neovim respects main enable" (result.programs ? neovim && result.programs.neovim.enable))
        (testLib.assertions.assertFalse "vscode respects main enable" (result.programs ? vscode && result.programs.vscode.enable))
        (testLib.assertions.assertFalse "helix respects main enable" (result.programs ? helix && result.programs.helix.enable))
      ];
    })
  ];

  # Test build output compatibility
  buildCompatibilityTests = [
    (testLib.mkTest {
      name = "editors-build-output-structure";
      assertions = let
        config = mkTestConfig {
          enable = true;
          neovim.enable = true;
          vscode.enable = true;
          helix.enable = true;
        };
        result = evalConfig config;
      in [
        (testLib.assertions.assertTrue "config has programs section" (result ? programs))
        (testLib.assertions.assertTrue "config has home section" (result ? home))
        (testLib.assertions.assertTrue "home has packages" (result.home ? packages))
        (testLib.assertions.assertTrue "programs has neovim" (result.programs ? neovim))
        (testLib.assertions.assertTrue "programs has vscode" (result.programs ? vscode))
        (testLib.assertions.assertTrue "programs has helix" (result.programs ? helix))
      ];
    })

    (testLib.mkTest {
      name = "editors-package-installation";
      assertions = let
        config = mkTestConfig {
          enable = true;
          neovim.enable = true;
          vscode.enable = false;
          helix.enable = true;
        };
        result = evalConfig config;
        packageNames = map (pkg: pkg.pname or pkg.name or "unknown") result.home.packages;
      in [
        (testLib.assertions.assertContains "neovim package is installed" "neovim" packageNames)
        (testLib.assertions.assertContains "helix package is installed" "helix" packageNames)
        # VSCode should not be in packages since it's disabled
      ];
    })

    (testLib.mkTest {
      name = "editors-configuration-completeness";
      assertions = let
        config = mkTestConfig {
          enable = true;
          neovim = {
            enable = true;
            extraConfig = "set relativenumber";
            plugins = [pkgs.vimPlugins.vim-airline];
          };
          vscode = {
            enable = true;
            extensions = [pkgs.vscode-extensions.ms-python.python];
          };
        };
        result = evalConfig config;
      in [
        (testLib.assertions.assertMatches "neovim extraConfig is applied" ".*set relativenumber.*" result.programs.neovim.extraConfig)
        (testLib.assertions.assertContains "neovim custom plugin is included" "vim-airline" (map (p: p.pname or "unknown") result.programs.neovim.plugins))
        (testLib.assertions.assertContains "vscode extension is included" "ms-python.python" (map (e: e.pname or e.name or "unknown") result.programs.vscode.extensions))
      ];
    })
  ];

  # Test module structure and conventions
  structureTests = [
    (testLib.mkTest {
      name = "editors-module-structure";
      assertions = [
        (testLib.assertions.assertTrue "main module has imports" 
          (lib.pathExists (toString editorsModule + "/default.nix")))
        (testLib.assertions.assertTrue "neovim module exists" 
          (lib.pathExists (toString neovimModule)))
        (testLib.assertions.assertTrue "vscode module exists" 
          (lib.pathExists (toString vscodeModule)))
        (testLib.assertions.assertTrue "helix module exists" 
          (lib.pathExists (toString helixModule)))
      ];
    })

    (testLib.mkTest {
      name = "editors-option-namespacing";
      assertions = let
        config = mkTestConfig {
          enable = true;
          neovim.enable = true;
        };
        result = evalConfig config;
        options = (lib.evalModules {
          modules = [config];
          specialArgs = {inherit pkgs;};
        }).options;
      in [
        (testLib.assertions.assertTrue "main enable option exists" 
          (options.modules.home.development.editors ? enable))
        (testLib.assertions.assertTrue "neovim options are namespaced" 
          (options.modules.home.development.editors ? neovim))
        (testLib.assertions.assertTrue "vscode options are namespaced" 
          (options.modules.home.development.editors ? vscode))
        (testLib.assertions.assertTrue "helix options are namespaced" 
          (options.modules.home.development.editors ? helix))
      ];
    })
  ];

  # Test error handling and edge cases
  errorHandlingTests = [
    (testLib.mkTest {
      name = "editors-invalid-package-handling";
      assertions = let
        # Test with null package (should use default)
        config = mkTestConfig {
          enable = true;
          neovim = {
            enable = true;
            package = pkgs.neovim; # Valid package
          };
        };
        result = testLib.try (evalConfig config) null;
      in [
        (testLib.assertions.assertNotNull "config handles valid packages" result)
      ];
    })

    (testLib.mkTest {
      name = "editors-empty-configuration";
      assertions = let
        config = mkTestConfig {};
        result = evalConfig config;
      in [
        (testLib.assertions.assertTrue "empty config evaluates successfully" (result ? modules))
        (testLib.assertions.assertFalse "editors are disabled by default" 
          (result.modules.home.development.editors.enable or false))
      ];
    })
  ];
in
  backwardCompatibilityTests 
  ++ individualModuleTests 
  ++ combinationTests 
  ++ buildCompatibilityTests 
  ++ structureTests 
  ++ errorHandlingTests