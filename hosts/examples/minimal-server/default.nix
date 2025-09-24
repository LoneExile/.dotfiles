{ config, lib, pkgs, inputs, outputs, hostname, system, username, unstablePkgs, ... }:
{
  # Minimal Server Example Configuration
  #
  # This example demonstrates a minimal server environment suitable for:
  # - Headless servers and remote systems
  # - CI/CD runners and build environments
  # - Minimal development environments
  # - Resource-constrained systems
  # - Automated deployment targets
  #
  # Features included:
  # - Essential system tools only
  # - No GUI applications
  # - Optimized for automation and remote access
  # - Minimal resource usage
  # - Security-focused defaults
  
  imports = [
    ../../common/default.nix
    ../../common/profiles/minimal.nix  # Use minimal profile
  ];
  
  # Host identification - CUSTOMIZE THESE VALUES
  networking.hostName = "minimal-server";  # Replace with your hostname
  networking.computerName = "Minimal Server";
  
  # User configuration - CUSTOMIZE THESE VALUES
  users.users.admin = {  # Replace 'admin' with your username
    home = "/Users/admin";  # Update path with your username
    description = "System Administrator";  # Replace with your name/role
  };
  
  # Set primary user for system-wide activation
  system.primaryUser = "admin";  # Replace with your username
  
  # Minimal server configuration
  config = {
    # Enable minimal profile (provides only essential tools)
    profiles.minimal.enable = true;
    
    # Essential server packages only
    environment.systemPackages = with pkgs; [
      # Core system utilities
      coreutils                   # Basic file, shell and text utilities
      findutils                   # File finding utilities
      gnugrep                     # Text search utilities
      gnused                      # Stream editor
      gawk                        # Text processing
      
      # Network tools
      curl                        # HTTP client
      wget                        # File downloader
      openssh                     # SSH client and server
      rsync                       # File synchronization
      
      # System monitoring and management
      htop                        # System process monitor
      iotop                       # I/O monitoring
      lsof                        # List open files
      ps                          # Process status
      
      # Text editors (minimal)
      vim                         # Lightweight text editor
      nano                        # Simple text editor
      
      # Archive and compression
      gzip                        # Compression utility
      unzip                       # Archive extraction
      tar                         # Archive creation and extraction
      
      # Version control (essential for deployments)
      git                         # Version control system
      
      # Process management
      tmux                        # Terminal multiplexer
      screen                      # Alternative terminal multiplexer
      
      # File management
      tree                        # Directory tree display
      less                        # File pager
      
      # Network diagnostics
      netcat                      # Network utility
      nmap                        # Network discovery
      tcpdump                     # Network packet analyzer
      
      # System information
      neofetch                    # System information display
      
      # Automation and scripting
      jq                          # JSON processor
      yq-go                       # YAML processor
      
      # Security tools
      gnupg                       # GPG encryption
      
      # Log management
      logrotate                   # Log rotation utility
    ];
    
    # Minimal fonts (only if text rendering is needed)
    fonts.packages = with pkgs; [
      dejavu_fonts                # Basic fonts for any text rendering
    ];
    
    # Disable Homebrew for minimal server (Nix-only approach)
    homebrew = {
      enable = false;             # No Homebrew for minimal setup
    };
    
    # Minimal system defaults optimized for server use
    system.defaults = {
      # Global system preferences for server efficiency
      NSGlobalDomain = {
        # Minimal interface settings
        AppleShowAllExtensions = true;           # Show file extensions
        ApplePressAndHoldEnabled = false;        # Disable press-and-hold
        NSNavPanelExpandedStateForSaveMode = false;     # Compact dialogs
        NSNavPanelExpandedStateForSaveMode2 = false;
        PMPrintingExpandedStateForPrint = false;        # Compact print dialogs
        PMPrintingExpandedStateForPrint2 = false;
        
        # Server-appropriate interface
        AppleInterfaceStyle = lib.mkDefault null;       # System default (usually light)
        AppleShowScrollBars = "Always";          # Always show scroll bars
        NSDocumentSaveNewDocumentsToCloud = false;  # Save locally
        
        # Minimal animations for performance
        NSAutomaticWindowAnimationsEnabled = false;  # Disable window animations
        NSWindowResizeTime = 0.001;              # Faster window resizing
      };
      
      # Minimal dock configuration (hidden and compact)
      dock = {
        autohide = true;                         # Hide dock to save resources
        show-recents = false;                    # No recent applications
        tilesize = 32;                          # Smallest practical size
        magnification = false;                   # No magnification
        orientation = "bottom";                  # Standard position
        mineffect = "scale";                    # Minimal effect
        launchanim = false;                     # No launch animations
        static-only = true;                     # Static dock items only
      };
      
      # Minimal Finder settings
      finder = {
        AppleShowAllFiles = true;               # Show all files (important for servers)
        ShowPathbar = false;                    # Minimal UI
        ShowStatusBar = false;                  # Minimal UI
        FXPreferredViewStyle = "Nlsv";         # List view (most efficient)
        FXDefaultSearchScope = "SCcf";         # Search current folder
        NewWindowTarget = "PfLo";              # New windows to root
      };
      
      # Minimal trackpad settings (if applicable)
      trackpad = {
        Clicking = true;                        # Basic functionality
        TrackpadThreeFingerDrag = false;        # Disable advanced gestures
        TrackpadRightClick = true;              # Basic right-click
      };
      
      # Security-focused login settings
      loginwindow = {
        GuestEnabled = false;                   # No guest access
        SHOWFULLNAME = true;                    # Show full names for security
        DisableConsoleAccess = true;            # Disable console access
        PowerOffDisabledWhileLoggedIn = true;   # Prevent accidental shutdown
      };
    };
    
    # Minimal environment variables
    environment.variables = {
      EDITOR = "vim";                           # Lightweight editor
      PAGER = "less";                          # Standard pager
      MINIMAL_MODE = "true";                   # Flag for minimal scripts
      
      # Efficient shell settings
      HISTCONTROL = "ignoredups:erasedups";     # Clean command history
      HISTSIZE = "500";                        # Limited history size
      HISTFILESIZE = "1000";                   # Limited history file
      
      # Disable unnecessary features
      HOMEBREW_NO_AUTO_UPDATE = "1";           # No Homebrew auto-updates
      HOMEBREW_NO_ANALYTICS = "1";             # No analytics
    };
    
    # Minimal activation scripts
    system.activationScripts.extraActivation.text = ''
      echo "Setting up minimal server environment..."
      
      # Create essential directories only
      mkdir -p /Users/admin/{.config,.local/bin}
      
      # Create minimal log directory
      mkdir -p /Users/admin/logs
      
      # Set up SSH directory with proper permissions
      mkdir -p /Users/admin/.ssh
      chmod 700 /Users/admin/.ssh 2>/dev/null || true
      
      # Ensure proper ownership
      chown -R admin:staff /Users/admin/.config 2>/dev/null || true
      chown -R admin:staff /Users/admin/.local 2>/dev/null || true
      chown -R admin:staff /Users/admin/.ssh 2>/dev/null || true
      chown -R admin:staff /Users/admin/logs 2>/dev/null || true
      
      echo "Minimal server setup complete!"
    '';
    
    # Security settings for server environment
    security.pam.services.sudo_local = {
      touchIdAuth = false;                      # Disable TouchID for server use
      reattach = false;                         # No session reattachment needed
    };
    
    # Disable unnecessary services for minimal footprint
    services = {
      # Disable GUI-related services if possible
      # Note: Some services might be required even for minimal setups
    };
  };
  
  # Minimal user preferences (disable unnecessary features)
  system.defaults.CustomUserPreferences = {
    # Minimal Finder preferences
    "com.apple.finder" = {
      ShowExternalHardDrivesOnDesktop = false;  # Clean desktop
      ShowHardDrivesOnDesktop = false;          # Clean desktop
      ShowMountedServersOnDesktop = false;      # Clean desktop
      ShowRemovableMediaOnDesktop = false;      # Clean desktop
      _FXSortFoldersFirst = true;              # Organized listing
      NewWindowTarget = "PfLo";                # Open to root
      AppleShowAllExtensions = true;            # Show extensions
      FXEnableExtensionChangeWarning = true;    # Warn about changes
      WarnOnEmptyTrash = true;                 # Prevent accidents
      DisableAllAnimations = true;             # No animations for performance
    };
    
    # Minimal dock preferences
    "com.apple.dock" = {
      autohide = true;                         # Hide dock
      launchanim = false;                      # No animations
      show-recents = false;                    # No recent items
      show-process-indicators = false;         # Minimal indicators
      orientation = "bottom";                  # Standard position
      tilesize = 32;                          # Minimal size
      magnification = false;                   # No magnification
      minimize-to-application = true;          # Efficient minimizing
      mineffect = "scale";                    # Minimal effect
      static-only = true;                     # Static items only
    };
    
    # Disable unnecessary features
    "com.apple.AdLib" = {
      allowApplePersonalizedAdvertising = false;  # No ads
    };
    
    # Minimal Safari settings (if Safari is used)
    "com.apple.Safari" = {
      UniversalSearchEnabled = false;          # No search suggestions
      SuppressSearchSuggestions = true;        # No suggestions
      SendDoNotTrackHTTPHeader = true;         # Privacy
      AutoOpenSafeDownloads = false;          # Security
    };
    
    # Automatic security updates only
    "com.apple.SoftwareUpdate" = {
      AutomaticCheckEnabled = true;            # Check for updates
      AutomaticDownload = false;              # Manual download
      CriticalUpdateInstall = true;           # Security updates only
      ConfigDataInstall = true;               # System data updates
    };
    
    # Minimal Time Machine settings
    "com.apple.TimeMachine" = {
      DoNotOfferNewDisksForBackup = true;      # No backup prompts
      RequiresACPower = true;                 # Backup when plugged in only
    };
    
    # Minimal Activity Monitor (if used)
    "com.apple.ActivityMonitor" = {
      OpenMainWindow = false;                  # Don't open automatically
      IconType = 0;                           # Application icon only
      SortColumn = "CPUUsage";                # Sort by CPU
      SortDirection = 0;                      # Descending
      ShowCategory = 101;                     # System processes
    };
    
    # Disable screen saver for server use
    "com.apple.screensaver" = {
      askForPassword = 1;                     # Require password
      askForPasswordDelay = 0;                # Immediate password requirement
    };
    
    # Minimal energy settings
    "com.apple.PowerManagement" = {
      # Prevent sleep for server operations
      "Custom Profile" = {
        "AC Power" = {
          "System Sleep Timer" = 0;           # Never sleep on AC power
          "Disk Sleep Timer" = 0;             # Never sleep disks
          "Display Sleep Timer" = 30;         # Display sleep after 30 min
        };
      };
    };
  };
}