# Module Development Guide

This guide explains how to create and maintain modules in the modular Nix configuration system.

## Module Structure

All modules follow a consistent structure to ensure maintainability and ease of use. Each module should:

1. Have a clear enable/disable option
2. Provide sensible defaults
3. Include comprehensive documentation
4. Follow the standard option naming conventions
5. Implement proper validation

## Creating a New Module

### 1. Choose the Right Category

Modules are organized into categories:

- `modules/darwin/` - macOS-specific system configuration
- `modules/home/` - Home Manager configuration (cross-platform user environment)
- `modules/shared/` - Shared configuration that works across platforms

### 2. Use the Template

Copy the module template and modify it for your needs:

```bash
cp modules/_template.nix modules/category/your-module.nix
```

### 3. Module Naming Conventions

- Use kebab-case for file names: `my-module.nix`
- Use camelCase for option names: `enableFeature`
- Use descriptive names that clearly indicate the module's purpose

### 4. Standard Options

Every module should include these standard options:

#### Required Options

```nix
enable = lib.mkEnableOption "clear description of what this module provides";
```

#### Common Optional Options

```nix
# For modules that install packages
package = lib.mkOption {
  type = lib.types.package;
  default = pkgs.packageName;
  description = "Package to use for this module";
};

# For module-specific settings
settings = lib.mkOption {
  type = lib.types.attrs;
  default = {};
  description = "Configuration settings for this module";
  example = lib.literalExpression ''
    {
      key = "value";
      enabled = true;
    }
  '';
};

# For advanced configuration
extraConfig = lib.mkOption {
  type = lib.types.attrs;
  default = {};
  description = "Additional configuration options";
};
```

## Option Types and Validation

Use appropriate Nix types for validation:

```nix
# Basic types
type = lib.types.bool;           # true/false
type = lib.types.str;            # string
type = lib.types.int;            # integer
type = lib.types.package;        # Nix package

# Collection types
type = lib.types.listOf lib.types.str;        # list of strings
type = lib.types.attrsOf lib.types.bool;      # attribute set with boolean values
type = lib.types.attrs;                       # any attribute set

# Advanced types
type = lib.types.enum [ "option1" "option2" ]; # enumeration
type = lib.types.nullOr lib.types.str;        # string or null
type = lib.types.either lib.types.str lib.types.path; # string or path
```

## Documentation Standards

### Option Documentation

Each option must have:

1. **Description**: Clear, concise explanation of what the option does
2. **Default**: Sensible default value
3. **Example**: When helpful, provide usage examples
4. **Type**: Proper Nix type for validation

```nix
myOption = lib.mkOption {
  type = lib.types.str;
  default = "default-value";
  description = ''
    Clear description of what this option controls.
    Can be multi-line for complex options.
  '';
  example = "example-value";
};
```

### Module Documentation

Add a comment block at the top of each module:

```nix
# Module Name
# 
# Brief description of what this module provides and its main use cases.
# 
# Key features:
# - Feature 1
# - Feature 2
# 
# Dependencies: list any required modules or system components
# Conflicts: list any conflicting modules or settings
```

## Implementation Guidelines

### 1. Conditional Configuration

Always wrap your implementation in `lib.mkIf cfg.enable`:

```nix
config = lib.mkIf cfg.enable {
  # Your module implementation here
};
```

### 2. Package Installation

For Home Manager modules:
```nix
home.packages = [ cfg.package ] ++ cfg.extraPackages;
```

For Darwin modules:
```nix
environment.systemPackages = [ cfg.package ];
```

### 3. Configuration Files

Use Home Manager's file management:
```nix
home.file.".config/app/config.conf" = {
  text = lib.generators.toINI {} cfg.settings;
};

# Or for executable files
home.file.".local/bin/script" = {
  source = ./script.sh;
  executable = true;
};
```

### 4. Service Configuration

For systemd services:
```nix
systemd.user.services.myservice = {
  description = "My Service";
  wantedBy = [ "default.target" ];
  serviceConfig = {
    ExecStart = "${cfg.package}/bin/myservice";
    Restart = "always";
  };
} // cfg.extraConfig;
```

### 5. Program Configuration

