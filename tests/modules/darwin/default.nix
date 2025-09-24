# Darwin module tests
{ inputs, outputs, system, lib, pkgs, testLib, ... }:
let
  # Import Darwin modules for testing
  darwinModules = {
    system = ../../modules/darwin/system.nix;
    homebrew = ../../modules/darwin/homebrew.nix;
    security = ../../modules/darwin/security.nix;
    defaults = ../../modules/darwin/defaults.nix;
    packages = ../../modules/darwin/packages.nix;
  };
  
  # Test configurations for different scenarios
  testConfigs = {
    minimal = {
      enable = true;
    };
    
    customized = {
      enable = true;
      settings = {
        customSetting = "test-value";
      };
    };
  };
  
  # System module tests
  systemModuleTests = testLib.mkTest {
    name = "darwin-system-module";
    assertions = 
      # Test module structure
      testLib.moduleUtils.testModuleStructure "modules.darwin.system" {
        enable = true;
        hostname = "test-host";
        stateVersion = 5;
        primaryUser = "test-user";
      } ++
      
      # Test module evaluation
      testLib.moduleUtils.testModuleEvaluation "modules.darwin.system" darwinModules.system ++
      
      # Test different configurations
      testLib.moduleUtils.testModuleConfigurations "modules.darwin.system" darwinModules.system {
        default = {
          hostname = "test-host";
        };
        
        customKeyboard = {
          hostname = "test-host";
          keyboard.remapCapsLockToEscape = true;
        };
        
        customNix = {
          hostname = "test-host";
          nix.warnDirty = true;
          nix.enableChannel = true;
        };
      };
  };
  
  # Homebrew module tests
  homebrewModuleTests = testLib.mkTest {
    name = "darwin-homebrew-module";
    assertions =
      # Test module structure
      testLib.moduleUtils.testModuleStructure "modules.darwin.homebrew" {
        enable = true;
        brews = [];
        casks = [];
      } ++
      
      # Test module evaluation
      testLib.moduleUtils.testModuleEvaluation "modules.darwin.homebrew" darwinModules.homebrew ++
      
      # Test different configurations
      testLib.moduleUtils.testModuleConfigurations "modules.darwin.homebrew" darwinModules.homebrew {
        withBrews = {
          brews = [ "git" "curl" ];
        };
        
        withCasks = {
          casks = [ "firefox" "vscode" ];
        };
        
        withBoth = {
          brews = [ "git" ];
          casks = [ "firefox" ];
        };
      };
  };
  
  # Security module tests
  securityModuleTests = testLib.mkTest {
    name = "darwin-security-module";
    assertions =
      # Test module structure
      testLib.moduleUtils.testModuleStructure "modules.darwin.security" {
        enable = true;
        touchId = true;
      } ++
      
      # Test module evaluation
      testLib.moduleUtils.testModuleEvaluation "modules.darwin.security" darwinModules.security ++
      
      # Test different configurations
      testLib.moduleUtils.testModuleConfigurations "modules.darwin.security" darwinModules.security {
        touchIdEnabled = {
          touchId = true;
        };
        
        touchIdDisabled = {
          touchId = false;
        };
      };
  };
  
  # Defaults module tests
  defaultsModuleTests = testLib.mkTest {
    name = "darwin-defaults-module";
    assertions =
      # Test module structure
      testLib.moduleUtils.testModuleStructure "modules.darwin.defaults" {
        enable = true;
      } ++
      
      # Test module evaluation
      testLib.moduleUtils.testModuleEvaluation "modules.darwin.defaults" darwinModules.defaults;
  };
  
  # Packages module tests
  packagesModuleTests = testLib.mkTest {
    name = "darwin-packages-module";
    assertions =
      # Test module structure
      testLib.moduleUtils.testModuleStructure "modules.darwin.packages" {
        enable = true;
        systemPackages = [];
      } ++
      
      # Test module evaluation
      testLib.moduleUtils.testModuleEvaluation "modules.darwin.packages" darwinModules.packages ++
      
      # Test different configurations
      testLib.moduleUtils.testModuleConfigurations "modules.darwin.packages" darwinModules.packages {
        withPackages = {
          systemPackages = with pkgs; [ git curl ];
        };
        
        empty = {
          systemPackages = [];
        };
      };
  };
  
in [
  systemModuleTests
  homebrewModuleTests
  securityModuleTests
  defaultsModuleTests
  packagesModuleTests
]