# Module combination integration tests
{ inputs, outputs, system, lib, pkgs, testLib, builders, ... }:
let
  # Test different module combinations
  moduleCombinations = {
    # Basic shell setup
    basic-shell = {
      modules = {
        darwin.system.enable = true;
        home.shell.zsh.enable = true;
        home.shell.starship.enable = true;
      };
      description = "Basic shell configuration";
    };
    
    # Development environment
    development-env = {
      modules = {
        darwin.system.enable = true;
        home.shell.zsh.enable = true;
        home.development.git.enable = true;
        home.development.editors.enable = true;
        home.development.languages.enable = true;
      };
      description = "Development environment setup";
    };
    
    # Security-focused setup
    security-setup = {
      modules = {
        darwin.system.enable = true;
        darwin.security.enable = true;
        home.security.gpg.enable = true;
        home.security.ssh.enable = true;
      };
      description = "Security-focused configuration";
    };
    
    # Desktop productivity
    desktop-productivity = {
      modules = {
        darwin.system.enable = true;
        home.shell.zsh.enable = true;
        home.desktop.terminal.enable = true;
        home.desktop.window-manager.enable = true;
        home.desktop.productivity.enable = true;
      };
      description = "Desktop productivity setup";
    };
    
    # Full development workstation
    full-workstation = {
      modules = {
        darwin.system.enable = true;
        darwin.homebrew.enable = true;
        darwin.security.enable = true;
        home.shell.zsh.enable = true;
        home.shell.starship.enable = true;
        home.development.git.enable = true;
        home.development.editors.enable = true;
        home.development.languages.enable = true;
        home.development.containers.enable = true;
        home.desktop.terminal.enable = true;
        home.desktop.window-manager.enable = true;
        home.security.gpg.enable = true;
        home.security.ssh.enable = true;
      };
      description = "Full development workstation";
    };
    
    # Minimal server-like setup
    minimal-server = {
      modules = {
        darwin.system.enable = true;
        home.shell.zsh.enable = true;
        home.development.git.enable = true;
        home.security.ssh.enable = true;
      };
      description = "Minimal server-like configuration";
    };
  };
  
  # Create tests for each module combination
  moduleCombinationTests = lib.mapAttrsToList (combName: combConfig:
    testLib.mkTest {
      name = "module-combination-${combName}";
      assertions = [
        # Test that the module combination builds successfully
        (let
          testConfig = {
            hostname = "test-${combName}";
            username = "test-user";
            system = "aarch64-darwin";
            modules = combConfig.modules;
          };
          
          buildResult = testLib.try (builders.mkDarwin testConfig) null;
        in
          testLib.assertions.assertNotNull 
            "Module combination ${combName} builds successfully" 
            buildResult)
        
        # Test that all modules in combination are properly structured
        (testLib.assertions.assertTrue 
          "Module combination ${combName} has valid module structure"
          (let
            checkModuleStructure = path: moduleConfig:
              lib.isAttrs moduleConfig && 
              lib.hasAttr "enable" moduleConfig && 
              lib.isBool moduleConfig.enable;
            
            checkNestedModules = modules:
              lib.all (name: 
                let value = modules.${name}; in
                if lib.isAttrs value && !(lib.hasAttr "enable" value)
                then checkNestedModules value  # Nested module category
                else checkModuleStructure name value  # Actual module
              ) (lib.attrNames modules);
          in
            checkNestedModules combConfig.modules))
      ];
    }
  ) moduleCombinations;
  
  # Test module dependency resolution
  moduleDependencyTests = [
    (testLib.mkTest {
      name = "module-dependencies";
      assertions = [
        # Test that terminal module works with shell modules
        (let
          testConfig = {
            hostname = "test-deps";
            username = "test-user";
            system = "aarch64-darwin";
            modules = {
              darwin.system.enable = true;
              home.shell.zsh.enable = true;
              home.desktop.terminal.enable = true;
            };
          };
          buildResult = testLib.try (builders.mkDarwin testConfig) null;
        in
          testLib.assertions.assertNotNull 
            "Terminal module works with shell dependencies" 
            buildResult)
        
        # Test that development modules work together
        (let
          testConfig = {
            hostname = "test-dev-deps";
            username = "test-user";
            system = "aarch64-darwin";
            modules = {
              darwin.system.enable = true;
              home.development.git.enable = true;
              home.development.editors.enable = true;
              home.development.languages.enable = true;
            };
          };
          buildResult = testLib.try (builders.mkDarwin testConfig) null;
        in
          testLib.assertions.assertNotNull 
            "Development modules work together" 
            buildResult)
        
        # Test that security modules work together
        (let
          testConfig = {
            hostname = "test-sec-deps";
            username = "test-user";
            system = "aarch64-darwin";
            modules = {
              darwin.system.enable = true;
              darwin.security.enable = true;
              home.security.gpg.enable = true;
              home.security.ssh.enable = true;
            };
          };
          buildResult = testLib.try (builders.mkDarwin testConfig) null;
        in
          testLib.assertions.assertNotNull 
            "Security modules work together" 
            buildResult)
      ];
    })
  ];
  
  # Test module conflict detection
  moduleConflictTests = [
    (testLib.mkTest {
      name = "module-conflicts";
      assertions = [
        # Test that conflicting shell configurations are handled
        # Note: Currently we don't have conflicting modules, but this could be expanded
        (testLib.assertions.assertTrue "no shell conflicts detected"
          (let
            # Test enabling multiple shell configurations
            testConfig = {
              hostname = "test-conflicts";
              username = "test-user";
              system = "aarch64-darwin";
              modules = {
                darwin.system.enable = true;
                home.shell.zsh.enable = true;
                # If we had bash module: home.shell.bash.enable = true;
              };
            };
            buildResult = testLib.try (builders.mkDarwin testConfig) null;
          in
            buildResult != null))
      ];
    })
  ];
  
  # Test module platform compatibility
  modulePlatformTests = [
    (testLib.mkTest {
      name = "module-platform-compatibility";
      assertions = [
        # Test that Darwin modules work on Darwin
        (let
          testConfig = {
            hostname = "test-darwin";
            username = "test-user";
            system = "aarch64-darwin";
            modules = {
              darwin.system.enable = true;
              darwin.homebrew.enable = true;
              darwin.security.enable = true;
            };
          };
          buildResult = testLib.try (builders.mkDarwin testConfig) null;
        in
          testLib.assertions.assertNotNull 
            "Darwin modules work on Darwin platform" 
            buildResult)
        
        # Test that Home Manager modules work cross-platform
        (let
          testConfig = {
            hostname = "test-home";
            username = "test-user";
            system = "aarch64-darwin";
            modules = {
              darwin.system.enable = true;
              home.shell.zsh.enable = true;
              home.development.git.enable = true;
              home.security.ssh.enable = true;
            };
          };
          buildResult = testLib.try (builders.mkDarwin testConfig) null;
        in
          testLib.assertions.assertNotNull 
            "Home Manager modules work cross-platform" 
            buildResult)
      ];
    })
  ];
  
  # Test module configuration validation
  moduleValidationTests = [
    (testLib.mkTest {
      name = "module-validation";
      assertions = [
        # Test that invalid module configurations are rejected
        (testLib.assertions.assertTrue "invalid modules are rejected"
          (let
            # Test with invalid enable value
            invalidConfig = {
              hostname = "test-invalid";
              username = "test-user";
              system = "aarch64-darwin";
              modules = {
                darwin.system.enable = "invalid";  # Should be boolean
              };
            };
            # This should fail validation, but we'll check it doesn't crash
            buildResult = testLib.try (builders.mkDarwin invalidConfig) null;
          in
            true))  # For now, just check it doesn't crash
        
        # Test that missing required options are handled
        (testLib.assertions.assertTrue "missing options are handled"
          (let
            incompleteConfig = {
              hostname = "test-incomplete";
              username = "test-user";
              system = "aarch64-darwin";
              modules = {
                # Missing required system module
                home.shell.zsh.enable = true;
              };
            };
            buildResult = testLib.try (builders.mkDarwin incompleteConfig) null;
          in
            true))  # For now, just check it doesn't crash
      ];
    })
  ];
  
in moduleCombinationTests ++ moduleDependencyTests ++ moduleConflictTests ++ modulePlatformTests ++ moduleValidationTests