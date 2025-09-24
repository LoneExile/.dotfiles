# Minimal Server Example

This example configuration creates a minimal server environment optimized for headless operation, automation, and resource efficiency.

## Overview

**Profile Used**: Minimal  
**Target Users**: System administrators, DevOps engineers, CI/CD environments  
**Use Cases**: Headless servers, build runners, minimal development environments, resource-constrained systems

## Features Included

### Essential System Tools
- **Core Utilities**: Basic file, shell, and text manipulation tools
- **Network Tools**: SSH, curl, wget, rsync for remote operations
- **System Monitoring**: htop, iotop, lsof for system management
- **Text Editors**: vim, nano for configuration editing
- **Version Control**: Git for deployment and configuration management

### Server Optimizations
- **No GUI Applications**: Homebrew disabled, CLI tools only
- **Minimal Resource Usage**: Disabled animations, minimal dock, efficient defaults
- **Security Focus**: Restricted access, secure defaults, minimal attack surface
- **Automation Ready**: Tools for scripting and remote management

### Network and Remote Access
- **SSH Support**: OpenSSH for secure remote access
- **Network Diagnostics**: netcat, nmap, tcpdump for troubleshooting
- **File Synchronization**: rsync for efficient file transfers
- **Process Management**: tmux, screen for persistent sessions

## Customization Guide

### 1. Basic Setup
Replace the placeholder values in `default.nix`:

```nix
# Update these values
networking.hostName = "your-server";
networking.computerName = "Your Server Name";

users.users.yourusername = {  # Replace 'admin' with your username
  home = "/Users/yourusername";
  description = "Your Name or Role";
};

system.primaryUser = "yourusername";
```

### 2. Essential Tools Only
Add only necessary tools for your server purpose:

```nix
environment.systemPackages = with pkgs; [
  # Keep essential tools
  curl
  wget
  git
  vim
  
  # Add server-specific tools
  docker          # If running containers
  kubernetes-cli  # If managing Kubernetes
  terraform       # If managing infrastructure
  
  # Remove unnecessary tools
  # neofetch      # Remove if not needed for diagnostics
];
```

### 3. Security Configuration
Enhance security for server environments:

```nix
# Disable TouchID (not available on servers anyway)
security.pam.services.sudo_local = {
  touchIdAuth = false;
  reattach = false;
};

# Enhanced login security
system.defaults.loginwindow = {
  GuestEnabled = false;
  DisableConsoleAccess = true;
  PowerOffDisabledWhileLoggedIn = true;
};
```

### 4. Resource Optimization
Minimize resource usage:

```nix
system.defaults = {
  # Disable animations
  NSGlobalDomain = {
    NSAutomaticWindowAnimationsEnabled = false;
    NSWindowResizeTime = 0.001;
  };
  
  # Minimal dock
  dock = {
    autohide = true;
    static-only = true;
    launchanim = false;
  };
};
```

## Server Use Cases

### CI/CD Runner
For continuous integration and deployment:

```nix
environment.systemPackages = with pkgs; [
  # CI/CD tools
  git
  docker
  nodejs          # For Node.js projects
  python3         # For Python projects
  go              # For Go projects
  
  # Build tools
  gnumake
  cmake
  
  # Testing tools
  curl            # For API testing
  jq              # For JSON processing
];
```

### Build Server
For compiling and building software:

```nix
environment.systemPackages = with pkgs; [
  # Compilers and build tools
  gcc
  clang
  gnumake
  cmake
  ninja
  
  # Language-specific tools
  nodejs
  python3
  go
  rustc
  
  # Archive and packaging
  tar
  gzip
  zip
];
```

### Monitoring Server
For system and application monitoring:

```nix
environment.systemPackages = with pkgs; [
  # Monitoring tools
  htop
  iotop
  netstat
  ss
  
  # Log analysis
  grep
  awk
  sed
  
  # Network monitoring
  tcpdump
  nmap
  netcat
];
```

### Development Server
For minimal development environments:

```nix
environment.systemPackages = with pkgs; [
  # Essential development tools
  git
  vim
  tmux
  
  # Language runtimes
  nodejs
  python3
  
  # Database clients
  postgresql
  redis
  
  # Network tools
  curl
  wget
];
```

## Remote Access Setup

### SSH Configuration
Set up secure SSH access:

