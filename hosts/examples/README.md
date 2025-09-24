# Example Host Configurations

This directory contains example host configurations demonstrating different use cases and scenarios for the modular Nix configuration system. These examples serve as templates and learning resources for setting up new hosts.

## Available Examples

### 1. Development Workstation (`development-workstation/`)
- **Use Case**: Primary development machine for software engineers
- **Profile**: Development
- **Features**: Full development environment, multiple language support, container tools
- **Target Users**: Software developers, DevOps engineers, system administrators

### 2. Work Laptop (`work-laptop/`)
- **Use Case**: Corporate laptop for professional work
- **Profile**: Work
- **Features**: Productivity apps, security-focused, collaboration tools
- **Target Users**: Corporate employees, consultants, remote workers

### 3. Personal MacBook (`personal-macbook/`)
- **Use Case**: Personal computer for hobby development and daily use
- **Profile**: Personal
- **Features**: Customized for comfort, hobby tools, entertainment apps
- **Target Users**: Personal users, hobbyist developers, students

### 4. Minimal Server (`minimal-server/`)
- **Use Case**: Headless server or CI/CD runner
- **Profile**: Minimal
- **Features**: Essential tools only, no GUI applications, optimized for automation
- **Target Users**: Server administrators, CI/CD environments, minimal setups

### 5. Multi-User Workstation (`multi-user-workstation/`)
- **Use Case**: Shared development machine with multiple users
- **Profile**: Development (with multi-user customizations)
- **Features**: Shared development tools, user-specific configurations
- **Target Users**: Teams, shared development environments, labs

### 6. Gaming and Creative (`gaming-creative/`)
- **Use Case**: Personal machine optimized for gaming and creative work
- **Profile**: Personal (with creative extensions)
- **Features**: Creative applications, gaming tools, media production
- **Target Users**: Content creators, gamers, digital artists

## How to Use These Examples

1. **Browse the examples** to find one that matches your use case
2. **Copy the example** to your hosts directory:
   ```bash
   cp -r hosts/examples/development-workstation hosts/my-hostname
   ```
3. **Customize the configuration** by editing `hosts/my-hostname/default.nix`
4. **Update the flake** to include your new host configuration
5. **Build and test** your configuration

## Example Structure

Each example follows this structure:
```
example-name/
├── default.nix           # Main host configuration
├── README.md            # Specific documentation for this example
└── customizations/      # Optional additional customizations
    ├── packages.nix     # Custom package lists
    ├── services.nix     # Custom service configurations
    └── overrides.nix    # Profile overrides
```

## Customization Guidelines

### Common Customizations
- **Hostname and username**: Update these in every example
- **Package selection**: Add or remove packages based on your needs
- **System preferences**: Adjust macOS defaults to your liking
- **Homebrew apps**: Modify the list of GUI applications

### Profile Overrides
Examples show how to override profile defaults:
```nix
# Override profile settings
system.defaults.dock.autohide = false;  # Override profile default

# Add host-specific packages
environment.systemPackages = with pkgs; [
  # Your additional packages
];
```

### Security Considerations
- Review and customize security settings for your environment
- Update SSH keys and GPG configurations
- Adjust firewall and network settings as needed

## Testing Your Configuration

Before applying to your main system:

1. **Dry run**: Test the configuration build
   ```bash
   nix build .#darwinConfigurations.your-hostname.system
   ```

2. **Check for issues**: Use the diagnostic tools
   ```bash
   ./scripts/diagnose-config.sh your-hostname
   ```

3. **Validate configuration**: Run validation checks
   ```bash
   ./scripts/validate-config.sh your-hostname
   ```

## Contributing Examples

When contributing new examples:

1. **Follow the naming convention**: Use descriptive, kebab-case names
2. **Include comprehensive documentation**: Add a detailed README.md
3. **Add comments**: Explain configuration choices and customizations
4. **Test thoroughly**: Ensure the example builds and works correctly
5. **Keep it generic**: Avoid personal information or specific credentials

## Support

If you encounter issues with these examples:

1. Check the [Troubleshooting Guide](../../docs/TROUBLESHOOTING.md)
2. Review the [Module Documentation](../../docs/MODULES.md)
3. Examine the [Setup Instructions](../../docs/SETUP.md)
4. Open an issue with details about your specific use case