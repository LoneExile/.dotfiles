{
  config,
  lib,
  pkgs,
  inputs,
  outputs,
  stateVersion,
  ...
}: let
  cfg = config.modules.shared.diagnostics;

  # Import error handling and diagnostics
  errorLib = import ../../lib/error-handling.nix {inherit inputs outputs stateVersion;};

  # Get system information
  system = config.nixpkgs.system or pkgs.system;

  # Generate diagnostic report
  diagnosticReport = errorLib.diagnostics.createDiagnosticReport config system;

  # Health check results
  healthCheck = errorLib.diagnostics.healthCheck config system;
in {
  options.modules.shared.diagnostics = {
    enable = lib.mkEnableOption "system diagnostics and error handling";

    debugLevel = lib.mkOption {
      type = lib.types.enum ["none" "error" "warn" "info" "debug" "trace"];
      default = "info";
      description = "Debug logging level";
    };

    enableHealthCheck = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable system health monitoring";
    };

    generateReports = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Generate diagnostic reports";
    };

    reportPath = lib.mkOption {
      type = lib.types.str;
      default = "/tmp/nix-config-diagnostics.txt";
      description = "Path for diagnostic reports";
    };

    enableRecovery = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable automatic error recovery mechanisms";
    };

    healthThreshold = lib.mkOption {
      type = lib.types.int;
      default = 50;
      description = "Minimum health score before warnings (0-100)";
    };

    enablePerformanceMonitoring = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable performance monitoring and logging";
    };
  };

  config = lib.mkIf cfg.enable {
    # Set debug level globally
    _module.args.debugLevel =
      if cfg.debugLevel == "none"
      then errorLib.debug.levels.NONE
      else if cfg.debugLevel == "error"
      then errorLib.debug.levels.ERROR
      else if cfg.debugLevel == "warn"
      then errorLib.debug.levels.WARN
      else if cfg.debugLevel == "info"
      then errorLib.debug.levels.INFO
      else if cfg.debugLevel == "debug"
      then errorLib.debug.levels.DEBUG
      else errorLib.debug.levels.TRACE;

    # Health check warnings
    warnings = lib.mkIf cfg.enableHealthCheck (
      lib.optional (healthCheck.score < cfg.healthThreshold)
      "System health score is ${toString healthCheck.score}/100 (${healthCheck.status}). Consider reviewing configuration."
    );

    # Generate diagnostic report on activation
    system.activationScripts.diagnostics = lib.mkIf cfg.generateReports {
      text = ''
        echo "Generating system diagnostics report..."

        cat > ${cfg.reportPath} << 'EOF'
        ${diagnosticReport}
        EOF

        echo "Diagnostic report written to: ${cfg.reportPath}"

        # Health status notification
        ${lib.optionalString (healthCheck.score < cfg.healthThreshold) ''
          echo "⚠️  System health score: ${toString healthCheck.score}/100 (${healthCheck.status})"
          echo "   Check ${cfg.reportPath} for details and recommendations"
        ''}

        ${lib.optionalString (healthCheck.score >= cfg.healthThreshold) ''
          echo "✅ System health: ${toString healthCheck.score}/100 (${healthCheck.status})"
        ''}
      '';
    };

    # Add diagnostic utilities to system packages
    environment.systemPackages = [
      # System health checker
      (pkgs.writeShellScriptBin "nix-health-check" ''
        echo "System Health Check"
        echo "=================="
        echo ""

        # Run health check
        nix eval --impure --expr '
          let
            flake = builtins.getFlake "${toString ../../.}";
            config = flake.darwinConfigurations.${config.networking.hostName}.config;
            errorLib = import ${toString ../../lib/error-handling.nix} {
              inputs = flake.inputs;
              outputs = flake.outputs;
              stateVersion = "${stateVersion}";
            };
            healthCheck = errorLib.diagnostics.healthCheck config "${system}";
          in
            "Health Score: " + toString healthCheck.score + "/100 (" + healthCheck.status + ")\n" +
            "Modules: " + toString healthCheck.dependencies.totalModules + " total, " +
            toString healthCheck.dependencies.issueCount + " with issues\n" +
            "Validation: " + toString healthCheck.validation.summary.totalErrors + " errors"
        '

        echo ""
        echo "Full report available at: ${cfg.reportPath}"
      '')

      # Configuration debugger
      (pkgs.writeShellScriptBin "nix-config-debug" ''
        MODULE_PATH="''${1:-}"

        if [ -z "$MODULE_PATH" ]; then
          echo "Usage: nix-config-debug <module-path>"
          echo "Example: nix-config-debug modules.home.development.git"
          exit 1
        fi

        echo "Debugging module: $MODULE_PATH"
        echo "==============================="

        nix eval --impure --expr "
          let
            flake = builtins.getFlake \"${toString ../../.}\";
            config = flake.darwinConfigurations.${config.networking.hostName}.config;
            errorLib = import ${toString ../../lib/error-handling.nix} {
              inputs = flake.inputs;
              outputs = flake.outputs;
              stateVersion = \"${stateVersion}\";
            };

            pathParts = builtins.split \"\\.\" \"$MODULE_PATH\";
            moduleConfig = builtins.foldl' (acc: p: acc.\${p}) config pathParts;

          in
            \"Enabled: \" + toString (moduleConfig.enable or false) + \"\n\" +
            \"Has package: \" + toString (builtins.hasAttr \"package\" moduleConfig) + \"\n\" +
            \"Has settings: \" + toString (builtins.hasAttr \"settings\" moduleConfig) + \"\n\" +
            \"Settings keys: \" + builtins.concatStringsSep \", \" (
              if builtins.hasAttr \"settings\" moduleConfig
              then builtins.attrNames moduleConfig.settings
              else []
            )
        "
      '')

      # Error analyzer
      (pkgs.writeShellScriptBin "nix-analyze-errors" ''
        echo "Configuration Error Analysis"
        echo "==========================="

        # Run validation and show detailed error analysis
        nix eval --impure --json --expr '
          let
            flake = builtins.getFlake "${toString ../../.}";
            config = flake.darwinConfigurations.${config.networking.hostName}.config;
            validationLib = import ${toString ../../lib/validation.nix} {
              inputs = flake.inputs;
              outputs = flake.outputs;
              stateVersion = "${stateVersion}";
            };
            errorLib = import ${toString ../../lib/error-handling.nix} {
              inputs = flake.inputs;
              outputs = flake.outputs;
              stateVersion = "${stateVersion}";
            };

            result = validationLib.configValidation.validateFullConfig config "${system}";
            repairs = errorLib.recovery.suggestRepairs result.errors;

          in {
            summary = result.summary;
            errors = result.errors;
            repairs = repairs;
          }
        ' | ${pkgs.jq}/bin/jq -r '
          "Summary:",
          "- Total Errors: " + (.summary.totalErrors | tostring),
          "- Host Errors: " + (.summary.hostErrors | tostring),
          "- Profile Errors: " + (.summary.profileErrors | tostring),
          "- Module Errors: " + (.summary.moduleErrors | tostring),
          "",
          "Errors and Suggested Repairs:",
          (.repairs[] | "❌ " + .error + "\n💡 " + .suggestion + "\n")
        '
      '')

      # Performance profiler
      (lib.mkIf cfg.enablePerformanceMonitoring
        (pkgs.writeShellScriptBin "nix-profile-build" ''
          echo "Profiling Nix configuration build..."

          START_TIME=$(date +%s)

          # Build configuration with timing
          nix build --no-link --print-build-logs \
            "${toString ../../.}#darwinConfigurations.${config.networking.hostName}.system" \
            2>&1 | tee /tmp/nix-build-profile.log

          END_TIME=$(date +%s)
          DURATION=$((END_TIME - START_TIME))

          echo ""
          echo "Build completed in $DURATION seconds"
          echo "Build log saved to: /tmp/nix-build-profile.log"

          # Analyze build log for performance insights
          echo ""
          echo "Performance Analysis:"
          echo "===================="

          # Count derivations built
          DERIVATIONS=$(grep -c "building '/nix/store" /tmp/nix-build-profile.log || echo "0")
          echo "Derivations built: $DERIVATIONS"

          # Find slowest builds
          echo ""
          echo "Build timing analysis saved to /tmp/nix-build-profile.log"
        ''))
    ];

    # Export diagnostic functions for other modules
    _module.args.diagnostics = errorLib.diagnostics;
    _module.args.errorHandling = errorLib.errorHandling;
    _module.args.debug = errorLib.debug;
    _module.args.recovery = errorLib.recovery;

    # Add system metadata
    system.nixos.tags = lib.mkIf cfg.enableHealthCheck [
      "health-${healthCheck.status}"
      "score-${toString healthCheck.score}"
    ];
  };

  # Export diagnostic metadata
  meta.diagnostics = lib.mkIf cfg.enable {
    healthCheck = healthCheck;
    reportPath = cfg.reportPath;
    debugLevel = cfg.debugLevel;
  };
}
