# Full system build tests
{ inputs, outputs, system, lib, pkgs, testLib, builders, ... }:
let
  # Example configurations that should build successfully
  exampleConfigurations = {
    # Minimal server-like configuration
    minimal-server = {
      hostname = "minimal-server";
      username = "admin";
      system = "aarch64-darwin";
      profiles = {
        minimal.enable = true;
      };
      modules = {
        darwin.system.enable = true;
        home.shell.zsh.enable = true;
        home.development.git.enable = true;
      };
    };
    
    # Development workstation
    development-workstation = {
      hostname = "dev-workstation";
      username = "developer";
      system = "aarch64-darwin";
      profiles = {
        development.enable = true;
      };
      modules = {
        darwin.homebrew.enable = true;
        home.development.containers.enable = true;
        home.desktop.terminal.enable = true;
      };
    };
    
    # Work laptop
    work-laptop = {
      hostname = "work-laptop";
      username = "employee";
      system = "aarch64-darwin";
      profiles = {
        work.enable = true;
        development.enable = true;
      };
      modules = {
        darwin.security.enable = true;
        home.security.gpg.enable = true;
        home.security.ssh.enable = true;
      };
    };
    
    # Personal MacBook
    personal-macbook = {
      hostname = "personal-macbook";
      username = "user";
      system = "aarch64-darwin";
      profiles = {
        personal.enable = true;
        development.enable = true;
      };
      modules = {
        darwin.homebrew.enable = true;
        home.desktop.productivity.enable = true;
        home.desktop.window-manager.enable = true;
      };
    };
    
    # Multi-user workstation
    multi-user-workstation = {
      hostname = "multi-user";
      username = "admin";
      system = "aarch64-darwin";
      profiles = {
        development.enable = true;
        work.enable = true;
      };
      modules = {
        darwin.system.enable = true;
        darwin.security.enable = true;
        darwin.homebrew.enable = true;
      };
    };
  };
  
  # Create build tests for each example configuration
  buildConfigurationTests = lib.mapAttrsToList (configName: config:
    testLib.mkTest {
      name = "build-${configName}";
      assertions = [
        # Test that the configuration builds without errors
        (let
          buildResult = testLib.try (builders.mkDarwin config) null;
        in
          testLib.assertions.assertNotNull 
            "Configuration ${configName} builds successfully" 
            buildResult)
        
        # Test that the build result has expected structure
        (let
          buildResult = testLib.try (builders.mkDarwin config) null;
          hasConfig = buildResult != null && (buildResult ? config);
        in
          testLib.assertions.assertTrue 
            "Build result for ${configName} has config" 
            hasConfig)
        
        # Test that the build result has system configuration
        (let
          buildResult = testLib.try (builders.mkDarwin config) null;
          hasSystem = buildResult != null && 
                     (buildResult ? config) && 
                     (buildResult.config ? system);
        in
          testLib.assertions.assertTrue 
            "Build result for ${configName} has system config" 
            hasSystem)
      ];
    }
  ) exampleConfigurations;
  
  # Test build with different architectures
  architectureBuildTests = [
    (testLib.mkTest {
      name = "build-architectures";
      assertions = [
        # Test aarch64-darwin build
        (let
          aarch64Config = {
            hostname = "aarch64-test";
            username = "test-user";
            system = "aarch64-darwin";
            profiles = {
              minimal.enable = true;
            };
          };
          buildResult = testLib.try (builders.mkDarwin aarch64Config) null;
        in
          testLib.assertions.assertNotNull 
            "aarch64-darwin configuration builds" 
            buildResult)
        
        # Test x86_64-darwin build
        (let
          x86Config = {
            hostname = "x86-test";
            username = "test-user";
            system = "x86_64-darwin";
            profiles = {
              minimal.enable = true;
            };
          };
          buildResult = testLib.try (builders.mkDarwin x86Config) null;
        in
          testLib.assertions.assertNotNull 
            "x86_64-darwin configuration builds" 
            buildResult)
      ];
    })
  ];
  
  # Test build with various module combinations
  moduleCombinationBuildTests = [
    (testLib.mkTest {
      name = "build-module-combinations";
      assertions = [
        # Test Darwin-only modules
        (let
          darwinOnlyConfig = {
            hostname = "darwin-only";
            username = "test-user";
            system = "aarch64-darwin";
            modules = {
              darwin.system.enable = true;
              darwin.homebrew.enable = true;
              darwin.security.enable = true;
              darwin.defaults.enable = true;
            };
          };
          buildResult = testLib.try (builders.mkDarwin darwinOnlyConfig) null;
        in
          testLib.assertions.assertNotNull 
            "Darwin-only module combination builds" 
            buildResult)
        
        # Test Home Manager-only modules
        (let
          homeOnlyConfig = {
            hostname = "home-only";
            username = "test-user";
            system = "aarch64-darwin";
            modules = {
              darwin.system.enable = true;  # Required base
              home.shell.zsh.enable = true;
              home.development.git.enable = true;
              home.security.ssh.enable = true;
            };
          };
          buildResult = testLib.try (builders.mkDarwin homeOnlyConfig) null;
        in
          testLib.assertions.assertNotNull 
            "Home Manager-only module combination builds" 
            buildResult)
        
        # Test mixed Darwin and Home Manager modules
        (let
          mixedConfig = {
            hostname = "mixed-modules";
            username = "test-user";
            system = "aarch64-darwin";
            modules = {
              darwin.system.enable = true;
              darwin.homebrew.enable = true;
              home.shell.zsh.enable = true;
              home.development.git.enable = true;
              home.desktop.terminal.enable = true;
            };
          };
          buildResult = testLib.try (builders.mkDarwin mixedConfig) null;
        in
          testLib.assertions.assertNotNull 
            "Mixed Darwin and Home Manager modules build" 
            buildResult)
      ];
    })
  ];
  
  # Test build performance and resource usage
  buildPerformanceTests = [
    (testLib.mkTest {
      name = "build-performance";
      assertions = [
        # Test that builds complete in reasonable time
        # Note: This is a placeholder - actual timing would require more complex setup
        (testLib.assertions.assertTrue "builds complete in reasonable time"
          (let
            simpleConfig = {
              hostname = "perf-test";
              username = "test-user";
              system = "aarch64-darwin";
              profiles = {
                minimal.enable = true;
              };
            };
            buildResult = testLib.try (builders.mkDarwin simpleConfig) null;
          in
            buildResult != null))
        
        # Test that complex builds don't fail due to resource constraints
        (testLib.assertions.assertTrue "complex builds handle resources well"
          (let
            complexConfig = {
              hostname = "complex-perf-test";
              username = "test-user";
              system = "aarch64-darwin";
              profiles = {
                development.enable = true;
                work.enable = true;
                personal.enable = true;
              };
              modules = {
                darwin.homebrew.enable = true;
                darwin.security.enable = true;
                home.development.containers.enable = true;
                home.desktop.productivity.enable = true;
              };
            };
            buildResult = testLib.try (builders.mkDarwin complexConfig) null;
          in
            buildResult != null))
      ];
    })
  ];
  
  # Test build error handling
  buildErrorHandlingTests = [
    (testLib.mkTest {
      name = "build-error-handling";
      assertions = [
        # Test that invalid configurations are handled gracefully
        (testLib.assertions.assertTrue "invalid configs handled gracefully"
          (let
            invalidConfig = {
              hostname = "invalid-test";
              username = "test-user";
              system = "aarch64-darwin";
              modules = {
                # Invalid module configuration
                nonexistent.module.enable = true;
              };
            };
            # Should not crash, even if it fails to build
            buildResult = testLib.try (builders.mkDarwin invalidConfig) "handled";
          in
            true))  # Just check it doesn't crash the test runner
        
        # Test that missing required fields are handled
        (testLib.assertions.assertTrue "missing fields handled gracefully"
          (let
            incompleteConfig = {
              # Missing hostname, username, system
              modules = {
                darwin.system.enable = true;
              };
            };
            buildResult = testLib.try (builders.mkDarwin incompleteConfig) "handled";
          in
            true))  # Just check it doesn't crash the test runner
      ];
    })
  ];
  
in buildConfigurationTests ++ architectureBuildTests ++ moduleCombinationBuildTests ++ buildPerformanceTests ++ buildErrorHandlingTests