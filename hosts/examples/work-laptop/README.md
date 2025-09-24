# Work Laptop Example

This example configuration creates a professional work environment suitable for corporate employees, consultants, and remote workers who need productivity tools and enhanced security.

## Overview

**Profile Used**: Work  
**Target Users**: Corporate employees, consultants, remote workers, business professionals  
**Use Cases**: Corporate laptops, business environments, compliance-focused setups

## Features Included

### Productivity Applications
- **Microsoft Office Suite**: Word, Excel, PowerPoint, Outlook, Teams
- **Communication**: Slack, Zoom, WebEx, Skype for business communication
- **Document Management**: PDF Expert, Adobe Acrobat Reader, Apple iWork suite
- **Project Management**: Notion, Todoist, Trello, Evernote
- **Cloud Storage**: OneDrive, Dropbox, Google Drive, Box Drive

### Security and Compliance
- **Password Management**: 1Password, Bitwarden for secure credential storage
- **VPN Solutions**: NordVPN, ExpressVPN for secure remote access
- **Encryption Tools**: GPG for file encryption and digital signatures
- **System Security**: Enhanced firewall settings, secure defaults

### Business Tools
- **Time Tracking**: Toggl Track, RescueTime for productivity monitoring
- **Remote Access**: TeamViewer, AnyDesk, VNC Viewer for remote support
- **File Management**: Professional archive tools, cloud synchronization
- **System Maintenance**: CleanMyMac, AppCleaner for system optimization

### Professional Interface
- **Clean Workspace**: Auto-hiding dock, organized file management
- **Light Mode**: Professional appearance suitable for business environments
- **Enhanced Security**: TouchID authentication, secure login settings
- **Compliance Ready**: Settings appropriate for corporate compliance requirements

## Customization Guide

### 1. Basic Setup
Replace the placeholder values in `default.nix`:

```nix
# Update these values
networking.hostName = "your-work-laptop";
networking.computerName = "Your Work Laptop";

users.users.yourusername = {  # Replace 'employee' with your username
  home = "/Users/yourusername";
  description = "Your Full Name";
};

system.primaryUser = "yourusername";
```

### 2. Corporate Applications
Customize applications based on your company's requirements:

```nix
homebrew.casks = [
  # Standard business applications
  "microsoft-office"
  "microsoft-teams"
  "slack"
  
  # Add company-specific applications
  "your-company-app"
  "corporate-vpn-client"
  
  # Remove applications not needed in your environment
  # "webex"  # If your company doesn't use WebEx
];
```

### 3. Security Configuration
Adjust security settings for your corporate environment:

```nix
# Enable firewall if required by corporate policy
system.defaults.alf = {
  globalstate = 1;                        # Enable firewall
  allowsignedenabled = 1;                 # Allow signed apps
  allowdownloadsignedenabled = 1;         # Allow downloaded signed apps
};

# Adjust login security
system.defaults.loginwindow = {
  GuestEnabled = false;                   # Disable guest access
  DisableConsoleAccess = true;            # Enhanced security
};
```

### 4. Corporate Branding
Customize the appearance for your organization:

```nix
system.defaults = {
  NSGlobalDomain = {
    AppleInterfaceStyle = "Light";        # Professional light mode
  };
  
  dock = {
    tilesize = 40;                        # Professional icon size
    autohide = true;                      # Clean workspace
  };
};
```

## Corporate Integration

### Active Directory Integration
For environments using Active Directory:

1. **Domain Binding**: Configure domain binding through System Preferences
2. **Network Authentication**: Set up Kerberos authentication if required
3. **Group Policies**: Ensure compatibility with corporate group policies

### VPN Configuration
Set up corporate VPN access:

1. **Built-in VPN**: Configure through System Preferences > Network
2. **Third-party VPN**: Install corporate VPN client via Homebrew
3. **Always-on VPN**: Configure automatic VPN connection if required

### Certificate Management
For corporate certificates:

1. **Root Certificates**: Install corporate root certificates
2. **User Certificates**: Set up user authentication certificates
3. **Code Signing**: Configure code signing certificates if needed

## Security Best Practices

### Password Management
- Use a corporate-approved password manager (1Password or Bitwarden included)
- Enable two-factor authentication where possible
- Regular password rotation according to corporate policy

### Data Protection
- Enable FileVault disk encryption
- Configure automatic screen lock
- Set up Time Machine backups to corporate-approved storage

### Network Security
- Use corporate VPN for all external connections
- Avoid public Wi-Fi for sensitive work
- Keep firewall enabled and properly configured

### Software Updates
- Enable automatic security updates
- Test major updates in a non-production environment first
- Maintain an inventory of installed software for compliance

## Compliance Considerations

### Data Handling
- Configure applications to save documents locally by default
- Set up proper file organization for audit trails
- Ensure cloud storage complies with corporate data policies

### Audit Trail
- Enable system logging for security events
- Configure Time Machine for regular backups
- Maintain software inventory for compliance reporting

### Privacy Settings
- Disable personal advertising and tracking
- Configure Safari for enhanced privacy
- Review and adjust location services for business use

## Troubleshooting

### Common Corporate Issues

#### VPN Connection Problems
1. Verify corporate VPN credentials
2. Check network connectivity and firewall settings
3. Contact IT support for server configuration details

#### Microsoft Office Activation
1. Ensure you're signed in with your corporate Microsoft account
2. Verify your Office 365 license is active
3. Try signing out and back in to refresh the license

#### Domain Authentication Issues
1. Check network connectivity to domain controllers
2. Verify time synchronization with domain servers
3. Renew Kerberos tickets if authentication fails

#### Application Installation Restrictions
1. Check if your account has administrator privileges
2. Verify applications are approved by corporate policy
3. Contact IT for assistance with restricted applications

### Performance Optimization

#### For Video Conferencing
- Close unnecessary applications during meetings
- Use wired internet connection when possible
- Adjust video quality settings based on bandwidth

#### For Large Document Handling
- Increase available RAM if working with large files
- Use external storage for large project files
- Optimize cloud sync settings to avoid conflicts

## Migration from Personal Setup

### Separating Personal and Work Data
1. **Create separate user accounts**: Consider a work-only user account
2. **Use different browsers**: Separate personal and work browsing
3. **Organize file structure**: Keep work files in dedicated directories

### Backup Strategy
1. **Work data**: Use corporate-approved backup solutions
2. **Personal data**: Keep separate backup strategy for personal files
3. **Application settings**: Export/import settings when switching profiles

## Maintenance Schedule

### Daily Tasks
- Check for security updates
- Backup important work files
- Clear browser cache and temporary files

### Weekly Tasks
- Review installed applications for compliance
- Update corporate applications
- Check VPN and security tool functionality

### Monthly Tasks
- Full system backup verification
- Security audit of installed software
- Review and clean up file organization

## Getting Support

### Internal Support
- Contact your IT department for corporate-specific issues
- Use corporate help desk for application problems
- Follow company procedures for security incidents

### External Resources
- Check the main [Troubleshooting Guide](../../../docs/TROUBLESHOOTING.md)
- Review [Module Documentation](../../../docs/MODULES.md) for configuration details
- Consult vendor documentation for specific applications

## Contributing

When contributing improvements to this work configuration:
1. Ensure changes comply with common corporate security requirements
2. Test with various corporate applications and services
3. Document any corporate-specific customizations clearly
4. Consider privacy and security implications of all changes