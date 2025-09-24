# Test validation utilities
{
  lib,
  pkgs,
  ...
}: let
  # Validate test results
  validateTestResult = result: let
    hasRequiredFields =
      lib.hasAttr "name" result
      && lib.hasAttr "success" result
      && lib.hasAttr "total" result
      && lib.hasAttr "passed" result
      && lib.hasAttr "failed" result;

    validTypes =
      lib.isString result.name
      && lib.isBool result.success
      && lib.isInt result.total
      && lib.isInt result.passed
      && lib.isInt result.failed;

    mathChecks =
      result.total
      == (result.passed + result.failed)
      && result.passed >= 0
      && result.failed >= 0
      && result.total >= 0;

    successConsistency =
      result.success == (result.failed == 0);
  in {
    valid = hasRequiredFields && validTypes && mathChecks && successConsistency;
    errors =
      (
        if !hasRequiredFields
        then ["Missing required fields in test result"]
        else []
      )
      ++ (
        if !validTypes
        then ["Invalid field types in test result"]
        else []
      )
      ++ (
        if !mathChecks
        then ["Math inconsistency in test counts"]
        else []
      )
      ++ (
        if !successConsistency
        then ["Success flag inconsistent with failure count"]
        else []
      );
  };

  # Validate test suite structure
  validateTestSuite = suite: let
    hasRequiredFields =
      lib.hasAttr "tests" suite
      && lib.hasAttr "runTests" suite;

    validTests =
      lib.isList suite.tests
      && lib.all (
        test:
          lib.hasAttr "name" test
          && lib.hasAttr "command" test
          && lib.isString test.name
          && lib.isString test.command
      )
      suite.tests;

    validRunner =
      lib.isDerivation suite.runTests;
  in {
    valid = hasRequiredFields && validTests && validRunner;
    errors = lib.flatten [
      (lib.optional (!hasRequiredFields) "Missing required fields in test suite")
      (lib.optional (!validTests) "Invalid test structure")
      (lib.optional (!validRunner) "Invalid test runner")
    ];
  };

  # Validate test configuration
  validateTestConfiguration = config: let
    # Check basic structure
    hasBasicFields =
      lib.hasAttr "hostname" config
      && lib.hasAttr "username" config
      && lib.hasAttr "system" config;

    # Check field types
    validBasicTypes =
      lib.isString config.hostname
      && lib.isString config.username
      && lib.isString config.system;

    # Check hostname format
    validHostname =
      config.hostname
      != ""
      && !(lib.hasInfix " " config.hostname)
      && lib.stringLength config.hostname <= 63;

    # Check username format
    validUsername =
      config.username
      != ""
      && !(lib.hasInfix " " config.username)
      && lib.stringLength config.username <= 32;

    # Check system format
    validSystem = lib.elem config.system [
      "aarch64-darwin"
      "x86_64-darwin"
      "aarch64-linux"
      "x86_64-linux"
    ];

    # Check profiles structure
    validProfiles =
      if lib.hasAttr "profiles" config
      then
        lib.isAttrs config.profiles
        && lib.all (
          profile:
            lib.hasAttr "enable" profile
            && lib.isBool profile.enable
        ) (lib.attrValues config.profiles)
      else true;

    # Check modules structure
    validModules =
      if lib.hasAttr "modules" config
      then lib.isAttrs config.modules
      else true;
  in {
    valid =
      hasBasicFields
      && validBasicTypes
      && validHostname
      && validUsername
      && validSystem
      && validProfiles
      && validModules;
    errors = lib.flatten [
      (lib.optional (!hasBasicFields) "Missing basic configuration fields")
      (lib.optional (!validBasicTypes) "Invalid basic field types")
      (lib.optional (!validHostname) "Invalid hostname format")
      (lib.optional (!validUsername) "Invalid username format")
      (lib.optional (!validSystem) "Invalid system specification")
      (lib.optional (!validProfiles) "Invalid profiles structure")
      (lib.optional (!validModules) "Invalid modules structure")
    ];
  };

  # Validate module configuration
  validateModuleConfiguration = moduleConfig: let
    # Check enable field
    hasEnable = lib.hasAttr "enable" moduleConfig;
    enableIsBoolean = hasEnable && lib.isBool moduleConfig.enable;

    # Check optional fields
    packageValid =
      if lib.hasAttr "package" moduleConfig
      then moduleConfig.package == null || lib.isDerivation moduleConfig.package
      else true;

    settingsValid =
      if lib.hasAttr "settings" moduleConfig
      then lib.isAttrs moduleConfig.settings
      else true;

    extraConfigValid =
      if lib.hasAttr "extraConfig" moduleConfig
      then lib.isAttrs moduleConfig.extraConfig
      else true;
  in {
    valid = hasEnable && enableIsBoolean && packageValid && settingsValid && extraConfigValid;
    errors = lib.flatten [
      (lib.optional (!hasEnable) "Missing enable field")
      (lib.optional (!enableIsBoolean) "Enable field must be boolean")
      (lib.optional (!packageValid) "Invalid package specification")
      (lib.optional (!settingsValid) "Settings must be attribute set")
      (lib.optional (!extraConfigValid) "Extra config must be attribute set")
    ];
  };

  # Validate test assertions
  validateTestAssertions = assertions: let
    validAssertions =
      lib.all (
        assertion:
          lib.hasAttr "success" assertion
          && lib.hasAttr "message" assertion
          && lib.isBool assertion.success
          && lib.isString assertion.message
      )
      assertions;
  in {
    valid = lib.isList assertions && validAssertions;
    errors = lib.flatten [
      (lib.optional (!lib.isList assertions) "Assertions must be a list")
      (lib.optional (!validAssertions) "Invalid assertion structure")
    ];
  };

  # Create validation report
  createValidationReport = validationResults: let
    allResults = lib.flatten (lib.attrValues validationResults);
    totalChecks = lib.length allResults;
    passedChecks = lib.length (lib.filter (r: r.valid) allResults);
    failedChecks = totalChecks - passedChecks;

    allErrors = lib.flatten (map (r: r.errors) allResults);
  in {
    summary = {
      total = totalChecks;
      passed = passedChecks;
      failed = failedChecks;
      success = failedChecks == 0;
    };

    errors = allErrors;

    details = validationResults;

    report = ''
      Validation Report
      ================

      Summary:
        Total checks: ${toString totalChecks}
        Passed: ${toString passedChecks}
        Failed: ${toString failedChecks}
        Success: ${
        if failedChecks == 0
        then "✅ Yes"
        else "❌ No"
      }

      ${lib.optionalString (failedChecks > 0) ''
        Errors:
        ${builtins.concatStringsSep "\n" (map (error: "  - ${error}") allErrors)}
      ''}
    '';
  };

  # Test coverage analysis
  analyzeCoverage = {
    tests,
    modules,
    profiles,
  }: let
    # Extract tested modules from test names
    testedModules = lib.unique (lib.flatten (map (
        test: let
          # Simple heuristic: extract module names from test names
          words = lib.splitString "-" test.name;
          moduleWords =
            lib.filter (
              word:
                lib.hasPrefix "darwin" word
                || lib.hasPrefix "home" word
                || lib.hasPrefix "shared" word
            )
            words;
        in
          moduleWords
      )
      tests));

    # Calculate coverage percentages
    moduleCount = lib.length modules;
    testedModuleCount = lib.length testedModules;
    moduleCoverage =
      if moduleCount > 0
      then (testedModuleCount * 100) / moduleCount
      else 0;

    profileCount = lib.length profiles;
    # Assume all profiles are tested for now
    profileCoverage = 100;
  in {
    modules = {
      total = moduleCount;
      tested = testedModuleCount;
      coverage = moduleCoverage;
      untested = lib.subtractLists testedModules modules;
    };

    profiles = {
      total = profileCount;
      tested = profileCount;
      coverage = profileCoverage;
      untested = [];
    };

    overall = {
      coverage = (moduleCoverage + profileCoverage) / 2;
      recommendation =
        if moduleCoverage < 80
        then "Increase module test coverage"
        else if profileCoverage < 80
        then "Increase profile test coverage"
        else "Good test coverage";
    };
  };
in {
  inherit
    validateTestResult
    validateTestSuite
    validateTestConfiguration
    validateModuleConfiguration
    validateTestAssertions
    createValidationReport
    analyzeCoverage
    ;
}
