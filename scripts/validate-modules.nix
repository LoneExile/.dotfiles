# Simple Module Validation Script
# Checks basic module structure compliance
let
  # Basic validation functions
  isFunction = x: builtins.isFunction x;
  hasAttr = attr: set: builtins.hasAttr attr set;

  # Get all .nix files in modules directory (excluding template and default.nix)
  getModuleFiles = dir: let
    entries = builtins.readDir dir;
    nixFiles = builtins.filter (
      name:
        builtins.match ".*\\.nix$" name
        != null
        && name != "default.nix"
        && name != "_template.nix"
    ) (builtins.attrNames entries);

    # Get files from subdirectories
    subDirs = builtins.filter (name: entries.${name} == "directory") (builtins.attrNames entries);
    subDirFiles =
      builtins.concatMap (
        subDir: let
          subFiles = getModuleFiles (dir + "/${subDir}");
        in
          builtins.map (file: "${subDir}/${file}") subFiles
      )
      subDirs;
  in
    nixFiles ++ subDirFiles;

  # Validate a single module
  validateModule = modulePath: let
    fullPath = ../modules + "/${modulePath}";

    # Check if file exists and can be imported
    moduleExists = builtins.pathExists fullPath;

    validation =
      if moduleExists
      then let
        moduleContent = import fullPath;

        # Basic structure checks
        isFunc = isFunction moduleContent;

        # Try to evaluate with minimal inputs
        dummyConfig = {
          config = {};
          lib = {
            mkEnableOption = desc: {_type = "option";};
            mkOption = opts: {_type = "option";} // opts;
            mkIf = cond: config: config;
            types = {
              bool = "bool";
              str = "string";
              attrs = "attrs";
              package = "package";
              listOf = type: "listOf-${type}";
            };
          };
          pkgs = {};
        };

        evaluated =
          if isFunc
          then try (moduleContent dummyConfig) null
          else null;

        hasOptions = evaluated != null && hasAttr "options" evaluated;
        hasConfig = evaluated != null && hasAttr "config" evaluated;
      in {
        exists = true;
        isFunction = isFunc;
        canEvaluate = evaluated != null;
        hasOptions = hasOptions;
        hasConfig = hasConfig;
        valid = isFunc && evaluated != null && hasOptions && hasConfig;
      }
      else {
        exists = false;
        isFunction = false;
        canEvaluate = false;
        hasOptions = false;
        hasConfig = false;
        valid = false;
      };

    errors = builtins.filter (x: x != null) [
      (
        if !validation.exists
        then "File does not exist"
        else null
      )
      (
        if validation.exists && !validation.isFunction
        then "Module is not a function"
        else null
      )
      (
        if validation.exists && validation.isFunction && !validation.canEvaluate
        then "Module cannot be evaluated"
        else null
      )
      (
        if validation.canEvaluate && !validation.hasOptions
        then "Module missing 'options'"
        else null
      )
      (
        if validation.canEvaluate && !validation.hasConfig
        then "Module missing 'config'"
        else null
      )
    ];
  in {
    path = modulePath;
    inherit validation errors;
    valid = validation.valid;
  };

  # Get all module files
  moduleFiles = getModuleFiles ../modules;

  # Validate all modules
  results = builtins.map validateModule moduleFiles;

  # Summary
  validModules = builtins.filter (r: r.valid) results;
  invalidModules = builtins.filter (r: !r.valid) results;

  totalCount = builtins.length results;
  validCount = builtins.length validModules;
  invalidCount = builtins.length invalidModules;

  allValid = invalidCount == 0;

  # Simple try-catch implementation
  try = expr: catch: let
    result = builtins.tryEval expr;
  in
    if result.success
    then result.value
    else catch;
in {
  # Results
  inherit results validModules invalidModules;

  # Summary
  summary = {
    total = totalCount;
    valid = validCount;
    invalid = invalidCount;
    success = allValid;
    message =
      if allValid
      then "All ${builtins.toString totalCount} modules are valid"
      else "${builtins.toString invalidCount} of ${builtins.toString totalCount} modules have errors";
  };

  # Simple check for scripts
  check = allValid;

  # Report generation
  report = let
    validList = builtins.concatStringsSep "\n" (builtins.map (m: "✅ ${m.path}") validModules);
    invalidList = builtins.concatStringsSep "\n" (builtins.map (
        m: "❌ ${m.path}: ${builtins.concatStringsSep ", " m.errors}"
      )
      invalidModules);
  in ''
    # Module Validation Report

    **Status:** ${
      if allValid
      then "✅ PASS"
      else "❌ FAIL"
    }
    **Summary:** ${
      if allValid
      then "All ${builtins.toString totalCount} modules are valid"
      else "${builtins.toString invalidCount} of ${builtins.toString totalCount} modules have errors"
    }

    ## Valid Modules (${builtins.toString validCount})
    ${validList}

    ${
      if invalidCount > 0
      then ''
        ## Invalid Modules (${builtins.toString invalidCount})
        ${invalidList}
      ''
      else ""
    }

    ## Validation Criteria
    - Module must be a function
    - Module must return options and config attributes
    - Module must be evaluable with standard inputs
  '';
}
