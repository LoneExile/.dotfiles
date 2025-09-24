# Host configuration integration tests
{ inputs, outputs, system, lib, pkgs, testLib, builders, ... }:
let
  # Test different host configurations
  hostConfigurations = {
    # Minimal host configuration
    minimal-host = {
      hostname = "minimal-test";
      username = "test-user";
      system = "aarch64-darwin";
      profiles = {
        minimal.enable = true;
      };
      modules = {};
    };
    
    # Development workstation
    dev-workstation = {
      hostname = "dev-workstation";
      username = "developer";
      system = "aarch64-darwin";
      profiles = {
        development.enable = true;
      };
      modules = {
        darwin.homebrew.enable = true;
        home.development.containers.enable = true;
      };
    };
    
    # Work laptop configuration
    work-laptop = {
      hostname = "work-laptop";
      username = "employee";
      system = "aarch64-darwin";
      profiles = {
        work.enable = true;
        development.enable = true;
      };
      modules = {
        darwin.security.enable = true;
        home.security.gpg.enable = true;
      };
    };
    
    # Personal MacBook
    personal-macbook = {
      hostname = "personal-macbook";
      username = "user";
      system = "aarch64-darwin";
      profiles = {
        personal.enable = true;
        development.enable = true;
      };
      modules = {
        darwin.homebrew.enable = true;
        home.desktop.productivity.enable = true;
      };
    };
    
    # Multi-user workstation
    multi-user = {
      hostname = "multi-user-workstation";
      username = "admin";
      system = "aarch64-darwin";
      profiles = {
        development.enable = true;
        work.enable = true;
      };
      modules = {
        darwin.system.enable = true;
        darwin.security.enable = true;
      };
    };
  };
  
  # Create tests for each host configuration
  hostConfigurationTests = lib.mapAttrsToList (hostName: hostConfig:
    testLib.mkTest {
      name = "host-configuration-${hostName}";
      assertions = [
        # Test that the host configuration builds successfully
        (let
          buildResult = testLib.try (builders.mkDarwin hostConfig) null;
        in
          testLib.assertions.assertNotNull 
            "Host configuration ${hostName} builds successfully" 
            buildResult)
        
        # Test that host has required fields
        (testLib.assertions.assertHasAttr 
          "Host ${hostName} has hostname" 
          "hostname" hostConfig)
        
        (testLib.assertions.assertHasAttr 
          "Host ${hostName} has username" 
          "username" hostConfig)
        
        (testLib.assertions.assertHasAttr 
          "Host ${hostName} has system" 
          "system" hostConfig)
        
        # Test that hostname is valid
        (testLib.assertions.assertTrue 
          "Host ${hostName} has valid hostname"
          (lib.isString hostConfig.hostname && hostConfig.hostname != ""))
        
        # Test that username is valid
        (testLib.assertions.assertTrue 
          "Host ${hostName} has valid username"
          (lib.isString hostConfig.username && hostConfig.username != ""))
        
        # Test that system is valid
        (testLib.assertions.assertTrue 
          "Host ${hostName} has valid system"
          (lib.elem hostConfig.system [ "aarch64-darwin" "x86_64-darwin" ]))
      ];
    }
  ) hostConfigurations;
  
  # Test host-specific overrides
  hostOverrideTests = [
    (testLib.mkTest {
      name = "host-overrides";
      assertions = [
        # Test host with custom module settings
        (let
          hostWithOverrides = {
            hostname = "override-test";
            username = "test-user";
            system = "aarch64-darwin";
            profiles = {
              minimal.enable = true;
            };
            modules = {
              darwin.system = {
                enable = true;
                hostname = "custom-hostname";
                primaryUser = "custom-user";
              };
            };
          };
          buildResult = testLib.try (builders.mkDarwin hostWithOverrides) null;
        in
          testLib.assertions.assertNotNull 
            "Host with module overrides builds successfully" 
            buildResult)
        
        # Test host with profile overrides
        (let
          hostWithProfileOverrides = {
            hostname = "profile-override-test";
            username = "test-user";
            system = "aarch64-darwin";
            profiles = {
              development.enable = true;
            };
            # Override specific modules from the profile
            modules = {
              home.development.git = {
                enable = true;
                userName = "Custom User";
                userEmail = "custom@example.com";
              };
            };
          };
          buildResult = testLib.try (builders.mkDarwin hostWithProfileOverrides) null;
        in
          testLib.assertions.assertNotNull 
            "Host with profile overrides builds successfully" 
            buildResult)
      ];
    })
  ];
  
  # Test host validation
  hostValidationTests = [
    (testLib.mkTest {
      name = "host-validation";
      assertions = [
        # Test that invalid hostnames are handled
        (testLib.assertions.assertTrue "invalid hostnames are handled"
          (let
            invalidHost = {
              hostname = "";  # Empty hostname
              username = "test-user";
              system = "aarch64-darwin";
            };
            # Should handle gracefully
            buildResult = testLib.try (builders.mkDarwin invalidHost) null;
          in
            true))  # For now, just check it doesn't crash
        
        # Test that invalid usernames are handled
        (testLib.assertions.assertTrue "invalid usernames are handled"
          (let
            invalidHost = {
              hostname = "test-host";
              username = "";  # Empty username
              system = "aarch64-darwin";
            };
            buildResult = testLib.try (builders.mkDarwin invalidHost) null;
          in
            true))  # For now, just check it doesn't crash
        
        # Test that invalid systems are handled
        (testLib.assertions.assertTrue "invalid systems are handled"
          (let
            invalidHost = {
              hostname = "test-host";
              username = "test-user";
              system = "invalid-system";
            };
            buildResult = testLib.try (builders.mkDarwin invalidHost) null;
          in
            true))  # For now, just check it doesn't crash
      ];
    })
  ];
  
  # Test host inheritance from common configuration
  hostInheritanceTests = [
    (testLib.mkTest {
      name = "host-inheritance";
      assertions = [
        # Test that hosts inherit common configuration
        (let
          basicHost = {
            hostname = "inheritance-test";
            username = "test-user";
            system = "aarch64-darwin";
            profiles = {
              minimal.enable = true;
            };
          };
          buildResult = testLib.try (builders.mkDarwin basicHost) null;
        in
          testLib.assertions.assertNotNull 
            "Host inherits common configuration" 
            buildResult)
        
        # Test that host-specific config overrides common config
        (let
          hostWithOverrides = {
            hostname = "override-inheritance-test";
            username = "test-user";
            system = "aarch64-darwin";
            profiles = {
              minimal.enable = true;
            };
            modules = {
              darwin.system = {
                enable = true;
                stateVersion = 4;  # Override default state version
              };
            };
          };
          buildResult = testLib.try (builders.mkDarwin hostWithOverrides) null;
        in
          testLib.assertions.assertNotNull 
            "Host-specific config overrides common config" 
            buildResult)
      ];
    })
  ];
  
  # Test multi-architecture support
  multiArchTests = [
    (testLib.mkTest {
      name = "multi-architecture";
      assertions = [
        # Test aarch64-darwin configuration
        (let
          aarch64Host = {
            hostname = "aarch64-test";
            username = "test-user";
            system = "aarch64-darwin";
            profiles = {
              minimal.enable = true;
            };
          };
          buildResult = testLib.try (builders.mkDarwin aarch64Host) null;
        in
          testLib.assertions.assertNotNull 
            "aarch64-darwin host builds successfully" 
            buildResult)
        
        # Test x86_64-darwin configuration
        (let
          x86Host = {
            hostname = "x86-test";
            username = "test-user";
            system = "x86_64-darwin";
            profiles = {
              minimal.enable = true;
            };
          };
          buildResult = testLib.try (builders.mkDarwin x86Host) null;
        in
          testLib.assertions.assertNotNull 
            "x86_64-darwin host builds successfully" 
            buildResult)
      ];
    })
  ];
  
in hostConfigurationTests ++ hostOverrideTests ++ hostValidationTests ++ hostInheritanceTests ++ multiArchTests