{ config, lib, pkgs, ... }:
let
  cfg = config.modules.darwin.defaults;
in {
  options.modules.darwin.defaults = {
    enable = lib.mkEnableOption "macOS defaults and preferences";
    
    # Global NSGlobalDomain settings
    global = {
      showAllExtensions = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Show all file extensions";
      };
      
      showScrollBars = lib.mkOption {
        type = lib.types.enum [ "Always" "Automatic" "WhenScrolling" ];
        default = "Always";
        description = "When to show scroll bars";
      };
      
      interfaceStyle = lib.mkOption {
        type = lib.types.enum [ "Light" "Dark" ];
        default = "Dark";
        description = "System interface style";
      };
      
      hideMenuBar = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Hide the menu bar";
      };
      
      keyRepeat = lib.mkOption {
        type = lib.types.int;
        default = 2;
        description = "Key repeat rate";
      };
      
      initialKeyRepeat = lib.mkOption {
        type = lib.types.int;
        default = 25;
        description = "Initial key repeat delay";
      };
      
      enablePressAndHold = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable press and hold for accented characters";
      };
      
      naturalScrolling = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable natural scrolling direction";
      };
      
      tapToClick = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable tap to click on trackpad";
      };
    };
    
    # Dock configuration
    dock = {
      autohide = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Automatically hide the dock";
      };
      
      tilesize = lib.mkOption {
        type = lib.types.int;
        default = 36;
        description = "Size of dock tiles";
      };
      
      orientation = lib.mkOption {
        type = lib.types.enum [ "bottom" "left" "right" ];
        default = "bottom";
        description = "Dock orientation";
      };
      
      showRecents = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Show recent applications in dock";
      };
      
      launchAnimation = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable launch animation";
      };
      
      minimizeToApplication = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Minimize windows into application icon";
      };
      
      persistentApps = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "List of applications to keep in dock";
      };
    };
    
    # Finder configuration
    finder = {
      preferredViewStyle = lib.mkOption {
        type = lib.types.enum [ "icnv" "Nlsv" "clmv" "Flwv" ];
        default = "Nlsv";
        description = "Preferred view style (icon, list, column, gallery)";
      };
      
      showExternalHardDrives = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Show external hard drives on desktop";
      };
      
      showHardDrives = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Show hard drives on desktop";
      };
      
      showRemovableMedia = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Show removable media on desktop";
      };
      
      sortFoldersFirst = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Sort folders first in Finder";
      };
      
      defaultSearchScope = lib.mkOption {
        type = lib.types.str;
        default = "SCcf";
        description = "Default search scope (current folder)";
      };
      
      showStatusBar = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Show status bar in Finder";
      };
      
      showPathBar = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Show path bar in Finder";
      };
    };
    
    # Activity Monitor
    activityMonitor = {
      openMainWindow = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Open main window when launching Activity Monitor";
      };
      
      iconType = lib.mkOption {
        type = lib.types.int;
        default = 5;
        description = "Activity Monitor dock icon type";
      };
      
      sortColumn = lib.mkOption {
        type = lib.types.str;
        default = "CPUUsage";
        description = "Default sort column";
      };
    };
    
    # Custom preferences for specific applications
    customPreferences = lib.mkOption {
      type = lib.types.attrs;
      default = {};
      description = "Custom application preferences";
    };
    
    extraConfig = lib.mkOption {
      type = lib.types.attrs;
      default = {};
      description = "Additional defaults configuration";
    };
  };
  
  config = lib.mkIf cfg.enable {
    system.defaults = {
      # Global domain settings
      NSGlobalDomain = {
        AppleShowAllExtensions = cfg.global.showAllExtensions;
        AppleShowScrollBars = cfg.global.showScrollBars;
        NSUseAnimatedFocusRing = false;
        NSNavPanelExpandedStateForSaveMode = true;
        NSNavPanelExpandedStateForSaveMode2 = true;
        PMPrintingExpandedStateForPrint = true;
        PMPrintingExpandedStateForPrint2 = true;
        NSDocumentSaveNewDocumentsToCloud = false;
        ApplePressAndHoldEnabled = cfg.global.enablePressAndHold;
        InitialKeyRepeat = cfg.global.initialKeyRepeat;
        KeyRepeat = cfg.global.keyRepeat;
        "com.apple.mouse.tapBehavior" = if cfg.global.tapToClick then 1 else 0;
        NSWindowShouldDragOnGesture = true;
        NSAutomaticSpellingCorrectionEnabled = false;
        AppleInterfaceStyle = cfg.global.interfaceStyle;
        _HIHideMenuBar = cfg.global.hideMenuBar;
        AppleShowAllFiles = true;
        AppleFontSmoothing = 2;
        "com.apple.swipescrolldirection" = cfg.global.naturalScrolling;
      };
      
      # Finder settings
      finder = {
        FXPreferredViewStyle = cfg.finder.preferredViewStyle;
      };
      
      # Dock settings
      dock = {
        persistent-apps = cfg.dock.persistentApps;
      };
    };
    
    # Custom user preferences
    system.defaults.CustomUserPreferences = lib.mkMerge [
      {
        "com.apple.finder" = {
          ShowExternalHardDrivesOnDesktop = cfg.finder.showExternalHardDrives;
          ShowHardDrivesOnDesktop = cfg.finder.showHardDrives;
          ShowMountedServersOnDesktop = false;
          ShowRemovableMediaOnDesktop = cfg.finder.showRemovableMedia;
          _FXSortFoldersFirst = cfg.finder.sortFoldersFirst;
          FXDefaultSearchScope = cfg.finder.defaultSearchScope;
          DisableAllAnimations = true;
          NewWindowTarget = "PfDe";
          NewWindowTargetPath = "file://$\{HOME\}/Desktop/";
          AppleShowAllExtensions = cfg.global.showAllExtensions;
          FXEnableExtensionChangeWarning = false;
          ShowStatusBar = cfg.finder.showStatusBar;
          ShowPathbar = cfg.finder.showPathBar;
          WarnOnEmptyTrash = false;
        };
        
        "com.apple.desktopservices" = {
          DSDontWriteNetworkStores = true;
          DSDontWriteUSBStores = true;
        };
        
        "com.apple.dock" = {
          autohide = cfg.dock.autohide;
          launchanim = cfg.dock.launchAnimation;
          static-only = false;
          show-recents = cfg.dock.showRecents;
          show-process-indicators = true;
          orientation = cfg.dock.orientation;
          tilesize = cfg.dock.tilesize;
          minimize-to-application = cfg.dock.minimizeToApplication;
          mineffect = "scale";
          enable-window-tool = false;
        };
        
        "com.apple.ActivityMonitor" = {
          OpenMainWindow = cfg.activityMonitor.openMainWindow;
          IconType = cfg.activityMonitor.iconType;
          SortColumn = cfg.activityMonitor.sortColumn;
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
      }
      
      cfg.customPreferences
    ];
  } // cfg.extraConfig;
}