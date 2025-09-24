# Development Workstation Example

This example configuration creates a comprehensive development environment suitable for software engineers, DevOps professionals, and full-stack developers.

## Overview

**Profile Used**: Development  
**Target Users**: Software developers, DevOps engineers, system administrators  
**Use Cases**: Primary development machine, team development environments, coding bootcamps

## Features Included

### Development Tools
- **Editors**: Neovim, Visual Studio Code, JetBrains Toolbox, Sublime Text
- **Version Control**: Git with LFS, GitHub CLI, Lazygit
- **Containers**: Docker Desktop, Docker Compose, container management tools
- **Infrastructure**: Terraform, Ansible, Kubernetes tools (kubectl, helm)
- **Databases**: PostgreSQL, Redis, MongoDB clients and tools

### Programming Languages
The development profile includes comprehensive language support:
- **JavaScript/TypeScript**: Node.js, npm, yarn, development servers
- **Python**: Python 3, pip, virtual environment tools
- **Go**: Go compiler and tools
- **Rust**: Cargo and Rust toolchain
- **Java**: OpenJDK and development tools
- **Additional**: Support for many other languages through Nix packages

### Productivity Applications
- **Communication**: Slack, Discord, Zoom
- **Documentation**: Notion, Pandoc for document conversion
- **Design**: Figma, Sketch for UI/UX work
- **API Testing**: Postman, Insomnia
- **Database Management**: TablePlus, Sequel Pro

### System Optimizations
- **Performance**: Optimized for development workflows
- **Display**: Dark mode, enhanced file visibility
- **Keyboard**: Faster key repeat rates for coding
- **Dock**: Auto-hide for maximum screen space
- **Security**: TouchID for sudo authentication

## Customization Guide

### 1. Basic Setup
Replace the placeholder values in `default.nix`:

```nix
# Update these values
networking.hostName = "your-hostname";
networking.computerName = "Your Computer Name";

users.users.yourusername = {  # Replace 'developer' with your username
  home = "/Users/yourusername";
  description = "Your Full Name";
};

system.primaryUser = "yourusername";
```

### 2. Package Customization
Add or remove packages based on your needs:

```nix
environment.systemPackages = with pkgs; [
  # Add your preferred tools
  your-favorite-tool
  
  # Remove unwanted tools by commenting out
  # unwanted-package
];
```

### 3. Homebrew Applications
Customize the GUI applications:

```nix
homebrew.casks = [
  # Keep the ones you want
  "visual-studio-code"
  "docker"
  
  # Add your preferred applications
  "your-favorite-app"
  
  # Remove unwanted applications by commenting out
  # "unwanted-app"
];
```

### 4. System Preferences
Adjust macOS defaults to your liking:

```nix
system.defaults = {
  dock = {
    autohide = false;  # Change to false if you prefer visible dock
    tilesize = 48;     # Adjust dock icon size
  };
  
  NSGlobalDomain = {
    AppleInterfaceStyle = "Light";  # Change to "Light" for light mode
  };
};
```

## Language-Specific Configurations

### Node.js Development
The configuration includes Node.js optimizations:
- Increased memory limit for Node.js processes
- Global npm directory setup
- Yarn configuration

### Python Development
Python development features:
- Multiple Python versions available
- Virtual environment support
- Common Python development tools

### Go Development
Go development setup:
- GOPATH configuration
- Go tools and utilities
- Module support

### Docker Development
Container development features:
- Docker Desktop with BuildKit enabled
- Docker Compose support
- Container debugging tools

## Security Considerations

### TouchID Authentication
The configuration enables TouchID for sudo commands, providing security with convenience for development workflows.

### Development vs Production
This configuration is optimized for development and should not be used as-is for production servers. For production use, consider the minimal profile instead.

## Performance Optimizations

### Memory Management
- Increased Node.js memory limits
- Optimized Docker settings
- Efficient package management

### Development Workflow
- Fast key repeat rates for coding
- Auto-hiding dock for screen space
- Enhanced file visibility in Finder

## Troubleshooting

### Common Issues

#### Homebrew Installation Fails
If Homebrew casks fail to install:
1. Check if you have sufficient disk space
2. Verify your Apple ID is signed in for Mac App Store apps
3. Try running the activation manually: `darwin-rebuild switch`

#### Docker Issues
If Docker doesn't start properly:
1. Ensure Docker Desktop is installed via Homebrew
2. Check that virtualization is enabled in BIOS/UEFI
3. Restart the Docker service: `brew services restart docker`

#### Performance Issues
If the system feels slow:
1. Check Activity Monitor for resource usage
2. Consider reducing the number of startup applications
3. Adjust Docker resource limits in Docker Desktop preferences

### Getting Help
- Check the main [Troubleshooting Guide](../../../docs/TROUBLESHOOTING.md)
- Review [Module Documentation](../../../docs/MODULES.md)
- Examine specific module configurations in the `modules/` directory

## Migration from Existing Setup

### From Homebrew-only Setup
1. Export your current Homebrew packages: `brew bundle dump`
2. Review the generated Brewfile and add desired packages to this configuration
3. Test the new configuration before removing the old setup

### From Other Nix Configurations
1. Compare your existing configuration with this example
2. Migrate custom packages and settings gradually
3. Test each change before proceeding to the next

## Next Steps

After setting up this configuration:

1. **Test the build**: `nix build .#darwinConfigurations.your-hostname.system`
2. **Apply the configuration**: `darwin-rebuild switch --flake .#your-hostname`
3. **Customize further**: Add your personal tools and preferences
4. **Set up development environments**: Configure your preferred editors and tools
5. **Create project templates**: Set up templates for your common project types

## Contributing

If you improve this example configuration:
1. Test your changes thoroughly
2. Update this documentation
3. Submit a pull request with clear descriptions of the improvements
4. Consider if your changes would benefit other example configurations