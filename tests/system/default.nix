# System-level tests for full configuration builds and scenarios
{ inputs, outputs, system, lib, pkgs, ... }:
let
  # Test framework utilities
  testLib = import ../utils/test-framework.nix { inherit lib pkgs; };
  
  # Import builders for testing
  builders = import ../../lib/builders.nix { inherit inputs outputs; };
  
  # Full system build tests
  buildTests = import ./builds.nix { inherit inputs outputs system lib pkgs testLib builders; };
  
  # Upgrade/downgrade scenario tests
  upgradeTests = import ./upgrades.nix { inherit inputs outputs system lib pkgs testLib builders; };
  
  # Performance and resource tests
  performanceTests = import ./performance.nix { inherit inputs outputs system lib pkgs testLib builders; };
  
  # Combine all system tests
  allTests = buildTests ++ upgradeTests ++ performanceTests;
  
in {
  # Individual test categories
  builds = buildTests;
  upgrades = upgradeTests;
  performance = performanceTests;
  
  # All system tests combined
  tests = allTests;
  
  # Test runner
  runTests = pkgs.writeShellScriptBin "run-system-tests" ''
    echo "Running system tests..."
    
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
    '') allTests)}
    
    echo ""
    echo "System Tests Summary:"
    echo "  Total: $total_tests"
    echo "  Passed: $passed_tests"
    echo "  Failed: $failed_tests"
    
    if [ $failed_tests -gt 0 ]; then
      exit 1
    fi
  '';
}