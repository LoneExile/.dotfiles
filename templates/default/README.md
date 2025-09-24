# Nix Configuration Template

This is a basic template for creating a modular Nix configuration based on the main configuration.

## Quick Start

1. Update the `flake.nix` file:
   - Change the `nix-config` input URL to point to the main configuration repository
   - Update the hostname and username in the `darwinConfigurations`
   - Adjust the system architecture if needed

2. Create your host configuration:
   ```bash
   mkdir -p hosts/my-machine
   # Add your host-specific configuration in hosts/my-machine/default.nix
   ```

3. Build and switch:
   ```bash
   darwin-rebuild switch --flake .
   ```

## Customization

- Enable/disable profiles in the `profiles` section
- Add custom modules in a `modules/` directory
- Override settings in your host configuration

## Documentation

See the main configuration repository for detailed documentation on:
- Available modules and options
- Profile configurations
- Customization examples
- Troubleshooting guides