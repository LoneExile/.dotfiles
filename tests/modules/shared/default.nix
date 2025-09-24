# Shared module tests
{ inputs, outputs, system, lib, pkgs, testLib, ... }:
let
  # Import shared modules for testing
  sharedModules = {
    fonts = ../../modules/shared/fonts.nix;
    networking = ../../modules/shared/networking.nix;
    validation = ../../modules/shared/validation.nix;
    diagnostics = ../../modules/shared/diagnostics.nix;
  };
  
  # Fonts module tests
  fontsModuleTests = testLib.mkTest {
    name = "shared-fonts-module";
    assertions =
      # Test module structure
      testLib.moduleUtils.testModuleStructure "modules.shared.fonts" {
        enable = true;
        fonts = [];
      } ++
      
      # Test module evaluation
      testLib.moduleUtils.testModuleEvaluation "modules.shared.fonts" sharedModules.fonts ++
      
      # Test different configurations
      testLib.moduleUtils.testModuleConfigurations "modules.shared.fonts" sharedModules.fonts {
        withFonts = {
          fonts = with pkgs; [ 
            (nerdfonts.override { fonts = [ "FiraCode" "JetBrainsMono" ]; })
          ];
        };
        
        empty = {
          fonts = [];
        };
      };
  };
  
  # Networking module tests
  networkingModuleTests = testLib.mkTest {
    name = "shared-networking-module";
    assertions =
      # Test module structure
      testLib.moduleUtils.testModuleStructure "modules.shared.networking" {
        enable = true;
      } ++
      
      # Test module evaluation
      testLib.moduleUtils.testModuleEvaluation "modules.shared.networking" sharedModules.networking;
  };
  
  # Validation module tests
  validationModuleTests = testLib.mkTest {
    name = "shared-validation-module";
    assertions =
      # Test module structure
      testLib.moduleUtils.testModuleStructure "modules.shared.validation" {
        enable = true;
      } ++
      
      # Test module evaluation
      testLib.moduleUtils.testModuleEvaluation "modules.shared.validation" sharedModules.validation;
  };
  
  # Diagnostics module tests
  diagnosticsModuleTests = testLib.mkTest {
    name = "shared-diagnostics-module";
    assertions =
      # Test module structure
      testLib.moduleUtils.testModuleStructure "modules.shared.diagnostics" {
        enable = true;
      } ++
      
      # Test module evaluation
      testLib.moduleUtils.testModuleEvaluation "modules.shared.diagnostics" sharedModules.diagnostics;
  };
  
in [
  fontsModuleTests
  networkingModuleTests
  validationModuleTests
  diagnosticsModuleTests
]