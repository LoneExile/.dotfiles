{
  inputs,
  outputs,
  stateVersion,
  ...
}: let
  inherit (inputs.nixpkgs) lib;

  # Error severity levels
  severity = {
    CRITICAL = 0; # System cannot function
    ERROR = 1; # Feature will not work
    WARNING = 2; # Potential issue
    INFO = 3; # Informational
    DEBUG = 4; # Debug information
  };

  # Error categories
  categories = {
    CONFIGURATION = "configuration";
    DEPENDENCY = "dependency";
    PLATFORM = "platform";
    VALIDATION = "validation";
    BUILD = "build";
    RUNTIME = "runtime";
  };
in {
  # Error handling and diagnostics system
  errorHandling = let
    # Create structured error
    mkError = {
      message,
      category ? categories.CONFIGURATION,
      severity ? severity.ERROR,
      context ? {},
      suggestions ? [],
      documentation ? null,
    }: {
      inherit message category severity context suggestions documentation;
      timestamp = builtins.currentTime;
      id = builtins.hashString "sha256" "${message}-${toString builtins.currentTime}";
    };

    # Create warning
    mkWarning = message: context: suggestions: {
      inherit message context suggestions;
      category = categories.CONFIGURATION;
      severity = severity.WARNING;
      documentation = null;
      timestamp = builtins.currentTime;
      id = builtins.hashString "sha256" "${message}-${toString builtins.currentTime}";
    };

    # Create critical error
    mkCritical = message: context: suggestions: {
      inherit message context suggestions;
      category = categories.CONFIGURATION;
      severity = severity.CRITICAL;
      documentation = null;
      timestamp = builtins.currentTime;
      id = builtins.hashString "sha256" "${message}-${toString builtins.currentTime}";
    };

    # Format error for display
    formatError = error: let
      severityName =
        if error.severity == severity.CRITICAL
        then "CRITICAL"
        else if error.severity == severity.ERROR
        then "ERROR"
        else if error.severity == severity.WARNING
        then "WARNING"
        else if error.severity == severity.INFO
        then "INFO"
        else "DEBUG";

      contextStr =
        if error.context != {}
        then "\n  Context: ${builtins.toJSON error.context}"
        else "";

      suggestionsStr =
        if error.suggestions != []
        then "\n  Suggestions:\n${lib.concatStringsSep "\n" (map (s: "    - ${s}") error.suggestions)}"
        else "";

      docStr =
        if error.documentation != null
        then "\n  Documentation: ${error.documentation}"
        else "";
    in "[${severityName}:${error.category}] ${error.message}${contextStr}${suggestionsStr}${docStr}";

    # Group errors by category
    groupByCategory = errors:
      lib.groupBy (error: error.category) errors;

    # Format multiple errors
    formatErrors = errors: let
      sortedErrors = lib.sort (a: b: a.severity < b.severity) errors;
      formattedErrors = map formatError sortedErrors;
    in
      lib.concatStringsSep "\n\n" formattedErrors;

    # Filter errors by severity
    filterBySeverity = minSeverity: errors:
      lib.filter (error: error.severity <= minSeverity) errors;

    # Create error summary
    createSummary = errors: let
      byCategory = groupByCategory errors;
      bySeverity =
        lib.groupBy (
          error:
            if error.severity == severity.CRITICAL
            then "critical"
            else if error.severity == severity.ERROR
            then "error"
            else if error.severity == severity.WARNING
            then "warning"
            else "info"
        )
        errors;
    in {
      total = lib.length errors;
      critical = lib.length (bySeverity.critical or []);
      errors = lib.length (bySeverity.error or []);
      warnings = lib.length (bySeverity.warning or []);
      info = lib.length (bySeverity.info or []);
      byCategory = lib.mapAttrs (name: errs: lib.length errs) byCategory;
    };
  in {
    inherit severity categories;
    inherit mkError mkWarning mkCritical formatError formatErrors filterBySeverity groupByCategory createSummary;
  };

  # Diagnostic system
  diagnostics = let
    # Get enabled modules
    getEnabledModules = config: let
      collectEnabled = path: value:
        if lib.isAttrs value && lib.hasAttr "enable" value && value.enable
        then [path]
        else if lib.isAttrs value
        then
          lib.flatten (lib.mapAttrsToList (
              name: subValue:
                collectEnabled "${path}.${name}" subValue
            )
            value)
        else [];
    in
      lib.flatten (lib.mapAttrsToList (
        name: value:
          collectEnabled "modules.${name}" value
      ) (config.modules or {}));

    # Get enabled profiles
    getEnabledProfiles = config:
      lib.mapAttrsToList (name: profile: name)
      (lib.filterAttrs (name: profile: profile.enable or false)
        (config.profiles or {}));

    # System information collection
    collectSystemInfo = config: system: {
      system = system;
      hostname = config.hostname or "unknown";
      nixpkgsVersion = inputs.nixpkgs.rev or "unknown";
      flakeInputs = builtins.attrNames inputs;
      enabledModules = getEnabledModules config;
      profiles = getEnabledProfiles config;
      timestamp = builtins.currentTime;
    };

    # Module dependency analysis
    analyzeDependencies = config: let
      enabledModules = getEnabledModules config;

      # Import validation rules
      validationLib = import ./validation.nix {inherit inputs outputs stateVersion;};
      dependencyRules = validationLib.moduleValidation.validationRules.dependencies;

      # Analyze each enabled module
      analyzeModule = modulePath: let
        rules =
          dependencyRules.${modulePath}
          or {
            requires = [];
            conflicts = [];
          };

        missingDeps =
          lib.filter (
            dep:
              !(lib.elem dep enabledModules)
          )
          rules.requires;

        activeConflicts =
          lib.filter (
            conflict:
              lib.elem conflict enabledModules
          )
          rules.conflicts;
      in {
        module = modulePath;
        missingDependencies = missingDeps;
        activeConflicts = activeConflicts;
        hasIssues = missingDeps != [] || activeConflicts != [];
      };

      results = map analyzeModule enabledModules;
    in {
      modules = results;
      issueCount = lib.length (lib.filter (r: r.hasIssues) results);
      totalModules = lib.length enabledModules;
    };

    # Generate recommendations based on issues
    generateRecommendations = validationResult: depAnalysis: let
      recommendations = [];

      # Validation-based recommendations
      validationRecs =
        if validationResult.summary.totalErrors > 0
        then ["Fix configuration validation errors before proceeding"]
        else [];

      # Dependency-based recommendations
      depRecs =
        if depAnalysis.issueCount > 0
        then ["Review module dependencies and resolve conflicts"]
        else [];

      # Performance recommendations
      perfRecs =
        if depAnalysis.totalModules > 20
        then ["Consider using profiles to organize large numbers of modules"]
        else [];
    in
      validationRecs ++ depRecs ++ perfRecs;

    # Configuration health check
    healthCheck = config: system: let
      systemInfo = collectSystemInfo config system;
      depAnalysis = analyzeDependencies config;

      # Import validation for full check
      validationLib = import ./validation.nix {inherit inputs outputs stateVersion;};
      validationResult = validationLib.configValidation.validateFullConfig config system;

      # Calculate health score (0-100)
      healthScore = let
        maxScore = 100;
        errorPenalty = validationResult.summary.totalErrors * 10;
        warningPenalty = (depAnalysis.issueCount or 0) * 5;
        totalPenalty = errorPenalty + warningPenalty;
      in
        lib.max 0 (maxScore - totalPenalty);

      # Determine health status
      healthStatus =
        if healthScore >= 90
        then "excellent"
        else if healthScore >= 75
        then "good"
        else if healthScore >= 50
        then "fair"
        else if healthScore >= 25
        then "poor"
        else "critical";
    in {
      score = healthScore;
      status = healthStatus;
      systemInfo = systemInfo;
      validation = validationResult;
      dependencies = depAnalysis;
      recommendations = generateRecommendations validationResult depAnalysis;
    };

    # Create diagnostic report
    createDiagnosticReport = config: system: let
      healthCheckResult = healthCheck config system;

      formatModuleIssues = modules:
        lib.concatStringsSep "\n" (map (
            m:
              if m.hasIssues
              then
                "  - ${m.module}:\n"
                + (
                  if m.missingDependencies != []
                  then "    Missing deps: ${lib.concatStringsSep ", " m.missingDependencies}\n"
                  else ""
                )
                + (
                  if m.activeConflicts != []
                  then "    Conflicts: ${lib.concatStringsSep ", " m.activeConflicts}\n"
                  else ""
                )
              else ""
          )
          modules);
    in ''
      Configuration Diagnostic Report
      =============================

      System Information:
      - Hostname: ${healthCheckResult.systemInfo.hostname}
      - System: ${healthCheckResult.systemInfo.system}
      - Nixpkgs: ${healthCheckResult.systemInfo.nixpkgsVersion}
      - Timestamp: ${toString healthCheckResult.systemInfo.timestamp}

      Health Status: ${healthCheckResult.status} (${toString healthCheckResult.score}/100)

      Module Summary:
      - Total Modules: ${toString healthCheckResult.dependencies.totalModules}
      - Modules with Issues: ${toString healthCheckResult.dependencies.issueCount}
      - Enabled Profiles: ${lib.concatStringsSep ", " healthCheckResult.systemInfo.profiles}

      Validation Summary:
      - Total Errors: ${toString healthCheckResult.validation.summary.totalErrors}
      - Host Errors: ${toString healthCheckResult.validation.summary.hostErrors}
      - Profile Errors: ${toString healthCheckResult.validation.summary.profileErrors}
      - Module Errors: ${toString healthCheckResult.validation.summary.moduleErrors}

      ${lib.optionalString (healthCheckResult.dependencies.issueCount > 0) ''
        Module Issues:
        ${formatModuleIssues healthCheckResult.dependencies.modules}
      ''}

      ${lib.optionalString (healthCheckResult.validation.summary.totalErrors > 0) ''
        Validation Errors:
        ${lib.concatStringsSep "\n" (map (e: "- ${e}") healthCheckResult.validation.errors)}
      ''}

      Recommendations:
      ${lib.concatStringsSep "\n" (map (r: "- ${r}") healthCheckResult.recommendations)}
    '';
  in {
    inherit collectSystemInfo getEnabledModules getEnabledProfiles analyzeDependencies generateRecommendations healthCheck createDiagnosticReport;
  };

  # Debug utilities
  debug = let
    # Debug levels
    levels = {
      NONE = 0;
      ERROR = 1;
      WARN = 2;
      INFO = 3;
      DEBUG = 4;
      TRACE = 5;
    };

    # Current debug level (can be overridden)
    currentLevel = levels.INFO;

    # Debug logging function
    log = level: context: message: value:
      if level <= currentLevel
      then builtins.trace "[${context}:${toString level}] ${message}" value
      else value;

    # Convenience logging functions
    error = log levels.ERROR;
    warn = log levels.WARN;
    info = log levels.INFO;
    debugLog = log levels.DEBUG;
    trace = log levels.TRACE;

    # Debug configuration inspection
    inspectConfig = config: path: let
      pathParts = lib.splitString "." path;
      value = lib.getAttrFromPath pathParts config;
    in
      info "config-inspect" "Inspecting ${path}" {
        path = path;
        type = builtins.typeOf value;
        value = value;
      };

    # Module debugging
    debugModule = modulePath: moduleConfig:
      info "module-debug" "Module ${modulePath}" {
        enabled = moduleConfig.enable or false;
        hasPackage = lib.hasAttr "package" moduleConfig;
        hasSettings = lib.hasAttr "settings" moduleConfig;
        settingsKeys =
          if lib.hasAttr "settings" moduleConfig
          then builtins.attrNames moduleConfig.settings
          else [];
      };

    # Performance debugging
    timeOperation = name: operation: let
      startTime = builtins.currentTime;
      result = operation;
      endTime = builtins.currentTime;
      duration = endTime - startTime;
    in
      info "performance" "Operation ${name} took ${toString duration}s" result;

    # Memory usage estimation
    estimateSize = value: let
      sizeOf = v:
        if builtins.isString v
        then builtins.stringLength v
        else if builtins.isList v
        then builtins.length v
        else if builtins.isAttrs v
        then builtins.length (builtins.attrNames v)
        else 1;
    in
      info "memory" "Estimated size" (sizeOf value);
  in {
    inherit levels currentLevel log error warn info debugLog trace;
    inherit inspectConfig debugModule timeOperation estimateSize;
  };

  # Recovery and fallback mechanisms
  recovery = {
    # Safe attribute access with fallback
    safeGetAttr = path: default: config: let
      pathParts = lib.splitString "." path;
    in
      if lib.hasAttrByPath pathParts config
      then lib.getAttrFromPath pathParts config
      else default;

    # Safe module enabling with dependency checking
    safeEnableModule = modulePath: config: let
      validationLib = import ./validation.nix {inherit inputs outputs stateVersion;};
      rules = validationLib.moduleValidation.validationRules.dependencies.${modulePath} or {requires = [];};

      # Check if all dependencies are available
      depsAvailable =
        lib.all (
          dep:
            lib.hasAttrByPath (lib.splitString "." dep) config
            && (lib.getAttrFromPath (lib.splitString "." dep) config).enable or false
        )
        rules.requires;
    in
      if depsAvailable
      then lib.setAttrByPath (lib.splitString "." modulePath) {enable = true;}
      else {};

    # Graceful degradation for missing packages
    fallbackPackage = preferredPkg: fallbackPkg: pkgs:
      if lib.hasAttr preferredPkg pkgs
      then pkgs.${preferredPkg}
      else if lib.hasAttr fallbackPkg pkgs
      then pkgs.${fallbackPkg}
      else throw "Neither ${preferredPkg} nor ${fallbackPkg} available";

    # Configuration repair suggestions
    suggestRepairs = errors: let
      repairSuggestions = {
        "Missing required field" = "Add the missing field to your configuration";
        "conflicts with" = "Disable one of the conflicting modules";
        "requires" = "Enable the required dependency module";
        "not supported on platform" = "Remove platform-incompatible modules";
      };

      findSuggestion = error: let
        matchingKeys = lib.filter (key: lib.hasInfix key error) (builtins.attrNames repairSuggestions);
      in
        if matchingKeys != []
        then repairSuggestions.${lib.head matchingKeys}
        else "Review the error message and configuration documentation";
    in
      map (error: {
        error = error;
        suggestion = findSuggestion error;
      })
      errors;
  };
}
