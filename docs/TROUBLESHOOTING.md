# Troubleshooting Guide

This guide helps you diagnose and resolve common issues with the modular Nix configuration.

## 📋 Table of Contents

- [Quick Diagnostics](#quick-diagnostics)
- [Installation Issues](#installation-issues)
- [Build and Configuration Issues](#build-and-configuration-issues)
- [Module-Specific Issues](#module-specific-issues)
- [Performance Issues](#performance-issues)
- [Debug Mode](#debug-mode)
- [Getting Help](#getting-help)

## 🔍 Quick Diagnostics

### System Information

First, gather system information to understand your environment:

```bash
# Show system info
just info

# Check flake inputs
just inputs

# Validate configuration
just validate
```

### Common Diagnostic Commands

```bash
# Check if Nix is working
nix --version

# Check if flakes are enabled
nix flake --help

# Verify Darwin installation
darwin-rebuild --version

# Check system generation
darwin-rebuild --list-generations
```

## 🚀 Installation Issues

### Nix Installation Problems

#### Issue: "command not found: nix"

**Solution:**
```bash
# Install Nix using the Determinate Systems installer
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install

# Or use the official installer
sh <(curl -L https://nixos.org/nix/install)

# Restart your shell or source the profile
source ~/.nix-profile/etc/profile.d/nix.sh
```

#### Issue: "experimental feature 'flakes' is disabled"

**Solution:**
```bash
# Enable flakes temporarily
export NIX_CONFIG="experimental-features = nix-command flakes"

# Or add to ~/.config/nix/nix.conf permanently
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
```

### Darwin Installation Problems

#### Issue: "darwin-rebuild: command not found"

**Solution:**
```bash
# Install nix-darwin first
nix run nix-darwin -- switch --flake .#$(hostname)

# Or if you have the configuration ready
nix --extra-experimental-features 'nix-command flakes' build ".#darwinConfigurations.$(hostname).system"
sudo ./result/sw/bin/darwin-rebuild switch --flake ".#$(hostname)"
```

#### Issue: Permission denied during Darwin installation

**Solution:**
```bash
# Ensure you have admin privileges
sudo -v

# Check if you're in the admin group
groups $USER

# If not in admin group, add yourself (requires another admin)
sudo dseditgroup -o edit -a $USER -t user admin
```

## 🔧 Build and Configuration Issues

### Flake Build Errors

#### Issue: "error: getting status of '/nix/store/...': No such file or directory"

**Solution:**
```bash
# Clean up and rebuild
nix-collect-garbage -d
just clean
just build
```

#### Issue: "error: hash mismatch in fixed-output derivation"

**Solution:**
```bash
# Update flake inputs
just update

# Or update specific input
nix flake lock --update-input nixpkgs
```

#### Issue: Build fails with "out of disk space"

**Solution:**
```bash
# Clean up old generations and garbage collect
just gc

# Check disk usage
df -h
du -sh ~/.nix-profile/

# Remove old Darwin generations
sudo nix-collect-garbage -d
sudo nix-store --gc
```

### Configuration Syntax Errors

#### Issue: "error: syntax error, unexpected..."

**Solution:**
```bash
# Check syntax with detailed error reporting
just trace

# Format and lint your files
just fmt
just lint

# Check for common issues
just validate
```

#### Issue: "error: infinite recursion encountered"

**Solution:**
```bash
# Check for circular imports in your modules
# Look for modules importing each other
grep -r "import.*modules" modules/

# Use trace to see where recursion occurs
just trace
```

### Module Loading Issues

#### Issue: "error: attribute 'modules' missing"

**Solution:**
```bash
# Ensure modules are properly imported in flake.nix
# Check that lib/default.nix exports modules correctly

# Verify module structure
find modules/ -name "*.nix" -exec nix-instantiate --parse {} \;
```

#### Issue: Module options not recognized

**Solution:**
```bash
# Check if module is imported in the right place
# Verify module path in imports list
# Ensure module follows correct structure

# Test individual module
nix-instantiate --eval -E 'import ./modules/path/to/module.nix'
```

## 🧩 Module-Specific Issues

### Homebrew Module Issues

#### Issue: "Error: Homebrew is not installed"

**Solution:**
```bash
# Install Homebrew first
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Add to PATH
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"
```

#### Issue: Homebrew casks fail to install

**Solution:**
```bash
# Update Homebrew
brew update

# Check for conflicting installations
brew list --cask

# Clean up and retry
brew cleanup
darwin-rebuild switch --flake .
```

### Git Module Issues

#### Issue: Git signing fails

**Solution:**
```bash
# Check GPG setup
gpg --list-secret-keys

# Test signing
echo "test" | gpg --clearsign

# Configure Git to use correct GPG
git config --global gpg.program $(which gpg)
```

### Shell Module Issues

#### Issue: Zsh configuration not loading

**Solution:**
```bash
# Check if zsh is set as default shell
echo $SHELL

# Change default shell
chsh -s $(which zsh)

# Source configuration manually
source ~/.zshrc

# Check for syntax errors in zsh config
zsh -n ~/.zshrc
```

## ⚡ Performance Issues

### Slow Build Times

**Solutions:**
```bash
# Enable binary caches
echo "substituters = https://cache.nixos.org https://nix-community.cachix.org" >> ~/.config/nix/nix.conf
echo "trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=" >> ~/.config/nix/nix.conf

# Use more build cores
echo "max-jobs = auto" >> ~/.config/nix/nix.conf
echo "cores = 0" >> ~/.config/nix/nix.conf

# Enable parallel building
echo "build-cores = 0" >> ~/.config/nix/nix.conf
```

### High Memory Usage

**Solutions:**
```bash
# Limit memory usage during builds
echo "max-jobs = 2" >> ~/.config/nix/nix.conf

# Clean up regularly
just gc

# Monitor memory usage
top -o MEM
```

## 🐛 Debug Mode

### Enable Verbose Logging

```bash
# Build with detailed output
just trace

# Enable debug logging for specific components
export NIX_DEBUG=1
export NIXPKGS_ALLOW_UNFREE=1

# Darwin rebuild with verbose output
darwin-rebuild switch --flake . --verbose
```

### Debugging Specific Modules

```bash
# Test module in isolation
nix-instantiate --eval -E '
  let
    pkgs = import <nixpkgs> {};
    lib = pkgs.lib;
    config = {};
  in
  import ./modules/path/to/module.nix { inherit config lib pkgs; }
'

# Check module options
nix-instantiate --eval -E '
  (import ./modules/path/to/module.nix { 
    config = {}; 
    lib = (import <nixpkgs> {}).lib; 
    pkgs = import <nixpkgs> {}; 
  }).options
'
```

### Debugging Build Issues

```bash
# Keep failed builds for inspection
export NIX_KEEP_FAILED=1

# Show build logs
nix log /nix/store/...

# Build with maximum verbosity
nix build --verbose --print-build-logs
```

## 🆘 Getting Help

### Before Asking for Help

1. **Check this troubleshooting guide**
2. **Run diagnostics**: `just validate`
3. **Check recent changes**: `git log --oneline -10`
4. **Try a clean build**: `just clean && just build`
5. **Update inputs**: `just update`

### Information to Include

When reporting issues, include:

```bash
# System information
just info

# Flake metadata
nix flake metadata

# Error output with trace
just trace 2>&1 | tee error.log

# Recent changes
git log --oneline -5
```

### Where to Get Help

1. **GitHub Issues** - Report bugs and request features
2. **GitHub Discussions** - Ask questions and share ideas
3. **Nix Community** - [NixOS Discourse](https://discourse.nixos.org/)
4. **Discord/Matrix** - Real-time chat support

### Creating Minimal Reproducible Examples

When reporting issues:

1. **Isolate the problem** - Create minimal configuration that reproduces the issue
2. **Test on clean system** - Verify issue isn't environment-specific
3. **Include exact commands** - Show what you ran and what happened
4. **Share configuration** - Provide relevant parts of your config

### Common Solutions Checklist

- [ ] Updated flake inputs (`just update`)
- [ ] Cleaned build artifacts (`just clean`)
- [ ] Validated configuration (`just validate`)
- [ ] Checked disk space (`df -h`)
- [ ] Restarted shell/terminal
- [ ] Checked for typos in configuration
- [ ] Verified module imports are correct
- [ ] Tested with minimal configuration

---

If you're still experiencing issues after trying these solutions, please open an issue on GitHub with detailed information about your problem.