{ config, lib, pkgs, inputs, outputs, stateVersion, ... }:
let
  cfg = config.modules.shared.validation;
  
  # Import our validation library
  validationLib = import ../../lib/validation.nix { inherit inputs outputs stateVersion; };
  
  # Get system from config or detect it
  system = config.nixpkgs.system or pkgs.system;
  
  # Perform validation
  validationResult = validationLib.configValidation.validateFullConfig config system;
  
  # Create validation report
  validationReport = {
    timestamp = builtins.currentTime;
    system = system;
    hostname = config.networking.hostName or "unknown";
    result = validationResult;
    
    # Generate human-readable report
    report = ''
      Configuration Validation Report
      =============================
      
      Timestamp: ${toString validationReport.timestamp}
      System: ${system}
      Hostname: ${validationReport.hostname}
      
      Summary:
      - Total Errors: ${toString validationResult.summary.totalErrors}
      - Host Errors: ${toString validationResult.summary.hostErrors}
      - Profile Errors: ${toString validationResult.summary.profileErrors}
      - Module Errors: ${toString validationResult.summary.moduleErrors}
      
      ${lib.optionalString (validationResult.summary.totalErrors > 0) ''
      Errors:
      ${lib.concatStringsSep "\n" (map (error: "- ${error}") validationResult.errors)}
      ''}
      
      ${lib.optionalString validationResult.valid "✅ Configuration is valid!"}
      ${lib.optionalString (!validationResult.valid) "❌ Configuration has validation errors"}
    '';
  };
  
in {
  options.modules.shared.validation = {
    enable = lib.mkEnableOption "configuration validation system";
    
    enforceValidation = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enforce validation (fail build on errors)";
    };
    
    generateReport = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to generate validation reports";
    };
    
    reportPath = lib.mkOption {
      type = lib.types.str;
      default = "/tmp/nix-config-validation-report.txt";
      description = "Path to write validation report";
    };
    
    warningsAsErrors = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Treat validation warnings as errors";
    };
    
    skipModules = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "List of module paths to skip during validation";
    };
    
    customRules = lib.mkOption {
      type = lib.types.attrs;
      default = {};
      description = "Custom validation rules to apply";
    };
  };
  
  config = lib.mkIf cfg.enable {
    # Add validation assertions if enforcement is enabled
    assertions = lib.mkIf cfg.enforceValidation 
      (validationLib.validationAssertions.mkValidationAssertions validationResult);
    
    # Generate validation report if enabled
    system.activationScripts.validationReport = lib.mkIf cfg.generateReport {
      text = ''
        echo "Writing validation report to ${cfg.reportPath}"
        cat > ${cfg.reportPath} << 'EOF'
        ${validationReport.report}
        EOF
        
        ${lib.optionalString (!validationResult.valid) ''
        echo "⚠️  Configuration validation found issues. Check ${cfg.reportPath} for details."
        ''}
        
        ${lib.optionalString validationResult.valid ''
        echo "✅ Configuration validation passed successfully."
        ''}
      '';
    };
    
    # Add validation metadata to system
    system.configurationRevision = lib.mkDefault (
      if validationResult.valid 
      then "valid-${toString validationReport.timestamp}"
      else "invalid-${toString validationReport.timestamp}"
    );
    
    # Export validation functions for use in other modules
    _module.args.validation = validationLib;
    _module.args.validationResult = validationResult;
    
    # Add validation utilities to environment for debugging
    environment.systemPackages = lib.mkIf cfg.generateReport [
      (pkgs.writeShellScriptBin "nix-config-validate" ''
        echo "Running configuration validation..."
        
        # Re-run validation
        nix eval --impure --expr '
          let
            config = (import ${../../flake.nix}).darwinConfigurations.${config.networking.hostName}.config;
            validation = import ${../../lib/validation.nix} { 
              inputs = (import ${../../flake.nix}).inputs;
              outputs = (import ${../../flake.nix}).outputs;
              stateVersion = "${stateVersion}";
            };
            result = validation.configValidation.validateFullConfig config "${system}";
          in
            if result.valid 
            then "✅ Configuration is valid"
            else "❌ Configuration has " + toString result.summary.totalErrors + " errors:\n" + 
                 builtins.concatStringsSep "\n" result.errors
        '
        
        echo ""
        echo "Validation report location: ${cfg.reportPath}"
        if [ -f "${cfg.reportPath}" ]; then
          echo "Last validation report:"
          cat "${cfg.reportPath}"
        fi
      '')
      
      (pkgs.writeShellScriptBin "nix-config-debug" ''
        echo "Configuration Debug Information"
        echo "=============================="
        echo "System: ${system}"
        echo "Hostname: ${config.networking.hostName or "unknown"}"
        echo "Validation enabled: ${lib.boolToString cfg.enable}"
        echo "Enforcement enabled: ${lib.boolToString cfg.enforceValidation}"
        echo ""
        
        echo "Enabled modules:"
        nix eval --impure --expr '
          let
            config = (import ${../../flake.nix}).darwinConfigurations.${config.networking.hostName}.config;
            enabledModules = builtins.filter (path: 
              let 
                parts = builtins.split "\\." path;
                moduleConfig = builtins.foldl (acc: part: acc.${part}) config parts;
              in moduleConfig.enable or false
            ) (builtins.attrNames (config.modules or {}));
          in builtins.concatStringsSep "\n" enabledModules
        '
      '')
    ];
  };
  
  # Always export validation metadata for introspection
  meta.validation = {
    enabled = cfg.enable;
    result = lib.mkIf cfg.enable validationResult;
    report = lib.mkIf cfg.enable validationReport;
  };
}