1. **Generate SSH Keys** (on client):
   ```bash
   ssh-keygen -t ed25519 -C "your-email@example.com"
   ```

2. **Copy Public Key** to server:
   ```bash
   ssh-copy-id admin@your-server
   ```

3. **Configure SSH** in `/etc/ssh/sshd_config`:
   ```
   PermitRootLogin no
   PasswordAuthentication no
   PubkeyAuthentication yes
   ```

### Tmux for Persistent Sessions
Use tmux for long-running processes:

```bash
# Start new session
tmux new-session -d -s server-session

# Attach to session
tmux attach-session -t server-session

# List sessions
tmux list-sessions
```

## Security Best Practices

### User Access Control
- Use dedicated service accounts for applications
- Implement sudo access with specific command restrictions
- Regular audit of user accounts and permissions

### Network Security
- Configure firewall rules for necessary ports only
- Use VPN for administrative access
- Implement fail2ban for SSH protection

### System Hardening
- Regular security updates (automated for critical patches)
- Disable unnecessary services
- Monitor system logs for suspicious activity

### Data Protection
- Encrypt sensitive data at rest
- Secure backup procedures
- Regular security audits

## Monitoring and Maintenance

### System Monitoring
Essential monitoring for server health:

```bash
# System resources
htop                    # Process and resource monitoring
iotop                   # I/O monitoring
df -h                   # Disk usage
free -h                 # Memory usage

# Network monitoring
netstat -tulpn          # Network connections
ss -tulpn               # Socket statistics
tcpdump -i any          # Network packet capture

# Log monitoring
tail -f /var/log/system.log    # System logs
journalctl -f                  # System journal (if available)
```

### Automated Maintenance
Set up automated maintenance tasks:

1. **Log Rotation**: Configure logrotate for log management
2. **Cleanup Scripts**: Regular cleanup of temporary files
3. **Update Checks**: Automated security update installation
4. **Backup Verification**: Regular backup integrity checks

## Performance Optimization

### Resource Management
- Monitor CPU and memory usage regularly
- Optimize application configurations for server environment
- Use resource limits for applications

### Storage Optimization
- Regular cleanup of temporary files
- Monitor disk usage and implement alerts
- Optimize file system performance

### Network Optimization
- Configure network buffers for server workloads
- Monitor network utilization
- Optimize for server-specific network patterns

## Troubleshooting

### Common Server Issues

#### SSH Connection Problems
1. **Check SSH Service**: `sudo systemctl status ssh`
2. **Verify Network**: `ping your-server`
3. **Check Firewall**: Review firewall rules
4. **Key Authentication**: Verify SSH key configuration

#### Performance Issues
1. **Resource Usage**: Check CPU, memory, and disk usage
2. **Process Analysis**: Identify resource-intensive processes
3. **Network Bottlenecks**: Monitor network utilization
4. **Log Analysis**: Review system logs for errors

#### Service Failures
1. **Service Status**: Check service status and logs
2. **Configuration**: Verify service configuration files
3. **Dependencies**: Check service dependencies
4. **Resource Limits**: Verify resource availability

### Diagnostic Commands
Essential commands for server troubleshooting:

```bash
# System information
uname -a                # System information
uptime                  # System uptime and load
ps aux                  # Running processes
lsof                    # Open files and network connections

# Network diagnostics
ping hostname           # Network connectivity
traceroute hostname     # Network path tracing
nslookup hostname       # DNS resolution
netstat -rn            # Routing table

# Disk and filesystem
df -h                   # Disk usage
du -sh /path           # Directory size
lsblk                  # Block devices
mount                  # Mounted filesystems
```

## Backup and Recovery

### Backup Strategy
- **System Configuration**: Regular backup of configuration files
- **Application Data**: Automated backup of application data
- **User Data**: Backup of user home directories
- **Database Backups**: Regular database dumps if applicable

### Recovery Procedures
- **System Recovery**: Procedures for system restoration
- **Data Recovery**: Steps for data restoration from backups
- **Service Recovery**: Process for restoring failed services
- **Disaster Recovery**: Complete system rebuild procedures

## Contributing

When contributing improvements to this minimal server configuration:
1. Focus on essential tools and minimal resource usage
2. Prioritize security and automation capabilities
3. Test thoroughly in headless environments
4. Document server-specific optimizations and procedures
5. Consider various server use cases (CI/CD, monitoring, development)