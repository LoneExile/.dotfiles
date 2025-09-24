# Development Nix Configuration Template

This template provides a comprehensive development environment with all the tools needed for software development.

## Features

- Full development toolchain
- Multiple programming language support
- Container tools (Docker, etc.)
- Advanced shell configuration
- Development-focused applications

## Quick Start

1. Update the `flake.nix` file:
   - Change the `nix-config` input URL
   - Update hostname and username
   - Adjust system architecture if needed
   - Customize enabled language modules

2. Build and switch:
   ```bash
   darwin-rebuild switch --flake .
   ```

## Included Tools

- Git with advanced configuration
- Neovim with development plugins
- Multiple programming languages (Python, Node.js, Rust, Go)
- Container tools (Docker, Podman)
- Shell enhancements (zsh, starship)
- Window management (Aerospace)

## Customization

- Enable/disable specific programming languages
- Add custom development tools
- Modify shell configuration
- Adjust window management settings