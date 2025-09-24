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
  # Development Workstation Example Configuration
  #
  # This example demonstrates a comprehensive development environment suitable for:
  # - Software engineers and developers
  # - DevOps engineers and system administrators
  # - Full-stack developers working with multiple technologies
  # - Teams requiring consistent development environments
  #
  # Features included:
  # - Complete development toolchain (Git, editors, debuggers)
  # - Multiple programming language support
  # - Container and virtualization tools
  # - Database and infrastructure tools
  # - Productivity applications for development workflow

  imports = [
    ../../common/default.nix
    ../../common/profiles/development.nix # Use development profile
  ];

  # Host identification - CUSTOMIZE THESE VALUES
  networking.hostName = "dev-workstation"; # Replace with your hostname
  networking.computerName = "Development Workstation";

  # User configuration - CUSTOMIZE THESE VALUES
  users.users.developer = {
    # Replace 'developer' with your username
    home = "/Users/developer"; # Update path with your username
    description = "Developer Name"; # Replace with your full name
  };

  # Set primary user for system-wide activation
  system.primaryUser = "developer"; # Replace with your username

  # Development workstation configuration
  config = {
    # Enable development profile (provides comprehensive dev tools)
    profiles.development.enable = true;

    # Additional development packages beyond the profile defaults
    environment.systemPackages = with pkgs; [
      # Advanced development tools
      unstablePkgs.devenv # Development environment manager
      unstablePkgs.direnv # Environment variable management
      unstablePkgs.just # Command runner (modern make)

      # Infrastructure and cloud tools
      terraform # Infrastructure as code
      ansible # Configuration management
      kubectl # Kubernetes CLI
      helm # Kubernetes package manager
      docker-compose # Container orchestration

      # Database tools
      postgresql # PostgreSQL client
      redis # Redis CLI
      mongodb-tools # MongoDB utilities

      # Network and debugging tools
      wireshark # Network protocol analyzer
      nmap # Network discovery
      tcpdump # Packet analyzer

      # Performance and monitoring
      htop # System monitor
      iotop # I/O monitor
      bandwhich # Network utilization by process

      # Additional productivity tools
      jq # JSON processor
      yq-go # YAML processor
      ripgrep # Fast text search
      fd # Fast file finder
      bat # Enhanced cat with syntax highlighting
      exa # Modern ls replacement

      # Version control enhancements
      git-lfs # Git Large File Storage
      gh # GitHub CLI
      lazygit # Terminal UI for Git

      # Documentation and note-taking
      pandoc # Document converter
      graphviz # Graph visualization
    ];

    # Development-optimized fonts
    fonts.packages = with pkgs; [
      # Programming fonts with ligatures
      nerd-fonts.fira-code
      nerd-fonts.jetbrains-mono
      nerd-fonts.hack
      nerd-fonts.source-code-pro

      # Additional fonts for documentation
      liberation_ttf
      dejavu_fonts
    ];

    # Development-focused Homebrew applications
    homebrew = {
      enable = true;
      onActivation = {
        cleanup = "zap"; # Remove unlisted packages
        autoUpdate = true; # Keep Homebrew updated
        upgrade = true; # Upgrade packages on activation
      };

      # Development-focused CLI tools from Homebrew
      brews = [
        "gh" # GitHub CLI (if not using Nix version)
        "act" # Run GitHub Actions locally
        "firebase-cli" # Firebase development tools
        "vercel-cli" # Vercel deployment CLI
        "railway" # Railway deployment CLI
      ];

      # Development applications
      casks = [
        # Code editors and IDEs
        "visual-studio-code" # Primary code editor
        "jetbrains-toolbox" # JetBrains IDE manager
        "sublime-text" # Alternative text editor

        # Development tools
        "docker" # Docker Desktop
        "postman" # API development and testing
        "insomnia" # Alternative API client
        "tableplus" # Database management
        "sequel-pro" # MySQL/MariaDB client

        # Design and prototyping
        "figma" # Design collaboration
        "sketch" # UI/UX design

        # Productivity and communication
        "slack" # Team communication
        "discord" # Developer community
        "zoom" # Video conferencing
        "notion" # Documentation and notes

        # Utilities
        "raycast" # Productivity launcher
        "alfred" # Alternative launcher
        "cleanmymac" # System maintenance
        "the-unarchiver" # Archive extraction

        # Browsers for testing
        "google-chrome" # Primary browser
        "firefox" # Alternative browser
        "microsoft-edge" # Cross-browser testing

        # Terminal and shell
        "iterm2" # Enhanced terminal
        "wezterm" # Modern terminal emulator
      ];

      # Mac App Store applications for development
      masApps = {
        "Xcode" = 497799835; # iOS/macOS development
        "TestFlight" = 899247664; # iOS app testing
        "Simulator" = 1192426158; # iOS Simulator (if separate)
        "Developer" = 640199958; # Apple Developer app
        "Transloader" = 1048809284; # Download manager
        "Klokki Slim - Time Tracking" = 1459795140; # Time tracking
      };
    };

    # Development-optimized system defaults
    system.defaults = {
      # Global system preferences for development
      NSGlobalDomain = {
        # Faster key repeat for coding
        InitialKeyRepeat = 15; # Faster initial repeat
        KeyRepeat = 2; # Faster subsequent repeats

        # Development-friendly settings
        AppleShowAllExtensions = true; # Always show file extensions
        ApplePressAndHoldEnabled = false; # Disable press-and-hold for accents
        NSNavPanelExpandedStateForSaveMode = true; # Expanded save dialogs
        NSNavPanelExpandedStateForSaveMode2 = true;
        PMPrintingExpandedStateForPrint = true; # Expanded print dialogs
        PMPrintingExpandedStateForPrint2 = true;

        # Interface preferences
        AppleInterfaceStyle = "Dark"; # Dark mode for reduced eye strain
        AppleShowScrollBars = "Always"; # Always show scroll bars
      };

      # Dock configuration for development workflow
      dock = {
        autohide = true; # More screen space for code
        show-recents = false; # Clean dock without recent apps
        tilesize = 36; # Compact dock icons
        magnification = false; # No magnification for consistency
        orientation = "bottom"; # Standard bottom orientation
        mineffect = "scale"; # Subtle minimize effect
      };

      # Finder optimized for development
      finder = {
        AppleShowAllFiles = true; # Show hidden files (important for dev)
        ShowPathbar = true; # Show path bar for navigation
        ShowStatusBar = true; # Show status bar with file info
        FXPreferredViewStyle = "Nlsv"; # List view by default
        FXDefaultSearchScope = "SCcf"; # Search current folder by default
      };

      # Trackpad settings for development comfort
      trackpad = {
        Clicking = true; # Tap to click
        TrackpadThreeFingerDrag = true; # Three-finger drag
        TrackpadRightClick = true; # Right-click with two fingers
      };
    };

    # Development-specific environment variables
    environment.variables = {
      EDITOR = "nvim"; # Default editor
      BROWSER = "open"; # Default browser command
      DEVELOPMENT_MODE = "true"; # Flag for development scripts

      # Development tool configurations
      DOCKER_BUILDKIT = "1"; # Enable Docker BuildKit
      COMPOSE_DOCKER_CLI_BUILD = "1"; # Use Docker CLI for compose

      # Language-specific environment variables
      NODE_OPTIONS = "--max-old-space-size=8192"; # Increase Node.js memory
      PYTHONDONTWRITEBYTECODE = "1"; # Don't create .pyc files
      GOPATH = "$HOME/go"; # Go workspace
      CARGO_HOME = "$HOME/.cargo"; # Rust package manager
    };

    # Development-specific activation scripts
    system.activationScripts.extraActivation.text = ''
      echo "Setting up development workstation..."

      # Create development directories
      mkdir -p /Users/developer/Development/{projects,tools,scripts}
      mkdir -p /Users/developer/.config/{nvim,git,docker}

      # Set up Git configuration directory permissions
      chown -R developer:staff /Users/developer/.config/git 2>/dev/null || true

      # Create Docker configuration directory
      mkdir -p /Users/developer/.docker
      chown -R developer:staff /Users/developer/.docker 2>/dev/null || true

      # Set up development tool directories
      mkdir -p /Users/developer/{.npm-global,.yarn/bin,.local/bin}
      chown -R developer:staff /Users/developer/.npm-global 2>/dev/null || true
      chown -R developer:staff /Users/developer/.yarn 2>/dev/null || true
      chown -R developer:staff /Users/developer/.local 2>/dev/null || true

      echo "Development workstation setup complete!"
    '';

    # Security settings appropriate for development
    security.pam.services.sudo_local = {
      touchIdAuth = true; # TouchID for sudo (convenient for dev)
      reattach = true; # Reattach to user session
    };
  };

  # Custom user preferences for development workflow
  system.defaults.CustomUserPreferences = {
    # Finder preferences for development
    "com.apple.finder" = {
      ShowExternalHardDrivesOnDesktop = true; # Show external drives
      ShowHardDrivesOnDesktop = false; # Hide internal drives
      ShowMountedServersOnDesktop = true; # Show network drives
      ShowRemovableMediaOnDesktop = true; # Show USB drives
      _FXSortFoldersFirst = true; # Sort folders first
      NewWindowTarget = "PfHm"; # New windows open to home
      AppleShowAllExtensions = true; # Always show extensions
      FXEnableExtensionChangeWarning = false; # Don't warn about extension changes
      WarnOnEmptyTrash = false; # Don't warn when emptying trash
    };

    # Terminal preferences
    "com.apple.Terminal" = {
      "Default Window Settings" = "Pro"; # Use Pro theme
      "Startup Window Settings" = "Pro";
    };

    # Activity Monitor preferences for development monitoring
    "com.apple.ActivityMonitor" = {
      OpenMainWindow = true; # Open main window on launch
      IconType = 5; # Show CPU usage in dock
      SortColumn = "CPUUsage"; # Sort by CPU usage
      SortDirection = 0; # Descending order
      ShowCategory = 100; # Show all processes
    };

    # Disable automatic software updates (developers often need control)
    "com.apple.SoftwareUpdate" = {
      AutomaticCheckEnabled = false; # Manual update checking
      AutomaticDownload = false; # Manual downloads
      CriticalUpdateInstall = true; # Still install security updates
    };

    # Development-friendly Safari settings
    "com.apple.Safari" = {
      IncludeDevelopMenu = true; # Enable develop menu
      WebKitDeveloperExtrasEnabledPreferenceKey = true; # Enable web inspector
      "com.apple.Safari.ContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled" = true;
    };
  };
}
