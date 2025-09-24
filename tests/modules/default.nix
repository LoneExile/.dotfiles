# Module unit tests
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

  # Import individual module tests
  darwinTests = import ./darwin {inherit inputs outputs system lib pkgs testLib;};
  homeTests = import ./home {inherit inputs outputs system lib pkgs testLib;};
  sharedTests = import ./shared {inherit inputs outputs system lib pkgs testLib;};

  # Combine all module tests
  allTests = darwinTests ++ homeTests ++ sharedTests;
in {
  # Individual test categories
  darwin = darwinTests;
  home = homeTests;
  shared = sharedTests;

  # All module tests combined
  tests = allTests;

  # Test runner
  runTests = pkgs.writeShellScriptBin "run-module-tests" ''
    echo "Running module unit tests..."

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
      '')
      allTests)}

    echo ""
    echo "Module Tests Summary:"
    echo "  Total: $total_tests"
    echo "  Passed: $passed_tests"
    echo "  Failed: $failed_tests"

    if [ $failed_tests -gt 0 ]; then
      exit 1
    fi
  '';
}
