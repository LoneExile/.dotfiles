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
  # Host-specific configuration for "le"
  # This file contains customizations specific to this machine

  imports = [
    ../common/default.nix
    # ../common/profiles/personal.nix # Select personal profile for this host
  ];

  # Host identification
  networking.hostName = "le";
  networking.computerName = "le";

  # User configuration
  users.users.le = {
    home = "/Users/le";
    description = "Apinant U-suwantim";
  };

  # Set primary user for system-wide activation
  system.primaryUser = "le";

  # Host-specific overrides and customizations
  # Personal profile is enabled through imports

  # Host-specific system packages
  environment.systemPackages = with pkgs; [
    # Unstable packages
    unstablePkgs.yt-dlp
    unstablePkgs.get_iplayer
    unstablePkgs.colmena
    unstablePkgs.aerospace
    unstablePkgs.colima

    unstablePkgs.comma
    unstablePkgs.hcloud
    unstablePkgs.just
    unstablePkgs.lima
    unstablePkgs.docker
    unstablePkgs.lazydocker
    unstablePkgs.wezterm
    unstablePkgs.k9s
    unstablePkgs.syncthing-macos
    unstablePkgs.talosctl
    unstablePkgs.yq-go
    unstablePkgs.fluxcd
    unstablePkgs.kubernetes-helm
    unstablePkgs.yazi
    unstablePkgs.aws-vault
    unstablePkgs.awscli2
    unstablePkgs.kubevirt
    unstablePkgs.statix # Nix linter
    unstablePkgs.deadnix # Dead code detection
    unstablePkgs.alejandra
    unstablePkgs.kubectl
    unstablePkgs.btop
    # unstablePkgs.logseq
    unstablePkgs.skopeo # For copying container images
    unstablePkgs.lsof
    unstablePkgs.bandwhich
    unstablePkgs.qbittorrent-enhanced
    unstablePkgs.dust
    # unstablePkgs.flameshot
    unstablePkgs.harbor-cli
    unstablePkgs.gettext
    unstablePkgs.parallel
    unstablePkgs.gh
    unstablePkgs.freerdp
    unstablePkgs.sqlcmd
    unstablePkgs.sshpass
    unstablePkgs.jellyfin-ffmpeg
    unstablePkgs.poetry

    # Stable CLI tools
    packer
    obsidian
  ];

  # Host-specific fonts
  fonts.packages = [
    pkgs.nerd-fonts.fira-code
    pkgs.nerd-fonts.fira-mono
    pkgs.nerd-fonts.hack
    pkgs.nerd-fonts.jetbrains-mono
  ];

  # Host-specific Nix registry
  nix.registry = {
    n.to = {
      type = "path";
      path = inputs.nixpkgs;
    };
    u.to = {
      type = "path";
      path = inputs.nixpkgs-unstable;
    };
  };

  # Host-specific Homebrew configuration
  homebrew = {
    enable = true;
    onActivation = {
      cleanup = "zap";
      autoUpdate = true;
      upgrade = true;
    };
    global.autoUpdate = true;

    brews = [
      # "bitwarden-cli"
      "displayplacer"
      # "gh"
      "watch"
      "rover"
      "doctl"
      "wireguard-tools"
      # "git-cola"
      "huggingface-cli"
      "libpq"
      "postgresql"
      "git-lfs"
      "k3sup"
      "tw93/tap/mole"
      "pango"
      "gdk-pixbuf"
      "libffi"
      "terragrunt"
    ];

    taps = builtins.attrNames config.nix-homebrew.taps;

    casks = [
      "audacity" # Audio editing software
      "kdenlive" # Video editing software
      "discord"
      "firefox"
      # "flameshot"
      "font-fira-code"
      "font-fira-code-nerd-font"
      "font-fira-mono-for-powerline"
      "font-hack-nerd-font"
      "font-jetbrains-mono-nerd-font"
      "font-meslo-lg-nerd-font"
      "google-chrome"
      "iina"
      "obs"
      "raycast"
      "signal"
      "slack"
      "spotify"
      "tailscale-app"
      "nordvpn"
      "mtmr"
      "raspberry-pi-imager"
      "brave-browser"
      "trex"
      "numi"
      "postman"
      "telegram"
      "anki"
      "mongodb-compass"
      "openvpn-connect"
      "cloudflare-warp"
      "kiro"
      "vnc-viewer"
      "visual-studio-code"
      "cap"
      "figma"
      # "framer"
      # "webull"
      "tradingview"
      "gimp"
      "logseq"
      "dbeaver-community"
      "claude"
      # "ksnip"
      "github"
      "tigervnc-viewer"
      "firefox"
    ];

    masApps = {
      "Bitwarden" = 1352778147;
      "Keynote" = 409183694;
      "Numbers" = 409203825;
      "Pages" = 409201541;
      "Line" = 539883307;
      "Amphetamine" = 937984704;
      "Dropover" = 1355679052;
      "Runcat" = 1429033973;
      "WhatsApp" = 310633997;
      # "Webull" = 1334590352;
      "WireGuard" = 1451685025;
      "Windows App" = 1295203466;
    };
  };
  # Keyboard
  system.keyboard.enableKeyMapping = true;
  system.keyboard.remapCapsLockToEscape = false;

  # Add ability to used TouchID for sudo authentication
  security.pam.services.sudo_local.touchIdAuth = true;
  security.pam.services.sudo_local.reattach = true;

  # Host-specific system activation scripts
  system.activationScripts.extraActivation.text = ''
    # Set display to maximum resolution using displayplacer
    echo "Setting display to maximum resolution..."
    if command -v displayplacer >/dev/null 2>&1; then
      # Set MacBook built-in screen to maximum resolution (mode 13: 2560x1600)
      displayplacer "id:1 mode:13 degree:0" 2>/dev/null || {
        echo "Warning: Failed to set display resolution with contextual ID, this is normal on first run"
      }
    else
      echo "displayplacer not found, skipping display configuration"
    fi
  '';

  # Host-specific macOS defaults (overriding profile defaults)
  system.defaults = {
    NSGlobalDomain = {
      AppleShowAllExtensions = true;
      AppleShowScrollBars = "Always";
      NSUseAnimatedFocusRing = false;
      NSNavPanelExpandedStateForSaveMode = true;
      NSNavPanelExpandedStateForSaveMode2 = true;
      PMPrintingExpandedStateForPrint = true;
      PMPrintingExpandedStateForPrint2 = true;
      NSDocumentSaveNewDocumentsToCloud = false;
      ApplePressAndHoldEnabled = false;
      InitialKeyRepeat = 25;
      KeyRepeat = 2;
      "com.apple.mouse.tapBehavior" = 1;
      NSWindowShouldDragOnGesture = true;
      NSAutomaticSpellingCorrectionEnabled = false;
      AppleInterfaceStyle = "Dark";
      _HIHideMenuBar = false;
      AppleShowAllFiles = true;
      AppleFontSmoothing = 2;
      "com.apple.swipescrolldirection" = false;
    };

    LaunchServices.LSQuarantine = false;
    loginwindow.GuestEnabled = false;
    finder.FXPreferredViewStyle = "Nlsv";

    # Custom user preferences specific to this host
    CustomUserPreferences = {
      "com.apple.finder" = {
        ShowExternalHardDrivesOnDesktop = true;
        ShowHardDrivesOnDesktop = false;
        ShowMountedServersOnDesktop = false;
        ShowRemovableMediaOnDesktop = true;
        _FXSortFoldersFirst = true;
        FXDefaultSearchScope = "SCcf";
        DisableAllAnimations = true;
        NewWindowTarget = "PfDe";
        NewWindowTargetPath = "file://${config.users.users.le.home}/Desktop/";
        AppleShowAllExtensions = true;
        FXEnableExtensionChangeWarning = false;
        ShowStatusBar = true;
        ShowPathbar = true;
        WarnOnEmptyTrash = false;
      };

      "com.apple.desktopservices" = {
        DSDontWriteNetworkStores = true;
        DSDontWriteUSBStores = true;
      };

      "com.apple.dock" = {
        autohide = true;
        launchanim = false;
        static-only = false;
        show-recents = false;
        show-process-indicators = true;
        orientation = "bottom";
        tilesize = 26;
        magnification = true; # Enable hover zoom/magnification
        largesize = 34; # Magnified tile size when hovering (16-128)
        minimize-to-application = true;
        mineffect = "scale";
        enable-window-tool = false;
      };

      "com.apple.ActivityMonitor" = {
        OpenMainWindow = true;
        IconType = 5;
        SortColumn = "CPUUsage";
        SortDirection = 0;
      };

      "com.apple.Safari" = {
        UniversalSearchEnabled = false;
        SuppressSearchSuggestions = true;
      };

      "com.apple.AdLib" = {
        allowApplePersonalizedAdvertising = false;
      };

      "com.apple.SoftwareUpdate" = {
        AutomaticCheckEnabled = true;
        ScheduleFrequency = 1;
        AutomaticDownload = 1;
        CriticalUpdateInstall = 1;
      };

      "com.apple.TimeMachine".DoNotOfferNewDisksForBackup = true;
      "com.apple.ImageCapture".disableHotPlug = true;
      "com.apple.commerce".AutoUpdate = true;
      "com.googlecode.iterm2".PromptOnQuit = false;

      "com.google.Chrome" = {
        AppleEnableSwipeNavigateWithScrolls = true;
        DisablePrintPreview = true;
        PMPrintingExpandedStateForPrint2 = true;
      };
    };
  };
}
