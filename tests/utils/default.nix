# Test utilities and helpers
{
  inputs,
  outputs,
  system,
  lib,
  pkgs,
  ...
}: let
  # Test framework
  testFramework = import ./test-framework.nix {inherit lib pkgs;};

  # Test runners
  testRunners = import ./test-runners.nix {inherit lib pkgs testFramework;};

  # Test data generators
  testData = import ./test-data.nix {inherit lib pkgs;};

  # Test validation utilities
  testValidation = import ./test-validation.nix {inherit lib pkgs;};
in {
  # Export all utilities
  inherit testFramework testRunners testData testValidation;

  # Convenience functions
  mkTest = testFramework.mkTest;
  runTests = testRunners.runAllTests;

  # Test data generators
  generateTestConfig = testData.generateTestConfig;
  generateTestModule = testData.generateTestModule;

  # Validation helpers
  validateTestResult = testValidation.validateTestResult;
  validateTestSuite = testValidation.validateTestSuite;
}
