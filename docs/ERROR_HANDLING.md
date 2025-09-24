# Error Handling and Validation System

This document describes the comprehensive error handling, validation, and diagnostics system implemented in the modular Nix configuration.

## Overview

The error handling system provides:

- **Configuration Validation**: Comprehensive validation of module configurations, dependencies, and platform compatibility
- **Error Diagnostics**: Detailed error analysis with context and repair suggestions
- **Health Monitoring**: System health scoring and monitoring
- **Debug Tools**: Advanced debugging and profiling utilities
- **Recovery Mechanisms**: Automatic error recovery and fallback strategies

## Components

### 1. Validation System (`lib/validation.nix`)

The validation system provides comprehensive configuration validation:

#### Module Validation
- **Structure Validation**: Ensures modules follow the standard interface pattern
- **Dependency Checking**: Validates module dependencies are met
- **Conflict Detection**: Identifies conflicting modules
- **Platform Compatibility**: Checks platform-specific module usage

#### Configuration Validation
- **Host Configuration**: Validates host-specific settings
- **Profile Configuration**: Validates profile definitions
- **Full System Validation**: Comprehensive system-wide validation

#### Usage Example
```nix
{
  modules.shared.validation = {
    enable = true;
    enforceValidation = true;  # Fail build on errors
    generateReport = true;
    reportPath = "/tmp/validation-report.txt";
  };
}
```

### 2. Error Handling System (`lib/error-handling.nix`)

Provides structured error handling and diagnostics:

#### Error Management
- **Structured Errors**: Standardized error format with severity levels
- **Error Categories**: Categorization by type (configuration, dependency, platform, etc.)
- **Error Formatting**: Human-readable error messages with context

#### Diagnostics
- **System Information**: Collects comprehensive system metadata
- **Health Checking**: Calculates system health scores (0-100)
- **Dependency Analysis**: Analyzes module dependencies and conflicts
- **Performance Monitoring**: Build performance analysis

#### Debug Utilities
- **Debug Logging**: Configurable debug levels and context-aware logging
- **Configuration Inspection**: Tools for inspecting configuration state
- **Performance Profiling**: Build time and resource usage analysis

### 3. Integration System (`lib/integration.nix`)

Provides integration utilities for seamless error handling:

#### Enhanced Builders
- **Validated Darwin Builder**: System builder with built-in validation
- **Configuration Wrappers**: Add validation to any configuration
- **Safe Module Loading**: Error-safe module importing

#### Development Tools
- **Development Shell**: Pre-configured shell with validation tools
- **CI/CD Checks**: Automated validation and health checks
- **Build Testing**: Automated build verification

### 4. Diagnostic Modules

#### Validation Module (`modules/shared/validation.nix`)
Integrates validation into the system configuration:

```nix
{
  modules.shared.validation = {
    enable = true;
    enforceValidation = true;
    generateReport = true;
    warningsAsErrors = false;
    skipModules = [ "modules.problematic.module" ];
  };
}
```

#### Diagnostics Module (`modules/shared/diagnostics.nix`)
Provides system diagnostics and monitoring:

```nix
{
  modules.shared.diagnostics = {
    enable = true;
    debugLevel = "info";
    enableHealthCheck = true;
    generateReports = true;
    enableRecovery = true;
    healthThreshold = 75;
  };
}
```

## Command Line Tools

### 1. Configuration Validator (`scripts/validate-config.sh`)

Validates configuration before building:

```bash
# Basic validation
./scripts/validate-config.sh

# Verbose validation with custom hostname
./scripts/validate-config.sh -v -H myhost

# Check only (no report generation)
./scripts/validate-config.sh --check-only
```

### 2. Diagnostic Tool (`scripts/diagnose-config.sh`)

Comprehensive diagnostics and error analysis:

```bash
# Quick health check
./scripts/diagnose-config.sh health

# Full validation with detailed errors
./scripts/diagnose-config.sh validate -v

# Analyze configuration and get suggestions
./scripts/diagnose-config.sh analyze

# Debug specific module
./scripts/diagnose-config.sh debug modules.home.development.git

# Profile build performance
./scripts/diagnose-config.sh profile

# Interactive fix mode (experimental)
./scripts/diagnose-config.sh fix -i
```

### 3. System Utilities

When diagnostics are enabled, additional utilities are available:

```bash
# System health check
nix-health-check

# Configuration debugging
nix-config-debug modules.home.shell.zsh

# Error analysis
nix-analyze-errors

# Build profiling (if performance monitoring enabled)
nix-profile-build
```

