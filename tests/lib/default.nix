# Library function tests
{
  inputs,
  outputs,
  system,
  lib,
  pkgs,
  ...
}: let
  # Test framework utilities
  testLib = import ../utils/test-framework.nix {inherit lib pkgs;};

  # Import library modules for testing
  builders = import ../../lib/builders.nix {inherit inputs outputs;};
  utils = import ../../lib/utils.nix {inherit inputs outputs;};
  validation = import ../../lib/validation.nix {inherit inputs outputs;};

  # Builders tests
  buildersTests = testLib.mkTest {
    name = "lib-builders";
    assertions = [
      # Test mkDarwin function exists and is callable
      (testLib.assertions.assertNotNull "mkDarwin function exists" builders.mkDarwin)
      (testLib.assertions.assertEqual "mkDarwin is function" "lambda" (lib.typeOf builders.mkDarwin))

      # Test mkProfile function exists and is callable
      (testLib.assertions.assertNotNull "mkProfile function exists" builders.mkProfile)
      (testLib.assertions.assertEqual "mkProfile is function" "lambda" (lib.typeOf builders.mkProfile))

      # Test mkModule function exists and is callable
      (testLib.assertions.assertNotNull "mkModule function exists" builders.mkModule)
      (testLib.assertions.assertEqual "mkModule is function" "lambda" (lib.typeOf builders.mkModule))

      # Test mkDarwin with minimal config
      (testLib.assertions.assertNotNull "mkDarwin minimal config"
        (testLib.try (builders.mkDarwin {
            hostname = "test-host";
            username = "test-user";
            system = "aarch64-darwin";
          })
          null))

      # Test mkProfile with minimal config
      (testLib.assertions.assertNotNull "mkProfile minimal config"
        (testLib.try (builders.mkProfile {
            name = "test-profile";
          })
          null))

      # Test mkModule with minimal config
      (testLib.assertions.assertNotNull "mkModule minimal config"
        (testLib.try (builders.mkModule {
            name = "test-module";
          })
          null))
    ];
  };

  # Utils tests
  utilsTests = testLib.mkTest {
    name = "lib-utils";
    assertions = [
      # Test that utils exports expected functions
      (testLib.assertions.assertHasAttr "utils has fileUtils" "fileUtils" utils)
      (testLib.assertions.assertHasAttr "utils has configUtils" "configUtils" utils)
      (testLib.assertions.assertHasAttr "utils has systemUtils" "systemUtils" utils)

      # Test file utilities
      (testLib.assertions.assertNotNull "fileUtils exists" utils.fileUtils)
      (testLib.assertions.assertEqual "fileUtils is attrs" "set" (lib.typeOf utils.fileUtils))

      # Test config utilities
      (testLib.assertions.assertNotNull "configUtils exists" utils.configUtils)
      (testLib.assertions.assertEqual "configUtils is attrs" "set" (lib.typeOf utils.configUtils))

      # Test system utilities
      (testLib.assertions.assertNotNull "systemUtils exists" utils.systemUtils)
      (testLib.assertions.assertEqual "systemUtils is attrs" "set" (lib.typeOf utils.systemUtils))
    ];
  };

  # Validation tests
  validationTests = testLib.mkTest {
    name = "lib-validation";
    assertions = [
      # Test that validation exports expected components
      (testLib.assertions.assertHasAttr "validation has moduleValidation" "moduleValidation" validation)
      (testLib.assertions.assertHasAttr "validation has configValidation" "configValidation" validation)
      (testLib.assertions.assertHasAttr "validation has validationAssertions" "validationAssertions" validation)

      # Test module validation functions
      (testLib.assertions.assertNotNull "moduleValidation exists" validation.moduleValidation)
      (testLib.assertions.assertHasAttr "moduleValidation has validateModuleStructure"
        "validateModuleStructure"
        validation.moduleValidation)
      (testLib.assertions.assertHasAttr "moduleValidation has validateModuleDependencies"
        "validateModuleDependencies"
        validation.moduleValidation)

      # Test config validation functions
      (testLib.assertions.assertNotNull "configValidation exists" validation.configValidation)
      (testLib.assertions.assertHasAttr "configValidation has validateFullConfig"
        "validateFullConfig"
        validation.configValidation)

      # Test validation assertions
      (testLib.assertions.assertNotNull "validationAssertions exists" validation.validationAssertions)
      (testLib.assertions.assertHasAttr "validationAssertions has assertValidConfig"
        "assertValidConfig"
        validation.validationAssertions)

      # Test module structure validation with valid config
      (let
        result = validation.moduleValidation.validateModuleStructure "test.module" {
          enable = true;
          package = pkgs.hello;
          settings = {};
        };
      in
        testLib.assertions.assertTrue "valid module structure passes validation" result.valid)

      # Test module structure validation with invalid config
      (let
        result = validation.moduleValidation.validateModuleStructure "test.module" {
          # Missing enable field
          package = pkgs.hello;
        };
      in
        testLib.assertions.assertFalse "invalid module structure fails validation" result.valid)

      # Test config validation with valid config
      (let
        testConfig = {
          hostname = "test-host";
          system = "aarch64-darwin";
          username = "test-user";
          modules = {};
          profiles = {};
        };
        result = validation.configValidation.validateFullConfig testConfig "aarch64-darwin";
      in
        testLib.assertions.assertTrue "valid config passes validation" result.valid)

      # Test config validation with invalid config
      (let
        testConfig = {
          # Missing required fields
          modules = {};
        };
        result = validation.configValidation.validateFullConfig testConfig "aarch64-darwin";
      in
        testLib.assertions.assertFalse "invalid config fails validation" result.valid)
    ];
  };
in {
  # Individual test categories
  builders = buildersTests;
  utils = utilsTests;
  validation = validationTests;

  # All library tests combined
  tests = [buildersTests utilsTests validationTests];

  # Test runner
  runTests = pkgs.writeShellScriptBin "run-lib-tests" ''
    echo "Running library function tests..."

    # Run tests and collect results
    total_tests=0
    passed_tests=0
    failed_tests=0

    ${builtins.concatStringsSep "\n" (map (test: ''
      echo "Running test: ${test.name}"
      total_tests=$((total_tests + 1))

      if ${test.command}; then
        echo "  ✓ PASSED: ${test.name}"
        passed_tests=$((passed_tests + 1))
      else
        echo "  ✗ FAILED: ${test.name}"
        failed_tests=$((failed_tests + 1))
      fi
    '') [buildersTests utilsTests validationTests])}

    echo ""
    echo "Library Tests Summary:"
    echo "  Total: $total_tests"
    echo "  Passed: $passed_tests"
    echo "  Failed: $failed_tests"

    if [ $failed_tests -gt 0 ]; then
      exit 1
    fi
  '';
}
