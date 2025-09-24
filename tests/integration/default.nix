# Integration tests for module combinations and profile testing
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

  # Import builders for testing
  builders = import ../../lib/builders.nix {inherit inputs outputs;};

  # Profile combination tests
  profileTests = import ./profiles.nix {inherit inputs outputs system lib pkgs testLib builders;};

  # Module combination tests
  moduleTests = import ./modules.nix {inherit inputs outputs system lib pkgs testLib builders;};

  # Host configuration tests
  hostTests = import ./hosts.nix {inherit inputs outputs system lib pkgs testLib builders;};

  # Combine all integration tests
  allTests = profileTests ++ moduleTests ++ hostTests;
in {
  # Individual test categories
  profiles = profileTests;
  modules = moduleTests;
  hosts = hostTests;

  # All integration tests combined
  tests = allTests;

  # Test runner
  runTests = pkgs.writeShellScriptBin "run-integration-tests" ''
    echo "Running integration tests..."

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
    echo "Integration Tests Summary:"
    echo "  Total: $total_tests"
    echo "  Passed: $passed_tests"
    echo "  Failed: $failed_tests"

    if [ $failed_tests -gt 0 ]; then
      exit 1
    fi
  '';
}
