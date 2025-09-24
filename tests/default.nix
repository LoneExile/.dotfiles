# Test suite for modular Nix configuration
{
  inputs,
  outputs,
  system ? "aarch64-darwin",
  lib,
  ...
}: let
  pkgs = inputs.nixpkgs.legacyPackages.${system};

  # Import test modules
  moduleTests = import ./modules {inherit inputs outputs system lib pkgs;};
  libTests = import ./lib {inherit inputs outputs system lib pkgs;};
  integrationTests = import ./integration {inherit inputs outputs system lib pkgs;};
  systemTests = import ./system {inherit inputs outputs system lib pkgs;};
in {
  # Unit tests for individual modules
  unit = {
    modules = moduleTests;
    lib = libTests;
  };

  # Integration tests for module combinations
  integration = integrationTests;

  # System-level tests
  system = systemTests;

  # Test runner utilities
  utils = import ./utils {inherit inputs outputs system lib pkgs;};

  # Run all tests
  runAll = pkgs.writeShellScriptBin "run-all-tests" ''
    echo "Running all tests for modular Nix configuration..."

    echo "=== Unit Tests ==="
    ${moduleTests.runTests}/bin/run-module-tests
    ${libTests.runTests}/bin/run-lib-tests

    echo "=== Integration Tests ==="
    ${integrationTests.runTests}/bin/run-integration-tests

    echo "=== System Tests ==="
    ${systemTests.runTests}/bin/run-system-tests

    echo "All tests completed!"
  '';
}
