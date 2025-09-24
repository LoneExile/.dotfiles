{
  config,
  lib,
  pkgs,
  inputs,
  outputs,
  hostname,
  system,
  username,
  unstablePkgs,
  ...
}: {
  # Work Laptop Example Configuration
  #
  # This example demonstrates a professional work environment suitable for:
  # - Corporate employees and consultants
  # - Remote workers and distributed teams
  # - Business professionals requiring productivity tools
  # - Environments with security and compliance requirements
  #
  # Features included:
  # - Professional productivity applications
  # - Enhanced security settings
  # - Collaboration and communication tools
  # - Business-focused system optimizations
  # - Compliance-friendly configurations

  imports = [
    ../../common/default.nix
    ../../common/profiles/work.nix # Use work profile
  ];

  # Host identification - CUSTOMIZE THESE VALUES
  networking.hostName = "work-laptop"; # Replace with your hostname
  networking.computerName = "Work Laptop";

  # User configuration - CUSTOMIZE THESE VALUES
  users.users.employee = {
    # Replace 'employee' with your username
    home = "/Users/employee"; # Update path with your username
    description = "Employee Name"; # Replace with your full name
  };

  # Set primary user for system-wide activation
  system.primaryUser = "employee"; # Replace with your username

  # Work laptop configuration
  config = {
    # Enable work profile (provides business-focused tools and settings)
    profiles.work.enable = true;

    # Professional productivity packages
    environment.systemPackages = with pkgs; [
      # Business and productivity tools
      libreoffice # Office suite alternative
      pandoc # Document conversion
      graphviz # Diagram creation

      # Communication and collaboration
      unstablePkgs.zoom-us # Video conferencing (if available in Nix)

      # Security and compliance tools
      gnupg # GPG encryption
      pass # Password manager CLI

      # Network and VPN tools
      openvpn # VPN client
      wireguard-tools # Modern VPN protocol

      # File management and backup
      rsync # File synchronization
      rclone # Cloud storage sync

      # Development tools (minimal set for work)
      git # Version control
      vim # Text editor
      curl # HTTP client
      wget # File downloader

      # System utilities
      htop # System monitor
      tree # Directory tree viewer
      jq # JSON processor

      # Archive and compression
      unzip # Archive extraction
      p7zip # 7-Zip compression
    ];

    # Professional fonts for documents and presentations
    fonts.packages = with pkgs; [
      # Business-appropriate fonts
      liberation_ttf # LibreOffice compatible fonts
      dejavu_fonts # Professional sans-serif fonts
      nerd-fonts.fira-code # Programming font (for occasional coding)

      # Microsoft-compatible fonts for document compatibility
      corefonts # Arial, Times New Roman, etc.
      vistafonts # Calibri, Cambria, etc.
    ];

    # Work-focused Homebrew applications
    homebrew = {
      enable = true;
      onActivation = {
        cleanup = "zap"; # Keep system clean
        autoUpdate = true; # Security updates
        upgrade = true; # Keep apps updated
      };

      # Professional CLI tools
      brews = [
        "mas" # Mac App Store CLI
        "awscli" # AWS CLI (if using AWS)
        "azure-cli" # Azure CLI (if using Azure)
      ];

      # Professional applications
      casks = [
        # Microsoft Office Suite
        "microsoft-office" # Full Office suite
        "microsoft-teams" # Team collaboration
        "microsoft-outlook" # Email client
        "onedrive" # Cloud storage

        # Communication and collaboration
        "slack" # Team messaging
        "zoom" # Video conferencing
        "webex" # Alternative video conferencing
        "skype" # International communication

        # Productivity and organization
        "notion" # Note-taking and project management
        "todoist" # Task management
        "evernote" # Note organization
        "trello" # Project boards

        # File management and cloud storage
        "dropbox" # File sharing
        "google-drive" # Google cloud storage
        "box-drive" # Enterprise file sharing

        # Security and VPN
        "nordvpn" # VPN service
        "expressvpn" # Alternative VPN
        "1password" # Password manager
        "bitwarden" # Alternative password manager

        # PDF and document tools
        "adobe-acrobat-reader" # PDF viewer
        "pdf-expert" # PDF editor
        "pages" # Apple document editor
        "keynote" # Presentation software
        "numbers" # Spreadsheet application

        # Browsers for different purposes
        "google-chrome" # Primary browser
        "firefox" # Alternative browser
        "microsoft-edge" # Corporate browser

        # Utilities and system tools
        "raycast" # Productivity launcher
        "cleanmymac" # System maintenance
        "the-unarchiver" # Archive extraction
        "appcleaner" # Application removal

        # Time tracking and productivity
        "toggl-track" # Time tracking
        "rescuetime" # Productivity monitoring

        # Remote access and support
        "teamviewer" # Remote desktop
        "anydesk" # Alternative remote access
        "vnc-viewer" # VNC client
      ];

      # Mac App Store applications for business use
      masApps = {
        "Keynote" = 409183694; # Presentations
        "Numbers" = 409203825; # Spreadsheets
        "Pages" = 409201541; # Documents
        "Microsoft Word" = 462054704; # Word processor
        "Microsoft Excel" = 462058435; # Spreadsheets
        "Microsoft PowerPoint" = 462062816; # Presentations
        "Slack" = 803453959; # Team communication
        "Zoom" = 546505307; # Video conferencing
        "1Password 7" = 1333542190; # Password manager
        "Bitwarden" = 1352778147; # Alternative password manager
        "Todoist" = 585829637; # Task management
        "Evernote" = 406056744; # Note-taking
        "PDF Expert" = 1055273043; # PDF editor
        "The Unarchiver" = 425424353; # Archive utility
        "Amphetamine" = 937984704; # Keep system awake
      };
    };

    # Work-optimized system defaults
    system.defaults = {
      # Global system preferences for professional use
      NSGlobalDomain = {
        # Professional keyboard settings
        InitialKeyRepeat = 25; # Standard repeat rate
        KeyRepeat = 6; # Standard subsequent rate

        # Business-friendly settings
        AppleShowAllExtensions = true; # File type awareness
        ApplePressAndHoldEnabled = false; # Disable accents for efficiency
        NSNavPanelExpandedStateForSaveMode = true; # Expanded dialogs
        NSNavPanelExpandedStateForSaveMode2 = true;
        PMPrintingExpandedStateForPrint = true; # Expanded print dialogs
        PMPrintingExpandedStateForPrint2 = true;

        # Professional interface
        AppleInterfaceStyle = "Light"; # Light mode for professional appearance
        AppleShowScrollBars = "Always"; # Always visible scroll bars
        NSDocumentSaveNewDocumentsToCloud = false; # Save locally by default
      };

      # Professional dock configuration
      dock = {
        autohide = true; # Clean workspace
        show-recents = false; # No personal items visible
        tilesize = 40; # Professional icon size
        magnification = false; # Consistent appearance
        orientation = "bottom"; # Standard position
        mineffect = "scale"; # Subtle effects
        launchanim = false; # Faster app launching
      };

      # Business-focused Finder settings
      finder = {
        AppleShowAllFiles = false; # Hide system files for simplicity
        ShowPathbar = true; # Enhanced navigation
        ShowStatusBar = true; # File information
        FXPreferredViewStyle = "Nlsv"; # List view for file details
        FXDefaultSearchScope = "SCcf"; # Search current folder
        NewWindowTarget = "PfDe"; # New windows to Desktop
      };

      # Professional trackpad settings
      trackpad = {
        Clicking = true; # Tap to click for efficiency
        TrackpadThreeFingerDrag = false; # Prevent accidental drags
        TrackpadRightClick = true; # Right-click functionality
      };

      # Security-focused login window
      loginwindow = {
        GuestEnabled = false; # No guest access
        SHOWFULLNAME = true; # Show full names
        DisableConsoleAccess = true; # Disable console access
      };
    };

    # Work-appropriate environment variables
    environment.variables = {
      EDITOR = "vim"; # Standard editor
      BROWSER = "open"; # Default browser
      WORK_MODE = "true"; # Flag for work scripts

      # Security settings
      HISTCONTROL = "ignoredups:erasedups"; # Clean command history
      HISTSIZE = "1000"; # Limited history size

      # Professional development settings (if needed)
      GIT_EDITOR = "vim"; # Git editor
    };

    # Work-specific activation scripts
    system.activationScripts.extraActivation.text = ''
      echo "Setting up work laptop environment..."

      # Create professional directory structure
      mkdir -p /Users/employee/{Documents,Desktop,Downloads}
      mkdir -p /Users/employee/Documents/{Projects,Templates,Archive}

      # Set up configuration directories
      mkdir -p /Users/employee/.config/{git,ssh}

      # Ensure proper ownership
      chown -R employee:staff /Users/employee/Documents 2>/dev/null || true
      chown -R employee:staff /Users/employee/.config 2>/dev/null || true

      # Create work-specific directories
      mkdir -p /Users/employee/Work/{Current,Archive,Templates}
      chown -R employee:staff /Users/employee/Work 2>/dev/null || true

      echo "Work laptop setup complete!"
    '';

    # Enhanced security settings for work environment
    security.pam.services.sudo_local = {
      touchIdAuth = true; # TouchID for convenience
      reattach = true; # Session reattachment
    };

    # Work-specific firewall settings (if needed)
    # system.defaults.alf = {
    #   globalstate = 1;                        # Enable firewall
    #   allowsignedenabled = 1;                 # Allow signed apps
    #   allowdownloadsignedenabled = 1;         # Allow downloaded signed apps
    # };
  };

  # Professional user preferences
  system.defaults.CustomUserPreferences = {
    # Professional Finder settings
    "com.apple.finder" = {
      ShowExternalHardDrivesOnDesktop = false; # Clean desktop
      ShowHardDrivesOnDesktop = false; # Clean desktop
      ShowMountedServersOnDesktop = true; # Show network drives
      ShowRemovableMediaOnDesktop = true; # Show USB drives
      _FXSortFoldersFirst = true; # Organized file listing
      NewWindowTarget = "PfDe"; # Open to Desktop
      AppleShowAllExtensions = true; # File type awareness
      FXEnableExtensionChangeWarning = true; # Warn about changes
      WarnOnEmptyTrash = true; # Prevent accidental deletion
    };

    # Professional dock preferences
    "com.apple.dock" = {
      autohide = true; # Clean workspace
      launchanim = false; # Faster launching
      show-recents = false; # No personal items
      show-process-indicators = true; # Show running apps
      orientation = "bottom"; # Standard position
      tilesize = 40; # Professional size
      minimize-to-application = true; # Organized minimizing
    };

    # Security and privacy settings
    "com.apple.AdLib" = {
      allowApplePersonalizedAdvertising = false; # Privacy protection
    };

    # Professional Safari settings
    "com.apple.Safari" = {
      UniversalSearchEnabled = false; # Privacy protection
      SuppressSearchSuggestions = true; # Reduce data sharing
      SendDoNotTrackHTTPHeader = true; # Privacy preference
    };

    # Automatic updates for security
    "com.apple.SoftwareUpdate" = {
      AutomaticCheckEnabled = true; # Security updates
      AutomaticDownload = true; # Download updates
      CriticalUpdateInstall = true; # Install security updates
      ConfigDataInstall = true; # System data updates
    };

    # Professional Time Machine settings
    "com.apple.TimeMachine" = {
      DoNotOfferNewDisksForBackup = false; # Allow backup prompts
      RequiresACPower = true; # Backup when plugged in
    };

    # Activity Monitor for system awareness
    "com.apple.ActivityMonitor" = {
      OpenMainWindow = true; # Show main window
      IconType = 3; # Show network usage
      SortColumn = "CPUUsage"; # Sort by CPU
      SortDirection = 0; # Descending order
    };
  };
}
