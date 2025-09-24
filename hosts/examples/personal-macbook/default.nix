{ config, lib, pkgs, inputs, outputs, hostname, system, username, unstablePkgs, ... }:
{
  # Personal MacBook Example Configuration
  #
  # This example demonstrates a personal computing environment suitable for:
  # - Personal daily computing and entertainment
  # - Hobby development and learning projects
  # - Creative work and media consumption
  # - Students and personal productivity
  #
  # Features included:
  # - Customized user experience optimized for comfort
  # - Entertainment and media applications
  # - Hobby development tools
  # - Personal productivity applications
  # - Creative and design tools
  
  imports = [
    ../../common/default.nix
    ../../common/profiles/personal.nix  # Use personal profile
  ];
  
  # Host identification - CUSTOMIZE THESE VALUES
  networking.hostName = "personal-macbook";  # Replace with your hostname
  networking.computerName = "Personal MacBook";
  
  # User configuration - CUSTOMIZE THESE VALUES
  users.users.user = {  # Replace 'user' with your username
    home = "/Users/user";  # Update path with your username
    description = "Your Name";  # Replace with your full name
  };
  
  # Set primary user for system-wide activation
  system.primaryUser = "user";  # Replace with your username
  
  # Personal MacBook configuration
  config = {
    # Enable personal profile (provides personalized tools and settings)
    profiles.personal.enable = true;
    
    # Personal computing packages
    environment.systemPackages = with pkgs; [
      # Entertainment and media
      unstablePkgs.yt-dlp          # YouTube downloader
      ffmpeg                       # Media processing
      imagemagick                  # Image manipulation
      
      # Creative tools
      gimp                         # Image editing
      inkscape                     # Vector graphics
      blender                      # 3D modeling (if interested)
      
      # Personal productivity
      obsidian                     # Note-taking and knowledge management
      logseq                       # Alternative note-taking
      
      # Hobby development tools
      git                          # Version control
      nodejs                       # JavaScript runtime
      python3                      # Python for scripting
      
      # File management and utilities
      syncthing                    # File synchronization
      rclone                       # Cloud storage management
      
      # System utilities and fun tools
      neofetch                     # System information display
      htop                         # System monitor
      tree                         # Directory tree viewer
      cowsay                       # Fun terminal tool
      fortune                      # Random quotes
      
      # Network tools
      curl                         # HTTP client
      wget                         # File downloader
      
      # Archive and compression
      unzip                        # Archive extraction
      p7zip                        # 7-Zip compression
      
      # Text processing
      jq                           # JSON processor
      yq-go                        # YAML processor
      
      # Personal automation
      just                         # Command runner
      direnv                       # Environment management
    ];
    
    # Personal and creative fonts
    fonts.packages = with pkgs; [
      # Programming fonts for hobby coding
      nerd-fonts.fira-code
      nerd-fonts.jetbrains-mono
      nerd-fonts.hack
      nerd-fonts.source-code-pro
      
      # Creative and design fonts
      nerd-fonts.droid-sans-mono
      liberation_ttf
      dejavu_fonts
      
      # Fun and decorative fonts
      comic-neue                   # Modern comic sans alternative
      
      # International fonts
      noto-fonts                   # Google Noto fonts
      noto-fonts-cjk              # Chinese, Japanese, Korean
      noto-fonts-emoji            # Emoji support
    ];
    
    # Personal-focused Homebrew applications
    homebrew = {
      enable = true;
      onActivation = {
        cleanup = "zap";           # Keep system clean
        autoUpdate = true;         # Keep apps updated
        upgrade = true;            # Upgrade on activation
      };
      
      # Personal CLI tools
      brews = [
        "gh"                       # GitHub CLI for personal projects
        "youtube-dl"               # Alternative YouTube downloader
        "mas"                      # Mac App Store CLI
      ];
      
      # Personal applications
      casks = [
        # Entertainment and media
        "spotify"                  # Music streaming
        "vlc"                      # Media player
        "iina"                     # Modern media player for macOS
        "plex"                     # Media server client
        "netflix"                  # Video streaming
        "youtube-music"            # YouTube Music
        
        # Creative and design tools
        "figma"                    # Design and prototyping
        "canva"                    # Graphic design
        "pixelmator-pro"           # Image editing
        "sketch"                   # UI/UX design
        "procreate"                # Digital art (if available)
        
        # Personal productivity
        "notion"                   # Note-taking and organization
        "obsidian"                 # Knowledge management
        "todoist"                  # Task management
        "fantastical"              # Calendar application
        "bear"                     # Note-taking
        
        # Communication and social
        "discord"                  # Gaming and community chat
        "telegram"                 # Messaging
        "signal"                   # Secure messaging
        "whatsapp"                 # Popular messaging
        "zoom"                     # Video calls with friends/family
        
        # Gaming and entertainment
        "steam"                    # Gaming platform
        "epic-games"               # Alternative gaming platform
        "minecraft"                # Popular game
        "chess-com"                # Online chess
        
        # Browsers and web tools
        "google-chrome"            # Primary browser
        "firefox"                  # Alternative browser
        "brave-browser"            # Privacy-focused browser
        "tor-browser"              # Anonymous browsing
        
        # File management and cloud storage
        "dropbox"                  # Cloud storage
        "google-drive"             # Google cloud storage
        "onedrive"                 # Microsoft cloud storage
        "the-unarchiver"           # Archive extraction
        
        # Development tools (for hobby projects)
        "visual-studio-code"       # Code editor
        "github-desktop"           # Git GUI
        "postman"                  # API testing
        
        # Utilities and system tools
        "raycast"                  # Productivity launcher
        "alfred"                   # Alternative launcher
        "cleanmymac"               # System maintenance
        "appcleaner"               # Application removal
        "bartender-4"              # Menu bar organization
        "magnet"                   # Window management
        
        # Photography and media
        "photos"                   # Photo management
        "lightroom"                # Photo editing
        "handbrake"                # Video transcoding
        "audacity"                 # Audio editing
        
        # Learning and education
        "anki"                     # Flashcard learning
        "duolingo"                 # Language learning
        "khan-academy"             # Educational content
        
        # Finance and personal management
        "mint"                     # Personal finance
        "ynab"                     # Budgeting (You Need A Budget)
        "1password"                # Password manager
        
        # Health and fitness
        "myfitnesspal"             # Fitness tracking
        "headspace"                # Meditation
      ];
      
      # Mac App Store applications for personal use
      masApps = {
        # Apple productivity apps
        "Pages" = 409201541;                    # Document creation
        "Numbers" = 409203825;                  # Spreadsheets
        "Keynote" = 409183694;                  # Presentations
        "GarageBand" = 682658836;               # Music creation
        "iMovie" = 408981434;                   # Video editing
        
        # Entertainment
        "Spotify" = 324684580;                  # Music streaming
        "Netflix" = 1274495053;                 # Video streaming
        "YouTube" = 1274495053;                 # Video platform
        
        # Productivity and utilities
        "1Password 7" = 1333542190;             # Password manager
        "Bear" = 1091189122;                    # Note-taking
        "Todoist" = 585829637;                  # Task management
        "Fantastical" = 975937182;              # Calendar
        "Magnet" = 441258766;                   # Window management
        "The Unarchiver" = 425424353;           # Archive utility
        
        # Creative tools
        "Pixelmator Pro" = 1289583905;          # Image editing
        "Procreate" = 425073498;                # Digital art (iPad app)
        "Canva" = 897446215;                    # Graphic design
        
        # Communication
        "Telegram" = 747648890;                 # Messaging
        "WhatsApp" = 1147396723;                # Popular messaging
        "Discord" = 985746746;                  # Gaming chat
        
        # Learning and education
        "Anki" = 412424040;                     # Flashcards
        "Duolingo" = 570060128;                 # Language learning
        
        # Health and lifestyle
        "MyFitnessPal" = 341232718;             # Fitness tracking
        "Headspace" = 493145008;                # Meditation
        
        # Finance
        "Mint" = 300238147;                     # Personal finance
        "YNAB" = 1010865085;                    # Budgeting
        
        # Gaming
        "Chess.com" = 329218549;                # Online chess
        "Minecraft" = 1142434718;               # Popular game
        
        # System utilities
        "Amphetamine" = 937984704;              # Keep system awake
        "CleanMyMac" = 1339170533;              # System cleaning
        "AppCleaner" = 1013897218;              # App removal
      };
    };
    
    # Personal-optimized system defaults
    system.defaults = {
      # Global system preferences for personal comfort
      NSGlobalDomain = {
        # Comfortable typing settings
        InitialKeyRepeat = 20;     # Slightly faster for personal use
        KeyRepeat = 3;             # Comfortable repeat rate
        
        # Personal preference settings
        AppleShowAllExtensions = true;           # Show file extensions
        ApplePressAndHoldEnabled = true;         # Enable accent characters
        NSNavPanelExpandedStateForSaveMode = true;      # Expanded dialogs
        NSNavPanelExpandedStateForSaveMode2 = true;
        PMPrintingExpandedStateForPrint = true;         # Expanded print dialogs
        PMPrintingExpandedStateForPrint2 = true;
        
        # Personal interface preferences
        AppleInterfaceStyle = "Dark";            # Dark mode for comfort
        AppleShowScrollBars = "WhenScrolling";   # Auto-hide scroll bars
        NSDocumentSaveNewDocumentsToCloud = true;   # Save to cloud by default
        
        # Personal mouse and trackpad
        "com.apple.mouse.tapBehavior" = 1;       # Tap to click
        "com.apple.swipescrolldirection" = true; # Natural scrolling
      };
      
      # Personal dock configuration
      dock = {
        autohide = false;                        # Keep dock visible for easy access
        show-recents = true;                     # Show recent applications
        tilesize = 48;                          # Larger icons for personal comfort
        magnification = true;                    # Visual enhancement
        orientation = "bottom";                  # Standard position
        mineffect = "genie";                    # Fun minimize effect
        launchanim = true;                      # Animated launching
        static-only = false;                    # Allow dynamic dock items
      };
      
      # Personal Finder settings
      finder = {
        AppleShowAllFiles = false;              # Hide system files for simplicity
        ShowPathbar = true;                     # Show path for navigation
        ShowStatusBar = true;                   # Show file information
        FXPreferredViewStyle = "icnv";         # Icon view for visual appeal
        FXDefaultSearchScope = "SCcf";         # Search current folder
        NewWindowTarget = "PfHm";              # New windows to home folder
      };
      
      # Comfortable trackpad settings
      trackpad = {
        Clicking = true;                        # Tap to click
        TrackpadThreeFingerDrag = true;         # Three-finger drag
        TrackpadRightClick = true;              # Two-finger right-click
        TrackpadCornerSecondaryClick = 2;       # Bottom-right corner right-click
      };
      
      # Personal login preferences
      loginwindow = {
        GuestEnabled = false;                   # No guest access needed
        SHOWFULLNAME = false;                   # Show username list
      };
    };
    
    # Personal environment variables
    environment.variables = {
      EDITOR = "nvim";                          # Preferred editor
      BROWSER = "open";                         # Default browser
      PERSONAL_MODE = "true";                   # Flag for personal scripts
      
      # Creative tool settings
      GIMP2_DIRECTORY = "$HOME/.config/GIMP/2.10";  # GIMP configuration
      
      # Development settings for hobby projects
      NODE_ENV = "development";                 # Default Node environment
      PYTHONDONTWRITEBYTECODE = "1";           # Clean Python environment
    };
    
    # Personal activation scripts
    system.activationScripts.extraActivation.text = ''
      echo "Setting up personal MacBook environment..."
      
      # Create personal directory structure
      mkdir -p /Users/user/{Documents,Desktop,Downloads,Pictures,Movies,Music}
      mkdir -p /Users/user/Documents/{Projects,Creative,Learning,Personal}
      mkdir -p /Users/user/Pictures/{Screenshots,Wallpapers,Photos}
      
      # Create hobby development directories
      mkdir -p /Users/user/Development/{personal,learning,experiments}
      
      # Set up configuration directories
      mkdir -p /Users/user/.config/{git,nvim,obsidian}
      
      # Create creative work directories
      mkdir -p /Users/user/Creative/{Design,Art,Music,Video}
      
      # Ensure proper ownership
      chown -R user:staff /Users/user/Documents 2>/dev/null || true
      chown -R user:staff /Users/user/Development 2>/dev/null || true
      chown -R user:staff /Users/user/Creative 2>/dev/null || true
      chown -R user:staff /Users/user/.config 2>/dev/null || true
      
      echo "Personal MacBook setup complete!"
    '';
    
    # Personal security settings (balanced security and convenience)
    security.pam.services.sudo_local = {
      touchIdAuth = true;                       # TouchID for convenience
      reattach = true;                          # Session reattachment
    };
  };
  
  # Personal user preferences
  system.defaults.CustomUserPreferences = {
    # Personal Finder preferences
    "com.apple.finder" = {
      ShowExternalHardDrivesOnDesktop = true;   # Show external drives
      ShowHardDrivesOnDesktop = false;          # Hide internal drive
      ShowMountedServersOnDesktop = false;      # Hide network drives
      ShowRemovableMediaOnDesktop = true;       # Show USB drives
      _FXSortFoldersFirst = true;              # Folders first
      NewWindowTarget = "PfHm";                # Open to home folder
      AppleShowAllExtensions = true;            # Show extensions
      FXEnableExtensionChangeWarning = false;   # Don't warn about extensions
      WarnOnEmptyTrash = false;                # Don't warn when emptying trash
      DisableAllAnimations = false;            # Keep animations for visual appeal
    };
    
    # Personal dock preferences
    "com.apple.dock" = {
      autohide = false;                        # Keep dock visible
      launchanim = true;                       # Animated launching
      show-recents = true;                     # Show recent apps
      show-process-indicators = true;          # Show running indicators
      orientation = "bottom";                  # Bottom orientation
      tilesize = 48;                          # Comfortable size
      magnification = true;                    # Visual enhancement
      largesize = 64;                         # Magnification size
      minimize-to-application = false;         # Minimize to dock
      mineffect = "genie";                    # Fun minimize effect
    };
    
    # Personal Safari preferences
    "com.apple.Safari" = {
      IncludeDevelopMenu = false;              # No need for develop menu
      AutoOpenSafeDownloads = true;           # Convenient for personal use
      ShowFavoritesBar = true;                # Show bookmarks bar
      HomePage = "https://www.google.com";     # Personal homepage preference
    };
    
    # Personal privacy settings (balanced)
    "com.apple.AdLib" = {
      allowApplePersonalizedAdvertising = false;  # Privacy protection
    };
    
    # Personal software update preferences
    "com.apple.SoftwareUpdate" = {
      AutomaticCheckEnabled = true;            # Check for updates
      AutomaticDownload = true;               # Download updates
      CriticalUpdateInstall = true;           # Install security updates
      ConfigDataInstall = true;               # System data updates
    };
    
    # Personal Time Machine settings
    "com.apple.TimeMachine" = {
      DoNotOfferNewDisksForBackup = false;     # Allow backup prompts
      RequiresACPower = false;                # Backup on battery too
    };
    
    # Personal Activity Monitor preferences
    "com.apple.ActivityMonitor" = {
      OpenMainWindow = false;                  # Don't open main window
      IconType = 0;                           # Application icon in dock
      SortColumn = "CPUUsage";                # Sort by CPU usage
      SortDirection = 0;                      # Descending order
    };
    
    # Personal desktop and screen saver
    "com.apple.screensaver" = {
      askForPassword = 1;                     # Require password after screensaver
      askForPasswordDelay = 300;              # 5 minutes delay
    };
    
    # Personal music and media preferences
    "com.apple.Music" = {
      userWantsPlaybackNotifications = true;   # Show music notifications
    };
    
    # Personal Photos preferences
    "com.apple.Photos" = {
      "com.apple.photos.sharedstreams" = true; # Enable shared photo streams
    };
  };
}