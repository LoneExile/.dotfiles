{ config, lib, pkgs, inputs, outputs, hostname, system, username, unstablePkgs, ... }:
{
  # Multi-User Workstation Example Configuration
  #
  # This example demonstrates a shared workstation environment suitable for:
  # - Shared development environments and labs
  # - Educational institutions and coding bootcamps
  # - Team workstations with multiple developers
  # - Collaborative development spaces
  #
  # Features included:
  # - Comprehensive development tools for multiple users
  # - User-specific configurations and isolation
  # - Shared resources and common tools
  # - Enhanced security for multi-user access
  # - Collaborative development workflows
  
  imports = [
    ../../common/default.nix
    ../../common/profiles/development.nix  # Use development profile as base
  ];
  
  # Host identification - CUSTOMIZE THESE VALUES
  networking.hostName = "dev-workstation";  # Replace with your hostname
  networking.computerName = "Development Workstation";
  
  # Primary administrator user - CUSTOMIZE THESE VALUES
  users.users.admin = {  # Primary administrator account
    home = "/Users/admin";
    description = "System Administrator";
  };
  
  # Additional user accounts - ADD YOUR TEAM MEMBERS
  users.users.developer1 = {
    home = "/Users/developer1";
    description = "Developer One";
  };
  
  users.users.developer2 = {
    home = "/Users/developer2";
    description = "Developer Two";
  };
  
  users.users.intern = {
    home = "/Users/intern";
    description = "Intern Developer";
  };
  
  # Set primary user for system-wide activation
  system.primaryUser = "admin";  # Administrator manages the system
  
  # Multi-user workstation configuration
  config = {
    # Enable development profile (provides comprehensive dev tools)
    profiles.development.enable = true;
    
    # Comprehensive development packages for shared use
    environment.systemPackages = with pkgs; [
      # Development environments and tools
      unstablePkgs.devenv          # Development environment manager
      unstablePkgs.direnv          # Environment variable management
      unstablePkgs.just            # Command runner
      
      # Multiple language support
      nodejs                       # JavaScript/TypeScript
      python3                      # Python development
      go                          # Go development
      rustc                       # Rust development
      openjdk                     # Java development
      ruby                        # Ruby development
      php                         # PHP development
      
      # Database tools and servers
      postgresql                  # PostgreSQL client and server
      mysql80                     # MySQL client and server
      redis                       # Redis server and CLI
      mongodb-tools               # MongoDB utilities
      sqlite                      # SQLite database
      
      # Container and virtualization
      docker                      # Container runtime
      docker-compose              # Container orchestration
      kubectl                     # Kubernetes CLI
      helm                        # Kubernetes package manager
      
      # Infrastructure and cloud tools
      terraform                   # Infrastructure as code
      ansible                     # Configuration management
      vagrant                     # Development environment management
      
      # Version control and collaboration
      git                         # Version control
      git-lfs                     # Large file support
      gh                          # GitHub CLI
      gitlab-runner               # GitLab CI runner
      
      # Editors and IDEs (CLI versions)
      vim                         # Lightweight editor
      neovim                      # Modern vim
      emacs                       # Alternative editor
      
      # Network and debugging tools
      wireshark                   # Network analysis
      nmap                        # Network discovery
      tcpdump                     # Packet capture
      netcat                      # Network utility
      
      # System monitoring and performance
      htop                        # System monitor
      iotop                       # I/O monitor
      bandwhich                   # Network usage by process
      
      # File management and utilities
      tree                        # Directory tree display
      ripgrep                     # Fast text search
      fd                          # Fast file finder
      bat                         # Enhanced cat
      exa                         # Modern ls
      
      # Documentation and productivity
      pandoc                      # Document conversion
      graphviz                    # Graph visualization
      
      # Security and encryption
      gnupg                       # GPG encryption
      openssh                     # SSH client/server
      
      # Archive and compression
      unzip                       # Archive extraction
      p7zip                       # 7-Zip compression
      
      # JSON/YAML processing
      jq                          # JSON processor
      yq-go                       # YAML processor
      
      # Process management
      tmux                        # Terminal multiplexer
      screen                      # Alternative multiplexer
    ];
    
    # Comprehensive fonts for development
    fonts.packages = with pkgs; [
      # Programming fonts
      nerd-fonts.fira-code
      nerd-fonts.jetbrains-mono
      nerd-fonts.hack
      nerd-fonts.source-code-pro
      nerd-fonts.inconsolata
      
      # System fonts
      dejavu_fonts
      liberation_ttf
      
      # International support
      noto-fonts
      noto-fonts-cjk
    ];
    
    # Shared development applications via Homebrew
    homebrew = {
      enable = true;
      onActivation = {
        cleanup = "zap";           # Keep system clean
        autoUpdate = true;         # Keep tools updated
        upgrade = true;            # Upgrade packages
      };
      
      # Shared development CLI tools
      brews = [
        "gh"                       # GitHub CLI
        "gitlab-runner"            # GitLab CI runner
        "act"                      # Run GitHub Actions locally
        "firebase-cli"             # Firebase tools
        "vercel-cli"               # Vercel deployment
        "heroku"                   # Heroku CLI
        "awscli"                   # AWS CLI
        "azure-cli"                # Azure CLI
        "gcloud"                   # Google Cloud CLI
      ];
      
      # Shared development applications
      casks = [
        # Code editors and IDEs
        "visual-studio-code"       # Primary shared editor
        "jetbrains-toolbox"        # JetBrains IDE suite
        "sublime-text"             # Alternative editor
        "atom"                     # Community editor
        
        # Development tools
        "docker"                   # Docker Desktop
        "postman"                  # API development
        "insomnia"                 # Alternative API client
        "tableplus"                # Database management
        "sequel-pro"               # MySQL client
        "robo-3t"                  # MongoDB client
        
        # Design and prototyping (for full-stack teams)
        "figma"                    # Design collaboration
        "sketch"                   # UI/UX design
        "zeplin"                   # Design handoff
        
        # Communication and collaboration
        "slack"                    # Team communication
        "discord"                  # Developer communities
        "zoom"                     # Video conferencing
        "microsoft-teams"          # Alternative communication
        
        # Browsers for testing
        "google-chrome"            # Primary browser
        "firefox"                  # Alternative browser
        "microsoft-edge"           # Cross-browser testing
        "safari-technology-preview" # Latest Safari features
        
        # Utilities and productivity
        "raycast"                  # Productivity launcher
        "alfred"                   # Alternative launcher
        "the-unarchiver"           # Archive extraction
        
        # Terminal applications
        "iterm2"                   # Enhanced terminal
        "wezterm"                  # Modern terminal
        
        # Version control GUI
        "github-desktop"           # Git GUI
        "sourcetree"               # Alternative Git GUI
        "gitup"                    # Git visualization
        
        # Virtualization
        "vmware-fusion"            # Virtual machines
        "parallels"                # Alternative virtualization
        
        # System monitoring
        "activity-monitor"         # System monitoring
        "disk-utility"             # Disk management
      ];
      
      # Shared Mac App Store applications
      masApps = {
        "Xcode" = 497799835;                    # iOS/macOS development
        "TestFlight" = 899247664;               # iOS testing
        "Transloader" = 1048809284;             # Download manager
        "The Unarchiver" = 425424353;           # Archive utility
        "Amphetamine" = 937984704;              # Keep system awake
      };
    };
    
    # Multi-user optimized system defaults
    system.defaults = {
      # Global preferences for shared workstation
      NSGlobalDomain = {
        # Efficient typing for developers
        InitialKeyRepeat = 15;     # Fast initial repeat
        KeyRepeat = 2;             # Fast subsequent repeat
        
        # Shared workstation settings
        AppleShowAllExtensions = true;           # Show file extensions
        ApplePressAndHoldEnabled = false;        # Disable accents for coding
        NSNavPanelExpandedStateForSaveMode = true;      # Expanded dialogs
        NSNavPanelExpandedStateForSaveMode2 = true;
        PMPrintingExpandedStateForPrint = true;         # Expanded print dialogs
        PMPrintingExpandedStateForPrint2 = true;
        
        # Professional interface
        AppleInterfaceStyle = "Dark";            # Dark mode for development
        AppleShowScrollBars = "Always";          # Always show scroll bars
        NSDocumentSaveNewDocumentsToCloud = false;  # Save locally by default
      };
      
      # Shared dock configuration
      dock = {
        autohide = true;                         # More screen space
        show-recents = false;                    # No personal items
        tilesize = 40;                          # Moderate icon size
        magnification = false;                   # Consistent appearance
        orientation = "bottom";                  # Standard position
        mineffect = "scale";                    # Subtle effects
        launchanim = false;                     # Faster launching
      };
      
      # Shared Finder settings
      finder = {
        AppleShowAllFiles = true;               # Show hidden files (dev need)
        ShowPathbar = true;                     # Enhanced navigation
        ShowStatusBar = true;                   # File information
        FXPreferredViewStyle = "Nlsv";         # List view for details
        FXDefaultSearchScope = "SCcf";         # Search current folder
      };
      
      # Shared trackpad settings
      trackpad = {
        Clicking = true;                        # Tap to click
        TrackpadThreeFingerDrag = true;         # Three-finger drag
        TrackpadRightClick = true;              # Right-click functionality
      };
      
      # Security for multi-user environment
      loginwindow = {
        GuestEnabled = false;                   # No guest access
        SHOWFULLNAME = true;                    # Show user names
        DisableConsoleAccess = true;            # Enhanced security
      };
    };
    
    # Multi-user environment variables
    environment.variables = {
      EDITOR = "nvim";                          # Shared editor preference
      BROWSER = "open";                         # Default browser
      SHARED_WORKSTATION = "true";              # Flag for shared environment
      
      # Development environment settings
      DOCKER_BUILDKIT = "1";                    # Enable Docker BuildKit
      COMPOSE_DOCKER_CLI_BUILD = "1";           # Use Docker CLI
      
      # Shared development paths
      SHARED_TOOLS_PATH = "/usr/local/shared";  # Shared tools directory
      
      # Language-specific shared settings
      NODE_OPTIONS = "--max-old-space-size=4096";  # Moderate Node.js memory
      PYTHONDONTWRITEBYTECODE = "1";            # Clean Python environment
      GOPATH = "/usr/local/go-workspace";       # Shared Go workspace
    };
    
    # Multi-user activation scripts
    system.activationScripts.extraActivation.text = ''
      echo "Setting up multi-user development workstation..."
      
      # Create shared directories
      mkdir -p /usr/local/shared/{tools,projects,resources}
      mkdir -p /usr/local/go-workspace/{src,bin,pkg}
      
      # Create user-specific development directories
      for user in admin developer1 developer2 intern; do
        if [ -d "/Users/$user" ]; then
          echo "Setting up directories for $user..."
          
          # Personal development directories
          mkdir -p "/Users/$user/Development"/{personal,shared,experiments}
          mkdir -p "/Users/$user/.config"/{git,nvim,tmux}
          mkdir -p "/Users/$user/.local"/{bin,share}
          
          # Set proper ownership
          chown -R "$user:staff" "/Users/$user/Development" 2>/dev/null || true
          chown -R "$user:staff" "/Users/$user/.config" 2>/dev/null || true
          chown -R "$user:staff" "/Users/$user/.local" 2>/dev/null || true
        fi
      done
      
      # Set shared directory permissions
      chmod 755 /usr/local/shared
      chmod 755 /usr/local/go-workspace
      
      # Create shared project templates
      mkdir -p /usr/local/shared/templates/{web,mobile,backend,fullstack}
      
      echo "Multi-user workstation setup complete!"
    '';
    
    # Enhanced security for multi-user environment
    security.pam.services.sudo_local = {
      touchIdAuth = true;                       # TouchID for convenience
      reattach = true;                          # Session reattachment
    };
  };
  
  # Multi-user system preferences
  system.defaults.CustomUserPreferences = {
    # Shared Finder preferences
    "com.apple.finder" = {
      ShowExternalHardDrivesOnDesktop = true;   # Show external drives
      ShowHardDrivesOnDesktop = false;          # Hide internal drives
      ShowMountedServersOnDesktop = true;       # Show network drives
      ShowRemovableMediaOnDesktop = true;       # Show USB drives
      _FXSortFoldersFirst = true;              # Organized listing
      NewWindowTarget = "PfHm";                # Open to home
      AppleShowAllExtensions = true;            # Show extensions
      FXEnableExtensionChangeWarning = false;   # Don't warn (dev environment)
      WarnOnEmptyTrash = true;                 # Prevent accidents
    };
    
    # Shared dock preferences
    "com.apple.dock" = {
      autohide = true;                         # More screen space
      launchanim = false;                      # Faster launching
      show-recents = false;                    # No personal items
      show-process-indicators = true;          # Show running apps
      orientation = "bottom";                  # Standard position
      tilesize = 40;                          # Moderate size
      minimize-to-application = true;          # Organized minimizing
    };
    
    # Development-friendly Safari settings
    "com.apple.Safari" = {
      IncludeDevelopMenu = true;               # Enable develop menu
      WebKitDeveloperExtrasEnabledPreferenceKey = true;  # Web inspector
      "com.apple.Safari.ContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled" = true;
    };
    
    # Shared security settings
    "com.apple.AdLib" = {
      allowApplePersonalizedAdvertising = false;  # Privacy protection
    };
    
    # Automatic updates for shared system
    "com.apple.SoftwareUpdate" = {
      AutomaticCheckEnabled = true;            # Check for updates
      AutomaticDownload = true;               # Download updates
      CriticalUpdateInstall = true;           # Install security updates
      ConfigDataInstall = true;               # System data updates
    };
    
    # Shared Activity Monitor preferences
    "com.apple.ActivityMonitor" = {
      OpenMainWindow = true;                   # Show main window
      IconType = 5;                           # Show CPU usage
      SortColumn = "CPUUsage";                # Sort by CPU
      SortDirection = 0;                      # Descending order
      ShowCategory = 100;                     # Show all processes
    };
    
    # Energy settings for workstation
    "com.apple.PowerManagement" = {
      "Custom Profile" = {
        "AC Power" = {
          "System Sleep Timer" = 0;           # Never sleep (workstation)
          "Disk Sleep Timer" = 0;             # Never sleep disks
          "Display Sleep Timer" = 60;         # Display sleep after 1 hour
        };
      };
    };
  };
}