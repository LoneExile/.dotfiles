# Contributing Guidelines

Thank you for your interest in contributing to the modular Nix configuration! This document provides guidelines and workflows for contributors.

## 📋 Table of Contents

- [Getting Started](#getting-started)
- [Development Environment](#development-environment)
- [Development Workflow](#development-workflow)
- [Module Development](#module-development)
- [Code Style and Standards](#code-style-and-standards)
- [Testing](#testing)
- [Documentation](#documentation)
- [Pull Request Process](#pull-request-process)

## 🚀 Getting Started

### Prerequisites

Before contributing, ensure you have:

- **macOS** (Darwin) system
- **Nix** with flakes enabled
- **Git** for version control
- **Basic Nix knowledge** - Understanding of Nix language and concepts
- **Text editor** with Nix syntax support

### Fork and Clone

1. **Fork the repository** on GitHub
2. **Clone your fork**:
   ```bash
   git clone https://github.com/yourusername/nix-config.git
   cd nix-config
   ```
3. **Add upstream remote**:
   ```bash
   git remote add upstream https://github.com/originalowner/nix-config.git
   ```

## 🛠️ Development Environment

### Enter Development Shell

The project provides several development environments:

```bash
# Full development environment
nix develop

# Minimal environment for quick tasks
nix develop .#minimal

# Documentation-focused environment
nix develop .#docs
```

### Available Tools

The development environment includes:

- **nixd** - Nix language server
- **nixfmt-rfc-style** - Nix formatter
- **statix** - Nix linter
- **deadnix** - Dead code detection
- **mdbook** - Documentation generation
- **just** - Command runner
- **sops/age** - Secrets management

### Development Commands

Use `just` for common development tasks:

```bash
# Show all available commands
just --list

# Validate configuration
just validate

# Format code
just fmt

# Build configuration
just build

# Run tests
just check
```

## 🔄 Development Workflow

### Branch Strategy

1. **Create feature branch**:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Keep branch up to date**:
   ```bash
   git fetch upstream
   git rebase upstream/main
   ```

3. **Make atomic commits** with clear messages

### Commit Guidelines

Follow conventional commit format:

```
type(scope): description

[optional body]

[optional footer]
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes
- `refactor`: Code refactoring
- `test`: Adding tests
- `chore`: Maintenance tasks

**Examples:**
```bash
git commit -m "feat(modules): add new development module for Rust"
git commit -m "fix(darwin): resolve homebrew installation issue"
git commit -m "docs: update module documentation with examples"
```

### Testing Changes

Before submitting changes:

1. **Validate configuration**:
   ```bash
   just validate
   ```

2. **Test build**:
   ```bash
   just build
   ```

3. **Test on clean system** (if possible):
   ```bash
   # In a VM or clean environment
   nix build .#darwinConfigurations.test.system
   ```

## 🧩 Module Development

### Module Structure

All modules should follow this structure:

```nix
{ config, lib, pkgs, ... }:
let
  cfg = config.modules.category.modulename;
in {
  options.modules.category.modulename = {
    enable = lib.mkEnableOption "module description";
    
    # Module-specific options
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.defaultPackage;
      description = "Package to use for this module";
    };
    
    settings = lib.mkOption {
      type = lib.types.attrs;
      default = {};
      description = "Additional settings";
    };
    
    extraConfig = lib.mkOption {
      type = lib.types.attrs;
      default = {};
      description = "Extra configuration options";
    };
  };
  
  config = lib.mkIf cfg.enable {
    # Module implementation
    
    # Apply extra configuration
  } // cfg.extraConfig;
}
```

### Module Categories

Place modules in appropriate categories:

- **`modules/darwin/`** - macOS system-level configuration
- **`modules/home/`** - User-level Home Manager configuration
- **`modules/shared/`** - Cross-platform configuration

### Module Guidelines

1. **Single Responsibility** - Each module should handle one specific area
2. **Configurable** - Provide options for customization
3. **Documented** - Include descriptions for all options
4. **Tested** - Ensure module works in isolation and combination
5. **Backwards Compatible** - Don't break existing configurations

### Creating a New Module

1. **Use the template**:
   ```bash
   cp modules/_template.nix modules/category/newmodule.nix
   ```

2. **Update module structure**:
   - Change the module path in options
   - Add module-specific options
   - Implement configuration logic

3. **Add to module imports**:
   ```nix
   # In modules/category/default.nix
   imports = [
     ./existing-module.nix
     ./newmodule.nix  # Add your module
   ];
   ```

4. **Document the module**:
   - Add to `docs/MODULES.md`
   - Include usage examples
   - Document all options

### Module Testing

Test your module:

```bash
# Syntax check
nix-instantiate --parse modules/category/newmodule.nix

# Option evaluation
nix-instantiate --eval -E '
  let
    lib = (import <nixpkgs> {}).lib;
    module = import ./modules/category/newmodule.nix {
      config = {};
      inherit lib;
      pkgs = import <nixpkgs> {};
    };
  in
  module.options
'

# Integration test
just build
```

## 📝 Code Style and Standards

### Nix Code Style

Follow these conventions:

1. **Formatting**: Use `nixfmt-rfc-style`
   ```bash
   just fmt
   ```

2. **Naming**:
   - Use camelCase for options: `enableFeature`
   - Use kebab-case for files: `my-module.nix`
   - Use descriptive names: `enableAutosuggestions` not `enableAS`

3. **Structure**:
   ```nix
   # Good
   {
     option1 = value1;
     option2 = value2;
   }
   
   # Avoid
   { option1 = value1; option2 = value2; }
   ```

4. **Comments**:
   ```nix
   # Explain complex logic
   programs.zsh = {
     enable = true;
     # Custom completion configuration for better UX
     enableCompletion = true;
   };
   ```

### Linting

Run linters before submitting:

```bash
# Check formatting
just fmt-check

# Run linter
just lint

# Find dead code
just deadnix

# Run all checks
just validate
```

## 🧪 Testing

### Validation Checks

The project includes several validation checks:

1. **Flake check**: `nix flake check`
2. **Format check**: `nixfmt --check **/*.nix`
3. **Lint check**: `statix check .`
4. **Dead code check**: `deadnix .`

### Manual Testing

1. **Build test**:
   ```bash
   just build
   ```

2. **Switch test** (on test system):
   ```bash
   just switch
   ```

3. **Module isolation test**:
   ```bash
   # Test with minimal config
   nix build .#darwinConfigurations.minimal.system
   ```

### Continuous Integration

The project uses GitHub Actions for:

- Flake validation
- Format checking
- Lint checking
- Build testing
- Documentation building

## 📚 Documentation

### Documentation Requirements

All contributions should include appropriate documentation:

1. **Module documentation** in `docs/MODULES.md`
2. **Usage examples** for new features
3. **Update README.md** if adding major features
4. **Inline comments** for complex code

### Documentation Style

1. **Clear and concise** - Explain what, why, and how
2. **Include examples** - Show practical usage
3. **Use proper formatting** - Follow Markdown conventions
4. **Keep up to date** - Update docs when changing code

### Building Documentation

```bash
# Build documentation
just docs

# Serve locally for testing
just docs-serve
```

## 🔄 Pull Request Process

### Before Submitting

1. **Update your branch**:
   ```bash
   git fetch upstream
   git rebase upstream/main
   ```

2. **Run all checks**:
   ```bash
   just validate
   ```

3. **Test thoroughly**:
   ```bash
   just build
   # Test on your system if possible
   ```

4. **Update documentation** as needed

### Pull Request Template

Use this template for pull requests:

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Documentation update
- [ ] Refactoring
- [ ] Other (specify)

## Testing
- [ ] Validated configuration (`just validate`)
- [ ] Built successfully (`just build`)
- [ ] Tested on live system
- [ ] Updated documentation

## Checklist
- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] Documentation updated
- [ ] No breaking changes (or documented)
```

### Review Process

1. **Automated checks** must pass
2. **Code review** by maintainers
3. **Testing** on different configurations
4. **Documentation review**
5. **Approval and merge**

### After Merge

1. **Delete feature branch**:
   ```bash
   git branch -d feature/your-feature-name
   ```

2. **Update local main**:
   ```bash
   git checkout main
   git pull upstream main
   ```

## 🎯 Contribution Ideas

### Good First Issues

- Fix typos in documentation
- Add missing module options
- Improve error messages
- Add usage examples
- Update package versions

### Advanced Contributions

- Create new modules
- Improve build performance
- Add testing infrastructure
- Enhance documentation
- Optimize configurations

### Areas Needing Help

- **Testing** - More comprehensive test coverage
- **Documentation** - Examples and tutorials
- **Modules** - Additional software integrations
- **Performance** - Build time optimizations
- **Cross-platform** - Linux support

## 📞 Getting Help

### Communication Channels

- **GitHub Issues** - Bug reports and feature requests
- **GitHub Discussions** - Questions and general discussion
- **Pull Request Comments** - Code-specific discussions

### Asking Questions

When asking for help:

1. **Search existing issues** first
2. **Provide context** - What are you trying to do?
3. **Include details** - System info, error messages, config snippets
4. **Be specific** - Clear, focused questions get better answers

### Mentorship

New contributors are welcome! Maintainers are happy to:

- Review your first pull request
- Provide guidance on module development
- Help with Nix-specific questions
- Suggest good first issues

---

Thank you for contributing to the modular Nix configuration! Your contributions help make this project better for everyone. 🎉