# Minimal Nix Configuration Template

This is a minimal template for creating a basic Nix configuration.

## Features

- Essential system configuration only
- Minimal package set
- Basic shell environment
- No development tools or extras

## Quick Start

1. Update the `flake.nix` file:
   - Change the `nix-config` input URL
   - Update hostname and username
   - Adjust system architecture if needed

2. Build and switch:
   ```bash
   darwin-rebuild switch --flake .
   ```

## Customization

This template provides a minimal base. You can:
- Add more profiles as needed
- Enable additional modules
- Customize settings in host configuration