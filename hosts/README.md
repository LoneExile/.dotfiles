# Host Configuration System

This directory contains host-specific configurations for the modular Nix configuration system.

## Directory Structure

```
hosts/
├── README.md              # This documentation
├── _template/             # Template for new host configurations
│   └── default.nix       # Host configuration template
├── common/                # Shared configuration across all hosts
│   ├── default.nix       # Base configuration for all hosts
│   └── profiles/         # Configuration profiles
│       ├── minimal.nix   # Minimal system profile
│       ├── development.nix # Development environment profile
│       ├── work.nix      # Work environment profile
│       └── personal.nix  # Personal use profile
└── {hostname}/           # Host-specific configurations
    └── default.nix       # Host customizations and overrides
```

## Configuration Profiles

The system provides four predefined profiles that can be selected for each host:

### 1. Minimal Profile (`minimal.nix`)
- Essential tools only
- Lightweight configuration
- Suitable for: servers, CI environments, minimal setups

### 2. Development Profile (`development.nix`)
- Comprehensive development tools
- Full programming language support
- Container tools and editors
- Suitable for: software developers, DevOps engineers

### 3. Work Profile (`work.nix`)
- Professional work environment
- Productivity applications
- Work-focused security settings
- Suitable for: corporate environments, team collaboration

### 4. Personal Profile (`personal.nix`)
- Personal computing optimization
- Hobby development tools
- Customized user experience
- Suitable for: personal machines, learning environments

## Creating a New Host Configuration

1. Copy the template directory:
   ```bash
   cp -r hosts/_template hosts/{hostname}
   ```

2. Edit `hosts/{hostname}/default.nix`:
   - Replace `HOSTNAME` with your actual hostname
   - Replace `USERNAME` with your actual username
   - Select and enable one profile by setting its `enable` option to `true`
   - Add host-specific customizations as needed

3. Add the host to your flake configuration

## Profile Selection

Each host must select exactly one profile. In your host configuration:

```nix
imports = [
  ../common/default.nix
  ../common/profiles/personal.nix  # Select your desired profile
];

config = {
  profiles.personal.enable = true;  # Enable the selected profile
  
  # Host-specific overrides
  # ...
};
```

## Host Overrides

Host configurations can override any setting from the selected profile:

```nix
config = {
  # Override profile defaults
  system.defaults.dock.autohide = false;  # Override profile setting
  
  # Add host-specific packages
  environment.systemPackages = with pkgs; [
    # Host-specific tools
  ];
  
  # Host-specific Homebrew apps
  homebrew.casks = [
    "host-specific-app"
  ];
};
```

## Common Configuration

The `common/default.nix` file contains settings shared across all hosts:
- Base Nix configuration
- Common system settings
- Module imports
- Profile selection mechanism

## Best Practices

1. **Keep profiles generic**: Profiles should contain settings applicable to the use case, not specific to individual machines
2. **Use host overrides sparingly**: Only override profile settings when necessary for the specific machine
3. **Document customizations**: Add comments explaining why host-specific overrides are needed
4. **Test profile changes**: Changes to profiles affect all hosts using that profile
5. **Use meaningful hostnames**: Choose descriptive hostnames that indicate the machine's purpose

## Examples

### Minimal Server Setup
```nix
imports = [
  ../common/default.nix
  ../common/profiles/minimal.nix
];

config = {
  profiles.minimal.enable = true;
  
  # Server-specific settings
  services.openssh.enable = true;
};
```

### Development Workstation
```nix
imports = [
  ../common/default.nix
  ../common/profiles/development.nix
];

config = {
  profiles.development.enable = true;
  
  # Additional development tools
  environment.systemPackages = with pkgs; [
    docker-compose
    kubernetes-cli
  ];
};
```

### Work Laptop
```nix
imports = [
  ../common/default.nix
  ../common/profiles/work.nix
];

config = {
  profiles.work.enable = true;
  
  # Work-specific security
  security.pam.services.sudo_local.touchIdAuth = true;
  
  # Work applications
  homebrew.casks = [
    "microsoft-teams"
    "zoom"
  ];
};
```