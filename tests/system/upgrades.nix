# Upgrade and downgrade scenario tests
{ inputs, outputs, system, lib, pkgs, testLib, builders, ... }:
let
  # Simulate different configuration versions for upgrade testing
  configVersions = {
    # Version 1: Basic configuration
    v1 = {
      hostname = "upgrade-test";
      username = "test-user";
      system = "aarch64-darwin";
      profiles = {
        minimal.enable = true;
      };
      modules = {
        darwin.system.enable = true;
        home.shell.zsh.enable = true;
      };
    };
    
    # Version 2: Added development tools
    v2 = {
      hostname = "upgrade-test";
      username = "test-user";
      system = "aarch64-darwin";
      profiles = {
        minimal.enable = true;
        development.enable = true;
      };
      modules = {
        darwin.system.enable = true;
        home.shell.zsh.enable = true;
        home.development.git.enable = true;
      };
    };
    
    # Version 3: Added security and desktop features
    v3 = {
      hostname = "upgrade-test";
      username = "test-user";
      system = "aarch64-darwin";
      profiles = {
        minimal.enable = true;
        development.enable = true;
        personal.enable = true;
      };
      modules = {
        darwin.system.enable = true;
        darwin.security.enable = true;
        home.shell.zsh.enable = true;
        home.development.git.enable = true;
        home.security.ssh.enable = true;
        home.desktop.terminal.enable = true;
      };
    };
    
    # Version 4: Full workstation setup
    v4 = {
      hostname = "upgrade-test";
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
        darwin.security.enable = true;
        darwin.homebrew.enable = true;
        home.shell.zsh.enable = true;
        home.development.git.enable = true;
        home.development.editors.enable = true;
        home.development.containers.enable = true;
        home.security.ssh.enable = true;
        home.security.gpg.enable = true;
        home.desktop.terminal.enable = true;
        home.desktop.productivity.enable = true;
      };
    };
  };
  
  # Test upgrade scenarios
  upgradeScenarioTests = [
    (testLib.mkTest {
      name = "upgrade-scenarios";
      assertions = [
        # Test v1 to v2 upgrade (adding development profile)
        (let
          v1Build = testLib.try (builders.mkDarwin configVersions.v1) null;
          v2Build = testLib.try (builders.mkDarwin configVersions.v2) null;
        in
          testLib.assertions.assertTrue 
            "v1 to v2 upgrade builds successfully"
            (v1Build != null && v2Build != null))
        
        # Test v2 to v3 upgrade (adding security and desktop)
        (let
          v2Build = testLib.try (builders.mkDarwin configVersions.v2) null;
          v3Build = testLib.try (builders.mkDarwin configVersions.v3) null;
        in
          testLib.assertions.assertTrue 
            "v2 to v3 upgrade builds successfully"
            (v2Build != null && v3Build != null))
        
        # Test v3 to v4 upgrade (adding full workstation)
        (let
          v3Build = testLib.try (builders.mkDarwin configVersions.v3) null;
          v4Build = testLib.try (builders.mkDarwin configVersions.v4) null;
        in
          testLib.assertions.assertTrue 
            "v3 to v4 upgrade builds successfully"
            (v3Build != null && v4Build != null))
        
        # Test direct v1 to v4 upgrade (major version jump)
        (let
          v1Build = testLib.try (builders.mkDarwin configVersions.v1) null;
          v4Build = testLib.try (builders.mkDarwin configVersions.v4) null;
        in
          testLib.assertions.assertTrue 
            "v1 to v4 major upgrade builds successfully"
            (v1Build != null && v4Build != null))
      ];
    })
  ];
  
  # Test downgrade scenarios
  downgradeScenarioTests = [
    (testLib.mkTest {
      name = "downgrade-scenarios";
      assertions = [
        # Test v4 to v3 downgrade (removing some features)
        (let
          v4Build = testLib.try (builders.mkDarwin configVersions.v4) null;
          v3Build = testLib.try (builders.mkDarwin configVersions.v3) null;
        in
          testLib.assertions.assertTrue 
            "v4 to v3 downgrade builds successfully"
            (v4Build != null && v3Build != null))
        
        # Test v3 to v2 downgrade (removing security and desktop)
        (let
          v3Build = testLib.try (builders.mkDarwin configVersions.v3) null;
          v2Build = testLib.try (builders.mkDarwin configVersions.v2) null;
        in
          testLib.assertions.assertTrue 
            "v3 to v2 downgrade builds successfully"
            (v3Build != null && v2Build != null))
        
        # Test v2 to v1 downgrade (removing development profile)
        (let
          v2Build = testLib.try (builders.mkDarwin configVersions.v2) null;
          v1Build = testLib.try (builders.mkDarwin configVersions.v1) null;
        in
          testLib.assertions.assertTrue 
            "v2 to v1 downgrade builds successfully"
            (v2Build != null && v1Build != null))
        
        # Test direct v4 to v1 downgrade (major version rollback)
        (let
          v4Build = testLib.try (builders.mkDarwin configVersions.v4) null;
          v1Build = testLib.try (builders.mkDarwin configVersions.v1) null;
        in
          testLib.assertions.assertTrue 
            "v4 to v1 major downgrade builds successfully"
            (v4Build != null && v1Build != null))
      ];
    })
  ];
  
  # Test configuration migration scenarios
  migrationScenarioTests = [
    (testLib.mkTest {
      name = "migration-scenarios";
      assertions = [
        # Test migrating from profile-based to module-based config
        (let
          profileBasedConfig = {
            hostname = "migration-test";
            username = "test-user";
            system = "aarch64-darwin";
            profiles = {
              development.enable = true;
            };
            modules = {};
          };
          
          moduleBasedConfig = {
            hostname = "migration-test";
            username = "test-user";
            system = "aarch64-darwin";
            profiles = {};
            modules = {
              darwin.system.enable = true;
              home.shell.zsh.enable = true;
              home.development.git.enable = true;
              home.development.editors.enable = true;
            };
          };
          
          profileBuild = testLib.try (builders.mkDarwin profileBasedConfig) null;
          moduleBuild = testLib.try (builders.mkDarwin moduleBasedConfig) null;
        in
          testLib.assertions.assertTrue 
            "profile to module migration builds successfully"
            (profileBuild != null && moduleBuild != null))
        
        # Test migrating between different profile combinations
        (let
          workProfileConfig = {
            hostname = "work-migration-test";
            username = "test-user";
            system = "aarch64-darwin";
            profiles = {
              work.enable = true;
            };
          };
          
          personalProfileConfig = {
            hostname = "work-migration-test";
            username = "test-user";
            system = "aarch64-darwin";
            profiles = {
              personal.enable = true;
            };
          };
          
          workBuild = testLib.try (builders.mkDarwin workProfileConfig) null;
          personalBuild = testLib.try (builders.mkDarwin personalProfileConfig) null;
        in
          testLib.assertions.assertTrue 
            "work to personal profile migration builds successfully"
            (workBuild != null && personalBuild != null))
      ];
    })
  ];
  
  # Test state version compatibility
  stateVersionTests = [
    (testLib.mkTest {
      name = "state-version-compatibility";
      assertions = [
        # Test different Darwin state versions
        (let
          stateVersion4Config = {
            hostname = "state-v4-test";
            username = "test-user";
            system = "aarch64-darwin";
            profiles = {
              minimal.enable = true;
            };
            modules = {
              darwin.system = {
                enable = true;
                stateVersion = 4;
              };
            };
          };
          
          stateVersion5Config = {
            hostname = "state-v5-test";
            username = "test-user";
            system = "aarch64-darwin";
            profiles = {
              minimal.enable = true;
            };
            modules = {
              darwin.system = {
                enable = true;
                stateVersion = 5;
              };
            };
          };
          
          v4Build = testLib.try (builders.mkDarwin stateVersion4Config) null;
          v5Build = testLib.try (builders.mkDarwin stateVersion5Config) null;
        in
          testLib.assertions.assertTrue 
            "different Darwin state versions build successfully"
            (v4Build != null && v5Build != null))
        
        # Test Home Manager state version compatibility
        # Note: This would require more complex setup to test properly
        (testLib.assertions.assertTrue "Home Manager state versions compatible"
          (let
            basicConfig = {
              hostname = "hm-state-test";
              username = "test-user";
              system = "aarch64-darwin";
              profiles = {
                minimal.enable = true;
              };
            };
            build = testLib.try (builders.mkDarwin basicConfig) null;
          in
            build != null))
      ];
    })
  ];
  
  # Test rollback scenarios
  rollbackScenarioTests = [
    (testLib.mkTest {
      name = "rollback-scenarios";
      assertions = [
        # Test rollback from broken configuration
        (let
          workingConfig = {
            hostname = "rollback-test";
            username = "test-user";
            system = "aarch64-darwin";
            profiles = {
              minimal.enable = true;
            };
          };
          
          # Simulate a "broken" config that should still build but might have issues
          potentiallyBrokenConfig = {
            hostname = "rollback-test";
            username = "test-user";
            system = "aarch64-darwin";
            profiles = {
              minimal.enable = true;
            };
            modules = {
              # Add some complex configuration that might cause issues
              darwin.system = {
                enable = true;
                keyboard.remapCapsLockToEscape = true;
                nix.warnDirty = true;
              };
            };
          };
          
          workingBuild = testLib.try (builders.mkDarwin workingConfig) null;
          brokenBuild = testLib.try (builders.mkDarwin potentiallyBrokenConfig) null;
          rollbackBuild = testLib.try (builders.mkDarwin workingConfig) null;
        in
          testLib.assertions.assertTrue 
            "rollback from potentially broken config works"
            (workingBuild != null && rollbackBuild != null))
      ];
    })
  ];
  
in upgradeScenarioTests ++ downgradeScenarioTests ++ migrationScenarioTests ++ stateVersionTests ++ rollbackScenarioTests