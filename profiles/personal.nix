{
  config,
  lib,
  pkgs,
  inputs,
  unstablePkgs,
  ...
}: {
  # Personal-use loadout.
  #
  # Homebrew app selection, AeroSpace window manager, and the macOS UI
  # preferences (Dark mode, dock layout, finder, Safari, etc.) used on
  # personal MacBooks.

  environment.variables = {
    EDITOR = lib.mkForce "nvim";
  };

  environment.systemPackages = with pkgs; [
    # AeroSpace with sticky-windows patch (LoneExile/AeroSpace fork).
    # Metadata published by CI to the nix-release-meta branch; fetchurl
    # over the raw .zip bytes for deterministic hashing.
    (unstablePkgs.aerospace.overrideAttrs (old: let
      meta = import "${inputs.aerospace-sticky-meta}/release.nix";
    in {
      version = meta.version;
      src = unstablePkgs.fetchurl {
        url = meta.url;
        sha256 = meta.sha256;
      };
      nativeBuildInputs = (old.nativeBuildInputs or []) ++ [unstablePkgs.unzip];
      dontUnpack = true;
      installPhase = ''
        runHook preInstall
        unzip -q "$src"
        cd AeroSpace-v*/
        mkdir -p $out/Applications $out/share
        mv AeroSpace.app $out/Applications
        cp -R bin $out
        runHook postInstall
      '';
    }))
  ];

  homebrew = {
    enable = true;
    onActivation = {
      cleanup = "zap";
      autoUpdate = true;
      upgrade = true;
    };
    global.autoUpdate = true;

    taps = builtins.attrNames config.nix-homebrew.taps;

    brews = [
      "mas"
      "displayplacer"
      "watch"
      "rover"
      "doctl"
      "wireguard-tools"
      "huggingface-cli"
      "libpq"
      "postgresql"
      "git-lfs"
      "k3sup"
      "tokei"
      "skaffold"
      "pango"
      "gdk-pixbuf"
      "libffi"
      "terragrunt"
      "mongosh"
      "protobuf"
      "protoc-gen-go"
      "protoc-gen-go-grpc"
      "telepresenceio/telepresence/telepresence-oss"
      "AlexsJones/llmfit/llmfit"
      "cdrtools"
      "webp"
      "poppler"
      "strongswan"
      "redis"
      "tea"
      "krew"
      "argocd"
      "jolehuit/tap/clother"
      "rsync"
      "crane"
      "coreutils"
      # "powershell/tap/powershell" # disabled: tap not declared as flake input; nix-homebrew can't manage it.
      # "steveyegge/beads/bd"
      # { name = "mole"; args = ["HEAD"]; }
    ];

    casks = [
      "audacity"
      "kdenlive"
      "discord"
      "firefox"
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
      # "nordvpn"  # cask URL stale/blocked (NordVPN-OpenVPN/10.0.3 404s); install manually if needed
      # "mtmr"     # cask URL stale (mtmr.app DMG); install manually if needed
      "raspberry-pi-imager"
      "brave-browser"
      "trex"
      "postman"
      "telegram"
      "anki"
      "mongodb-compass"
      "openvpn-connect"
      "cloudflare-warp"
      "vnc-viewer"
      "visual-studio-code"
      "cap"
      "figma"
      "tradingview"
      "gimp"
      "logseq"
      "dbeaver-community"
      "claude"
      "github"
      "wifiman"
      "zoom"
      "gcloud-cli"
      "mitmproxy"
      "flux-markdown"
      "thaw" # menu bar manager
    ];

    # masApps removed: brew bundle re-prompts on every switch because
    # `mas list` can't see installed MAS apps on macOS 26. Install these
    # from the App Store manually:
    #   Bitwarden (1352778147), Keynote (409183694), Numbers (409203825),
    #   Pages (409201541), Line (539883307), Amphetamine (937984704),
    #   Dropover (1355679052), Runcat (1429033973), WhatsApp (310633997),
    #   WireGuard (1451685025), Windows App (1295203466), WeChat (836500024)

    # masApps = {
    #   "Bitwarden" = 1352778147;
    #   "Keynote" = 409183694;
    #   "Numbers" = 409203825;
    #   "Pages" = 409201541;
    #   "Line" = 539883307;
    #   "Amphetamine" = 937984704;
    #   "Dropover" = 1355679052;
    #   "Runcat" = 1429033973;
    #   "WhatsApp" = 310633997;
    #   # "Webull" = 1334590352;
    #   "WireGuard" = 1451685025;
    #   "Windows App" = 1295203466;
    #   "WeChat" = 836500024;
    #   # "Curiota" = 1038088531;
    # };
  };

  # Personal macOS preferences
  system.defaults = {
    NSGlobalDomain = {
      AppleInterfaceStyle = "Dark";
      AppleShowScrollBars = "Always";
      NSNavPanelExpandedStateForSaveMode = true;
      NSNavPanelExpandedStateForSaveMode2 = true;
      PMPrintingExpandedStateForPrint = true;
      PMPrintingExpandedStateForPrint2 = true;
      NSDocumentSaveNewDocumentsToCloud = false;
      _HIHideMenuBar = false;
    };

    LaunchServices.LSQuarantine = false;
    loginwindow.GuestEnabled = false;
    finder.FXPreferredViewStyle = "Nlsv";

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
        magnification = true;
        largesize = 34;
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