For programs with Home Manager support:
```nix
programs.myprogram = {
  enable = true;
  package = cfg.package;
  settings = cfg.settings;
} // cfg.extraConfig;
```

## Testing Your Module

### 1. Syntax Check

Test that your module syntax is correct:
```bash
nix flake check
```

### 2. Build Test

Test building with your module enabled:
```bash
nix build .#darwinConfigurations.hostname.system
```

### 3. Module Validation

Ensure your module options are properly defined:
```bash
nix eval .#darwinConfigurations.hostname.options.modules.category.modulename --json
```

## Integration Guidelines

### 1. Adding to Module Lists

Add your module to the appropriate default.nix:

```nix
# modules/category/default.nix
{
  imports = [
    ./existing-module.nix
    ./your-new-module.nix  # Add this line
  ];
}
```

### 2. Profile Integration

Consider which profiles should enable your module by default:

```nix
# profiles/development.nix
{
  modules.category.your-module.enable = true;
}
```

### 3. Host Configuration

Document how users can enable your module:

```nix
# hosts/hostname/default.nix
{
  modules.category.your-module = {
    enable = true;
    settings = {
      # Custom settings
    };
  };
}
```

## Best Practices

### 1. Fail Fast

Use assertions to catch configuration errors early:

```nix
config = lib.mkIf cfg.enable {
  assertions = [
    {
      assertion = cfg.package != null;
      message = "Module package cannot be null";
    }
  ];
};
```

### 2. Provide Examples

Include practical examples in your option descriptions:

```nix
settings = lib.mkOption {
  type = lib.types.attrs;
  default = {};
  description = "Configuration settings";
  example = lib.literalExpression ''
    {
      theme = "dark";
      fontSize = 12;
      plugins = [ "plugin1" "plugin2" ];
    }
  '';
};
```

### 3. Use Meaningful Defaults

Choose defaults that work for most users:

```nix
fontSize = lib.mkOption {
  type = lib.types.int;
  default = 12;  # Reasonable default
  description = "Font size for the application";
};
```

### 4. Handle Dependencies

Document and handle module dependencies:

```nix
config = lib.mkIf cfg.enable {
  # Ensure required modules are enabled
  modules.shared.fonts.enable = lib.mkDefault true;
  
  # Your module configuration
};
```

### 5. Avoid Hardcoded Paths

Use configuration variables for paths:

```nix
configDir = lib.mkOption {
  type = lib.types.str;
  default = "${config.home.homeDirectory}/.config/myapp";
  description = "Configuration directory path";
};
```

## Common Patterns

### 1. Optional Features

```nix
enableAdvancedFeatures = lib.mkOption {
  type = lib.types.bool;
  default = false;
  description = "Enable advanced features";
};

config = lib.mkIf cfg.enable {
  programs.myapp = {
    enable = true;
    advancedMode = cfg.enableAdvancedFeatures;
  };
};
```

### 2. Multiple Packages

```nix
packages = lib.mkOption {
  type = lib.types.listOf lib.types.package;
  default = with pkgs; [ package1 package2 ];
  description = "List of packages to install";
};

config = lib.mkIf cfg.enable {
  home.packages = cfg.packages;
};
```

### 3. Conditional Configuration

```nix
config = lib.mkIf cfg.enable {
  programs.myapp = lib.mkMerge [
    {
      enable = true;
      basicSettings = cfg.settings;
    }
    (lib.mkIf cfg.enableAdvancedFeatures {
      advancedSettings = cfg.advancedSettings;
    })
  ];
};
```

## Troubleshooting

### Common Issues

1. **Module not found**: Ensure the module is imported in the category's default.nix
2. **Option conflicts**: Check for conflicting option definitions
3. **Type errors**: Verify option types match the provided values
4. **Missing dependencies**: Ensure required packages or modules are available

### Debugging Tips

1. Use `nix eval` to inspect option values
2. Check `nix flake check` for syntax errors
3. Use `--show-trace` for detailed error information
4. Test modules in isolation when possible

## Contributing

When contributing a new module:

1. Follow this development guide
2. Test thoroughly on your system
3. Update relevant documentation
4. Consider backward compatibility
5. Add appropriate examples and defaults

For more information, see the main CONTRIBUTING.md guide.