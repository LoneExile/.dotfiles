# Module Documentation

This document provides comprehensive documentation for all available modules in the modular Nix configuration. Each module is designed to be self-contained, configurable, and follows consistent patterns.

## 📋 Table of Contents

- [Module System Overview](#module-system-overview)
- [Darwin Modules](#darwin-modules)
- [Home Manager Modules](#home-manager-modules)
- [Shared Modules](#shared-modules)
- [Creating Custom Modules](#creating-custom-modules)
- [Module Configuration Examples](#module-configuration-examples)

## 🏗️ Module System Overview

### Module Structure

All modules follow a consistent structure:

```nix
{ config, lib, pkgs, ... }:
let
  cfg = config.modules.category.modulename;
in {
  options.modules.category.modulename = {
    enable = lib.mkEnableOption "module description";
    
    # Module-specific options
    option1 = lib.mkOption {
      type = lib.types.str;
      default = "default-value";
      description = "Option description";
    };
  };
  
  config = lib.mkIf cfg.enable {
    # Module implementation
  };
}
```

### Module Categories

- **`modules.darwin.*`** - macOS system-level configuration
- **`modules.home.*`** - User-level configuration via Home Manager
- **`modules.shared.*`** - Cross-platform configuration

### Common Options

Most modules include these standard options:

- `enable` - Enable/disable the module
- `extraConfig` - Additional configuration options
- `package` - Override the default package (where applicable)

## 🍎 Darwin Modules

Darwin modules configure macOS system-level settings and require administrator privileges.

### `modules.darwin.system`

Core macOS system configuration including Nix settings, keyboard, and basic system preferences.

#### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | false | Enable Darwin system configuration |
| `hostname` | string | "darwin-system" | System hostname |
| `stateVersion` | int | 5 | Darwin system state version |
| `primaryUser` | string | "le" | Primary user for system-wide activation |
| `allowUnfree` | bool | true | Allow unfree packages |
| `keyboard.enableKeyMapping` | bool | true | Enable keyboard key mapping |
| `keyboard.remapCapsLockToEscape` | bool | false | Remap Caps Lock to Escape |
| `nix.enableFlakes` | bool | true | Enable Nix flakes and nix-command |
| `nix.warnDirty` | bool | false | Warn about dirty Git repositories |
| `programs.enableZsh` | bool | true | Enable Zsh shell system-wide |
| `programs.enableNixIndex` | bool | true | Enable nix-index for command-not-found |

#### Example Configuration

```nix
modules.darwin.system = {
  enable = true;
  hostname = "my-macbook";
  primaryUser = "myuser";
  keyboard.remapCapsLockToEscape = true;
  nix.warnDirty = true;
};
```

### `modules.darwin.homebrew`

Homebrew package management for macOS applications and tools not available in Nixpkgs.

#### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | false | Enable Homebrew package management |
| `brews` | list of strings | [...] | List of Homebrew packages to install |
| `casks` | list of strings | [...] | List of Homebrew casks to install |
| `taps` | list of strings | [] | List of Homebrew taps to add |
| `masApps` | attrs | {...} | Mac App Store applications to install |
| `onActivation.cleanup` | enum | "zap" | Cleanup strategy ("none", "uninstall", "zap") |
| `onActivation.autoUpdate` | bool | true | Auto-update Homebrew on activation |
| `onActivation.upgrade` | bool | true | Upgrade packages on activation |

#### Example Configuration

```nix
modules.darwin.homebrew = {
  enable = true;
  brews = [ "gh" "bitwarden-cli" ];
  casks = [ "firefox" "discord" "visual-studio-code" ];
  taps = [ "homebrew/cask-fonts" ];
  masApps = {
    "Keynote" = 409183694;
    "Pages" = 409201541;
  };
  onActivation.cleanup = "uninstall";
};
```

### `modules.darwin.security`

Security-related configurations for macOS including TouchID and system security settings.

#### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | false | Enable security configurations |
| `touchId.enable` | bool | true | Enable TouchID for sudo |
| `gatekeeper.enable` | bool | true | Enable Gatekeeper |
| `firewall.enable` | bool | false | Enable macOS firewall |

#### Example Configuration

```nix
modules.darwin.security = {
  enable = true;
  touchId.enable = true;
  firewall.enable = true;
};
```

### `modules.darwin.defaults`

macOS system preferences and defaults configuration.

#### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | false | Enable macOS defaults configuration |
| `dock.*` | various | {...} | Dock configuration options |
| `finder.*` | various | {...} | Finder configuration options |
| `trackpad.*` | various | {...} | Trackpad configuration options |

## 🏠 Home Manager Modules

Home Manager modules configure user-level applications and environments.

### Shell Modules

#### `modules.home.shell.zsh`

Zsh shell configuration with modern enhancements and plugins.

##### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | false | Enable Zsh shell configuration |
| `enableAutosuggestions` | bool | true | Enable zsh autosuggestions |
| `enableSyntaxHighlighting` | bool | true | Enable zsh syntax highlighting |
| `enableCompletion` | bool | true | Enable zsh completion system |
| `historySize` | int | 10000 | Number of commands to keep in history |
| `enableZap` | bool | true | Enable Zap plugin manager |
| `extraConfig` | string | "" | Extra configuration to add to zshrc |

##### Example Configuration

```nix
modules.home.shell.zsh = {
  enable = true;
  historySize = 50000;
  enableZap = true;
  extraConfig = ''
    # Custom zsh configuration
    export CUSTOM_VAR="value"
  '';
};
```

#### `modules.home.shell.starship`

Starship prompt configuration for a modern, fast shell prompt.

##### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | false | Enable Starship prompt |
| `settings` | attrs | {...} | Starship configuration settings |

#### `modules.home.shell.aliases`

Shell aliases and functions for improved productivity.

##### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | false | Enable shell aliases |
| `extraAliases` | attrs | {} | Additional custom aliases |

### Development Modules

#### `modules.home.development.git`

Comprehensive Git configuration with modern workflows and tools.

##### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | false | Enable Git configuration |
| `userName` | string | "Apinant U-suwantim" | Git user name |
| `userEmail` | string | "Hello@Apinant.dev" | Git user email |
| `defaultBranch` | string | "main" | Default branch name for new repositories |
| `enableDiffSoFancy` | bool | true | Enable diff-so-fancy for better git diffs |
| `enableLfs` | bool | true | Enable Git LFS (Large File Storage) |
| `enableLazygit` | bool | true | Enable Lazygit TUI |
| `signing.enable` | bool | false | Enable commit signing |
| `signing.key` | string | "" | GPG key ID for signing commits |
| `signing.signByDefault` | bool | false | Sign all commits by default |

##### Example Configuration

```nix
modules.home.development.git = {
  enable = true;
  userName = "Your Name";
  userEmail = "your.email@example.com";
  defaultBranch = "main";
  signing = {
    enable = true;
    key = "YOUR_GPG_KEY_ID";
    signByDefault = true;
  };
  extraConfig = {
    core.editor = "code --wait";
    pull.rebase = false;
  };
};
```

#### `modules.home.development.editors`

Text editors and IDEs configuration including Neovim, VS Code, and others.

##### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | false | Enable editors configuration |
| `neovim.enable` | bool | true | Enable Neovim |
| `vscode.enable` | bool | false | Enable VS Code |

#### `modules.home.development.languages`

Programming language tools and environments.

##### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | false | Enable language tools |
| `node.enable` | bool | true | Enable Node.js tools |
| `python.enable` | bool | true | Enable Python tools |
| `rust.enable` | bool | false | Enable Rust tools |
| `go.enable` | bool | false | Enable Go tools |

#### `modules.home.development.containers`

Container and virtualization tools including Docker and related utilities.

##### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | false | Enable container tools |
| `docker.enable` | bool | true | Enable Docker tools |
| `kubernetes.enable` | bool | false | Enable Kubernetes tools |

### Desktop Modules

#### `modules.home.desktop.terminal`

Terminal emulator configuration including WezTerm and other terminal applications.

##### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | false | Enable terminal configuration |
| `wezterm.enable` | bool | true | Enable WezTerm configuration |

#### `modules.home.desktop.window-manager`

Window management tools including Aerospace and other tiling window managers.

##### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | false | Enable window manager configuration |
| `aerospace.enable` | bool | true | Enable Aerospace configuration |

#### `modules.home.desktop.productivity`

Productivity applications and tools for enhanced workflow.

##### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | false | Enable productivity tools |
| `raycast.enable` | bool | true | Enable Raycast launcher |

### Security Modules

#### `modules.home.security.gpg`

GPG configuration for encryption and signing.

##### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | false | Enable GPG configuration |
| `defaultKey` | string | "" | Default GPG key ID |

#### `modules.home.security.ssh`

SSH client configuration and key management.

##### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | false | Enable SSH configuration |
| `extraConfig` | string | "" | Additional SSH configuration |

## 🌐 Shared Modules

Shared modules provide cross-platform functionality.

### `modules.shared.fonts`

Font configuration and management.

#### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | false | Enable font configuration |
| `packages` | list of packages | [] | List of font packages to install |

### `modules.shared.networking`

Network configuration and tools.

#### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | false | Enable networking configuration |

## 🛠️ Creating Custom Modules

### Module Template

Use this template to create new modules:

```nix
{ config, lib, pkgs, ... }:
let
  cfg = config.modules.category.modulename;
in {
  options.modules.category.modulename = {
    enable = lib.mkEnableOption "module description";
    
    # Add your options here
    exampleOption = lib.mkOption {
      type = lib.types.str;
      default = "default-value";
      description = "Description of the option";
    };
    
    extraConfig = lib.mkOption {
      type = lib.types.attrs;
      default = {};
      description = "Additional configuration";
    };
  };
  
  config = lib.mkIf cfg.enable {
    # Module implementation
    # Configure packages, services, files, etc.
    
    home.packages = with pkgs; [
      # Add packages here
    ];
    
    # Apply extra configuration
  } // cfg.extraConfig;
}
```

### Best Practices

1. **Use descriptive option names** - Make options self-documenting
2. **Provide sensible defaults** - Users should be able to enable modules with minimal configuration
3. **Include documentation** - Add descriptions for all options
4. **Follow naming conventions** - Use consistent naming patterns
5. **Test thoroughly** - Ensure modules work in isolation and combination
6. **Handle dependencies** - Use `lib.mkIf` and proper conditionals

## 📚 Module Configuration Examples

### Minimal Development Setup

```nix
{
  modules = {
    darwin.system.enable = true;
    home = {
      shell.zsh.enable = true;
      development.git.enable = true;
    };
  };
}
```

### Full Development Environment

```nix
{
  modules = {
    darwin = {
      system.enable = true;
      homebrew.enable = true;
    };
    home = {
      shell = {
        zsh.enable = true;
        starship.enable = true;
        aliases.enable = true;
      };
      development = {
        git.enable = true;
        editors.enable = true;
        languages.enable = true;
        containers.enable = true;
      };
      desktop = {
        terminal.enable = true;
        window-manager.enable = true;
      };
    };
  };
}
```

### Work Environment

```nix
{
  modules = {
    darwin = {
      system.enable = true;
      homebrew.enable = true;
      security.enable = true;
    };
    home = {
      shell.zsh.enable = true;
      development.git = {
        enable = true;
        signing.enable = true;
      };
      desktop.productivity.enable = true;
      security = {
        gpg.enable = true;
        ssh.enable = true;
      };
    };
  };
}
```

---

For more examples and advanced configuration, see the [examples](../examples/) directory and [CONTRIBUTING.md](CONTRIBUTING.md) for development guidelines.