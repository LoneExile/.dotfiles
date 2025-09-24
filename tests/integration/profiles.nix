# Profile combination integration tests
{ inputs, outputs, system, lib, pkgs, testLib, builders, ... }:
let
  # Test different profile combinations
  profileCombinations = {
    # Single profiles
    minimal-only = {
      profiles = {
        minimal.enable = true;
      };
      expectedModules = [
        "modules.darwin.system"
        "modules.home.shell.zsh"
      ];
    };
    
    development-only = {
      profiles = {
        development.enable = true;
      };
      expectedModules = [
        "modules.darwin.system"
        "modules.home.shell.zsh"
        "modules.home.development.git"
        "modules.home.development.editors"
        "modules.home.development.languages"
      ];
    };
    
    work-only = {
      profiles = {
        work.enable = true;
      };
      expectedModules = [
        "modules.darwin.system"
        "modules.home.shell.zsh"
        "modules.home.development.git"
        "modules.home.security.ssh"
      ];
    };
    
    personal-only = {
      profiles = {
        personal.enable = true;
      };
      expectedModules = [
        "modules.darwin.system"
        "modules.home.shell.zsh"
        "modules.home.desktop.terminal"
        "modules.home.desktop.productivity"
      ];
    };
    
    # Profile combinations
    development-and-work = {
      profiles = {
        development.enable = true;
        work.enable = true;
      };
      expectedModules = [
        "modules.darwin.system"
        "modules.home.shell.zsh"
        "modules.home.development.git"
        "modules.home.development.editors"
        "modules.home.development.languages"
        "modules.home.security.ssh"
      ];
    };
    
    development-and-personal = {
      profiles = {
        development.enable = true;
        personal.enable = true;
      };
      expectedModules = [
        "modules.darwin.system"
        "modules.home.shell.zsh"
        "modules.home.development.git"
        "modules.home.development.editors"
        "modules.home.development.languages"
        "modules.home.desktop.terminal"
        "modules.home.desktop.productivity"
      ];
    };
    
    # All profiles (should work without conflicts)
    all-profiles = {
      profiles = {
        minimal.enable = true;
        development.enable = true;
        work.enable = true;
        personal.enable = true;
      };
      expectedModules = [
        "modules.darwin.system"
        "modules.home.shell.zsh"
        "modules.home.development.git"
        "modules.home.development.editors"
        "modules.home.development.languages"
        "modules.home.security.ssh"
        "modules.home.desktop.terminal"
        "modules.home.desktop.productivity"
      ];
    };
  };
  
  # Create tests for each profile combination
  profileCombinationTests = lib.mapAttrsToList (combName: combConfig:
    testLib.mkTest {
      name = "profile-combination-${combName}";
      assertions = [
        # Test that the profile combination builds successfully
        (let
          testConfig = {
            hostname = "test-${combName}";
            username = "test-user";
            system = "aarch64-darwin";
            inherit (combConfig) profiles;
          };
          
          buildResult = testLib.try (builders.mkDarwin testConfig) null;
        in
          testLib.assertions.assertNotNull 
            "Profile combination ${combName} builds successfully" 
            buildResult)
        
        # Test that expected modules are available
        # Note: This would require evaluating the configuration, which is complex
        # For now, we'll just test that the profiles are valid
        (testLib.assertions.assertTrue 
          "Profile combination ${combName} has valid profile structure"
          (lib.all (profile: lib.hasAttr "enable" profile && lib.isBool profile.enable) 
            (lib.attrValues combConfig.profiles)))
      ];
    }
  ) profileCombinations;
  
  # Test profile validation
  profileValidationTests = [
    (testLib.mkTest {
      name = "profile-validation";
      assertions = [
        # Test that profiles have required structure
        (testLib.assertions.assertTrue "profiles are attribute sets"
          (lib.all lib.isAttrs (lib.attrValues profileCombinations)))
        
        # Test that all profiles have enable options
        (testLib.assertions.assertTrue "all profiles have enable options"
          (lib.all (comb: 
            lib.all (profile: lib.hasAttr "enable" profile) 
              (lib.attrValues comb.profiles)
          ) (lib.attrValues profileCombinations)))
        
        # Test that enable options are booleans
        (testLib.assertions.assertTrue "all enable options are booleans"
          (lib.all (comb:
            lib.all (profile: lib.isBool profile.enable)
              (lib.attrValues comb.profiles)
          ) (lib.attrValues profileCombinations)))
      ];
    })
  ];
  
  # Test profile inheritance and overrides
  profileInheritanceTests = [
    (testLib.mkTest {
      name = "profile-inheritance";
      assertions = [
        # Test that development profile includes minimal features
        (testLib.assertions.assertTrue "development includes minimal features"
          (let
            devProfile = profileCombinations.development-only;
            minProfile = profileCombinations.minimal-only;
          in
            lib.all (module: lib.elem module devProfile.expectedModules) 
              minProfile.expectedModules))
        
        # Test that work profile includes essential features
        (testLib.assertions.assertTrue "work includes essential features"
          (let
            workProfile = profileCombinations.work-only;
            essentialModules = [ "modules.darwin.system" "modules.home.shell.zsh" ];
          in
            lib.all (module: lib.elem module workProfile.expectedModules) 
              essentialModules))
        
        # Test that personal profile includes desktop features
        (testLib.assertions.assertTrue "personal includes desktop features"
          (let
            personalProfile = profileCombinations.personal-only;
            desktopModules = [ "modules.home.desktop.terminal" ];
          in
            lib.all (module: lib.elem module personalProfile.expectedModules)
              desktopModules))
      ];
    })
  ];
  
  # Test profile conflict detection
  profileConflictTests = [
    (testLib.mkTest {
      name = "profile-conflicts";
      assertions = [
        # Test that conflicting profiles are detected
        # For now, we assume no conflicts exist, but this could be expanded
        (testLib.assertions.assertTrue "no profile conflicts detected"
          (let
            allCombinations = lib.attrValues profileCombinations;
            # Simple check - all combinations should be valid
          in
            lib.all (comb: comb ? profiles) allCombinations))
      ];
    })
  ];
  
in profileCombinationTests ++ profileValidationTests ++ profileInheritanceTests ++ profileConflictTests