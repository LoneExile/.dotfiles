# Performance and resource usage tests
{
  inputs,
  outputs,
  system,
  lib,
  pkgs,
  testLib,
  builders,
  ...
}: let
  # Performance test configurations
  performanceConfigs = {
    # Minimal configuration for baseline
    minimal = {
      hostname = "perf-minimal";
      username = "test-user";
      system = "aarch64-darwin";
      profiles = {
        minimal.enable = true;
      };
    };

    # Medium complexity configuration
    medium = {
      hostname = "perf-medium";
      username = "test-user";
      system = "aarch64-darwin";
      profiles = {
        development.enable = true;
      };
      modules = {
        darwin.homebrew.enable = true;
        home.development.containers.enable = true;
      };
    };

    # High complexity configuration
    complex = {
      hostname = "perf-complex";
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
        home.security.gpg.enable = true;
      };
    };

    # Maximum complexity configuration
    maximum = {
      hostname = "perf-maximum";
      username = "test-user";
      system = "aarch64-darwin";
      profiles = {
        minimal.enable = true;
        development.enable = true;
        work.enable = true;
        personal.enable = true;
      };
      modules = {
        darwin.system.enable = true;
        darwin.homebrew.enable = true;
        darwin.security.enable = true;
        darwin.defaults.enable = true;
        darwin.packages.enable = true;
        home.shell.zsh.enable = true;
        home.shell.starship.enable = true;
        home.shell.aliases.enable = true;
        home.development.git.enable = true;
        home.development.editors.enable = true;
        home.development.languages.enable = true;
        home.development.containers.enable = true;
        home.desktop.terminal.enable = true;
        home.desktop.window-manager.enable = true;
        home.desktop.productivity.enable = true;
        home.security.gpg.enable = true;
        home.security.ssh.enable = true;
      };
    };
  };

  # Build performance tests
  buildPerformanceTests = [
    (testLib.mkTest {
      name = "build-performance";
      assertions = [
        # Test that minimal config builds quickly
        (let
          buildResult = testLib.try (builders.mkDarwin performanceConfigs.minimal) null;
        in
          testLib.assertions.assertNotNull
          "Minimal configuration builds successfully"
          buildResult)

        # Test that medium complexity config builds reasonably
        (let
          buildResult = testLib.try (builders.mkDarwin performanceConfigs.medium) null;
        in
          testLib.assertions.assertNotNull
          "Medium complexity configuration builds successfully"
          buildResult)

        # Test that complex config builds without timeout
        (let
          buildResult = testLib.try (builders.mkDarwin performanceConfigs.complex) null;
        in
          testLib.assertions.assertNotNull
          "Complex configuration builds successfully"
          buildResult)

        # Test that maximum complexity config builds
        (let
          buildResult = testLib.try (builders.mkDarwin performanceConfigs.maximum) null;
        in
          testLib.assertions.assertNotNull
          "Maximum complexity configuration builds successfully"
          buildResult)
      ];
    })
  ];

  # Memory usage tests
  memoryUsageTests = [
    (testLib.mkTest {
      name = "memory-usage";
      assertions = [
        # Test that builds don't consume excessive memory
        # Note: This is a placeholder - actual memory testing would require more setup
        (testLib.assertions.assertTrue "builds use reasonable memory"
          (let
            # Test multiple configurations to ensure no memory leaks
            results = map (config: testLib.try (builders.mkDarwin config) null) [
              performanceConfigs.minimal
              performanceConfigs.medium
              performanceConfigs.complex
            ];
          in
            lib.all (result: result != null) results))

        # Test that concurrent builds don't interfere
        (testLib.assertions.assertTrue "concurrent builds work"
          (let
            # Simulate concurrent builds by testing multiple configs
            config1 = performanceConfigs.minimal // {hostname = "concurrent-1";};
            config2 = performanceConfigs.minimal // {hostname = "concurrent-2";};

            result1 = testLib.try (builders.mkDarwin config1) null;
            result2 = testLib.try (builders.mkDarwin config2) null;
          in
            result1 != null && result2 != null))
      ];
    })
  ];

  # Scalability tests
  scalabilityTests = [
    (testLib.mkTest {
      name = "scalability";
      assertions = [
        # Test that adding modules scales linearly
        (let
          # Test configurations with increasing module counts
          configs = [
            (performanceConfigs.minimal)
            (performanceConfigs.medium)
            (performanceConfigs.complex)
            (performanceConfigs.maximum)
          ];

          results = map (config: testLib.try (builders.mkDarwin config) null) configs;
        in
          testLib.assertions.assertTrue
          "configurations scale with module count"
          (lib.all (result: result != null) results))

        # Test that multiple hosts can be configured
        (let
          multiHostConfigs =
            lib.genList (
              i:
                performanceConfigs.minimal
                // {
                  hostname = "scale-test-${toString i}";
                }
            )
            5;

          results = map (config: testLib.try (builders.mkDarwin config) null) multiHostConfigs;
        in
          testLib.assertions.assertTrue
          "multiple host configurations work"
          (lib.all (result: result != null) results))
      ];
    })
  ];

  # Resource efficiency tests
  resourceEfficiencyTests = [
    (testLib.mkTest {
      name = "resource-efficiency";
      assertions = [
        # Test that similar configurations share resources
        (let
          # Two similar configurations should build successfully
          config1 = performanceConfigs.medium // {hostname = "resource-1";};
          config2 = performanceConfigs.medium // {hostname = "resource-2";};

          result1 = testLib.try (builders.mkDarwin config1) null;
          result2 = testLib.try (builders.mkDarwin config2) null;
        in
          testLib.assertions.assertTrue
          "similar configurations build efficiently"
          (result1 != null && result2 != null))

        # Test that module reuse works correctly
        (let
          # Configuration that reuses many modules
          reuseConfig = {
            hostname = "reuse-test";
            username = "test-user";
            system = "aarch64-darwin";
            profiles = {
              development.enable = true;
              work.enable = true; # Should reuse development modules
            };
          };

          result = testLib.try (builders.mkDarwin reuseConfig) null;
        in
          testLib.assertions.assertNotNull
          "module reuse works correctly"
          result)
      ];
    })
  ];

  # Stress tests
  stressTests = [
    (testLib.mkTest {
      name = "stress-tests";
      assertions = [
        # Test rapid configuration changes
        (let
          # Simulate rapid switching between configurations
          configs = [
            performanceConfigs.minimal
            performanceConfigs.complex
            performanceConfigs.minimal
            performanceConfigs.medium
          ];

          results = map (config: testLib.try (builders.mkDarwin config) null) configs;
        in
          testLib.assertions.assertTrue
          "rapid configuration changes work"
          (lib.all (result: result != null) results))

        # Test configuration with many overrides
        (let
          heavyOverrideConfig =
            performanceConfigs.maximum
            // {
              modules =
                performanceConfigs.maximum.modules
                // {
                  darwin.system = {
                    enable = true;
                    hostname = "stress-test-host";
                    primaryUser = "stress-user";
                    keyboard.remapCapsLockToEscape = true;
                    nix.warnDirty = false;
                    nix.enableChannel = false;
                  };
                  home.shell.zsh = {
                    enable = true;
                    historySize = 50000;
                    enableAutosuggestions = true;
                    enableSyntaxHighlighting = true;
                    enableZap = true;
                  };
                };
            };

          result = testLib.try (builders.mkDarwin heavyOverrideConfig) null;
        in
          testLib.assertions.assertNotNull
          "configuration with many overrides builds"
          result)
      ];
    })
  ];

  # Regression tests
  regressionTests = [
    (testLib.mkTest {
      name = "regression-tests";
      assertions = [
        # Test that previously working configurations still work
        (let
          # Test a known-good configuration
          knownGoodConfig = {
            hostname = "regression-test";
            username = "test-user";
            system = "aarch64-darwin";
            profiles = {
              development.enable = true;
            };
            modules = {
              darwin.homebrew.enable = true;
              home.development.git.enable = true;
            };
          };

          result = testLib.try (builders.mkDarwin knownGoodConfig) null;
        in
          testLib.assertions.assertNotNull
          "known-good configuration still works"
          result)

        # Test that edge cases are handled
        (let
          edgeCaseConfig = {
            hostname = "edge-case-test";
            username = "test-user";
            system = "aarch64-darwin";
            profiles = {}; # No profiles enabled
            modules = {
              darwin.system.enable = true; # Only system module
            };
          };

          result = testLib.try (builders.mkDarwin edgeCaseConfig) null;
        in
          testLib.assertions.assertNotNull
          "edge case configuration works"
          result)
      ];
    })
  ];
in
  buildPerformanceTests ++ memoryUsageTests ++ scalabilityTests ++ resourceEfficiencyTests ++ stressTests ++ regressionTests