## Error Severity Levels

The system uses standardized severity levels:

- **CRITICAL (0)**: System cannot function, build will fail
- **ERROR (1)**: Feature will not work, may fail build depending on settings
- **WARNING (2)**: Potential issue, generates warnings
- **INFO (3)**: Informational messages
- **DEBUG (4)**: Debug information for troubleshooting

## Health Scoring

The system calculates a health score (0-100) based on:

- **Configuration Errors**: Each error reduces score by 10 points
- **Module Issues**: Each dependency/conflict issue reduces score by 5 points
- **Platform Compatibility**: Platform-specific issues affect score

Health Status Levels:
- **Excellent (90-100)**: Configuration is in great shape
- **Good (75-89)**: Minor issues that should be addressed
- **Fair (50-74)**: Several issues requiring attention
- **Poor (25-49)**: Significant problems affecting functionality
- **Critical (0-24)**: Major issues preventing proper operation

## Module Template

Use the validated module template for new modules:

```nix
# Copy modules/_template-validated.nix and customize:
# - Replace CATEGORY with module category (darwin, home, shared)
# - Replace MODULE_NAME with your module name
# - Replace MODULE_DESCRIPTION with description
# - Add dependencies, conflicts, and platform restrictions
# - Implement module-specific validation logic
```

## Best Practices

### 1. Module Development
- Always use the validated module template
- Define clear dependencies and conflicts
- Specify supported platforms
- Add custom validation for complex logic
- Include comprehensive documentation

### 2. Configuration Management
- Enable validation in all environments
- Use appropriate validation levels (error for production, warning for development)
- Regularly run health checks
- Monitor diagnostic reports
- Address validation issues promptly

### 3. Error Handling
- Use structured error messages with context
- Provide actionable suggestions for fixes
- Implement graceful fallbacks where possible
- Log errors with appropriate severity levels
- Test error conditions and recovery paths

### 4. Development Workflow
- Run validation before committing changes
- Use diagnostic tools during development
- Profile builds to identify performance issues
- Test configurations on target platforms
- Document any known issues or limitations

## Troubleshooting

### Common Issues

#### Validation Failures
1. **Missing Dependencies**: Enable required modules or remove dependent modules
2. **Module Conflicts**: Disable conflicting modules or resolve conflicts
3. **Platform Incompatibility**: Remove platform-specific modules or add platform conditions
4. **Configuration Errors**: Fix configuration syntax or missing required fields

#### Build Failures
1. **Check validation report**: Review `/tmp/nix-config-validation-report.txt`
2. **Run diagnostics**: Use `./scripts/diagnose-config.sh analyze`
3. **Debug specific modules**: Use `./scripts/diagnose-config.sh debug <module-path>`
4. **Check system health**: Use `./scripts/diagnose-config.sh health`

#### Performance Issues
1. **Profile builds**: Use `./scripts/diagnose-config.sh profile`
2. **Check module count**: High module counts may impact performance
3. **Review dependencies**: Complex dependency chains can slow builds
4. **Use binary caches**: Ensure binary caches are properly configured

### Debug Mode

Enable debug mode for detailed logging:

```nix
{
  modules.shared.diagnostics = {
    enable = true;
    debugLevel = "debug";  # or "trace" for maximum verbosity
  };
}
```

### Recovery Mode

Enable automatic recovery mechanisms:

```nix
{
  modules.shared.diagnostics = {
    enable = true;
    enableRecovery = true;
  };
}
```

## Integration with CI/CD

The system provides CI/CD integration through the development utilities:

```nix
# In flake.nix
{
  checks = lib.mkValidatedDarwin {
    # ... configuration
  }.devUtils.mkChecks system configs;
}
```

This creates automated checks for:
- Configuration validation
- Health monitoring  
- Build testing

## Future Enhancements

Planned improvements include:

1. **Automatic Repair**: Intelligent automatic fixing of common issues
2. **Performance Optimization**: Automated performance tuning suggestions
3. **Configuration Migration**: Tools for migrating between configuration versions
4. **Advanced Analytics**: Trend analysis and predictive issue detection
5. **Integration Testing**: Automated testing of module combinations
6. **Documentation Generation**: Automatic generation of configuration documentation

## Contributing

When contributing to the error handling system:

1. Follow the established error format and severity levels
2. Add comprehensive validation for new modules
3. Include diagnostic capabilities in new features
4. Test error conditions and recovery paths
5. Update documentation for new error types or diagnostic features
6. Ensure backward compatibility with existing configurations