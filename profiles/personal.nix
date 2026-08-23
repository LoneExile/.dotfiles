{
  config,
  lib,
  ...
}: {
  # Personal-use loadout.
  #
  # Homebrew app selection and the macOS UI preferences (Dark mode, dock
  # layout, finder, Safari, etc.) used on personal MacBooks.

  environment.variables = {
    EDITOR = lib.mkForce "nvim";
  };

  homebrew = {
    enable = true;
    onActivation = {
      cleanup = "zap";
      # Do not auto-update taps here. Taps are pinned via nix-homebrew flake inputs
      # and updated with `nix flake update`. Running `brew update` can cause
      # permission errors on the read-only tap checkouts from the nix store.
      autoUpdate = false;
      # Don't run `brew upgrade` on every activation either: it hits the network
      # and rebuilds/downloads outdated formulae, slowing each switch. Consistent
      # with autoUpdate=false above — upgrades are explicit. Run `brew upgrade`
      # manually (or `just brew-upgrade`) when you actually want them.
      upgrade = false;
    };
    # Disable Homebrew's own auto-update. Updates are driven by the flake lock.
    global.autoUpdate = false;

    taps = builtins.attrNames config.nix-homebrew.taps;

    brews = [
      "mas"
      "displayplacer"
      "watch"
      "rover"
      "doctl"
      "wireguard-tools"
      # "huggingface-cli"
      "libpq"
      "postgresql@18"
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
      "rsync"
      "crane"
      "coreutils"
      "mactop"
      "glog"
      "hunk" # diff viewer for agentic coders

      # Rime/Squirrel build deps
      "cmake"
      "boost"
      "leveldb"
      "marisa"
      "yaml-cpp"
      "opencc"
      "googletest"
      "pkgconf"
      "ninja"
      # "tuxedo"
      "openbao"
      "opentofu"
      "harper" # grammar checker

      # Terminal recording / demo capture
      "vhs" # terminal recorder (pulls in ttyd)
      "asciinema" # terminal session recorder
      "agg" # asciinema-to-gif renderer

      "lightpanda-io/browser/lightpanda"
      "kubelogin"
      "gdu"
      "vale"

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
      # "spotify"
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
      # "figma"
      "tradingview"
      "gimp"
      "logseq"
      "dbeaver-community"
      "claude"
      "github"
      "wifiman"
      "zoom"
      # "gcloud-cli"
      "mitmproxy"
      "xykong/tap/flux-markdown"
      "thaw" # menu bar manager
      # "siyuan"
      "shottr"
      "squirrel-app"
      "bruno"
      # "android-studio"
      "rustdesk"
      "zennotes/tap/zennotes"
      "BarutSRB/tap/omniwm"
      "handy"
      "kgarner7/feishin/feishin"
      "abue-ammar/tinycast/tinycast"
      "cursor"
      "cursor-cli"
      "vorssaint"
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

  system.activationScripts.preActivation.text = ''
    # `homebrew.onActivation.cleanup = "zap"` untaps every tap absent from the
    # Brewfile, and brew runs as ${config.homebrew.user}. A tap tree that ended
    # up root-owned (a root-context `brew tap`, or a tap materialised while brew
    # ran as root) therefore cannot be untapped, and the whole activation dies:
    #   Untapping <owner>/<tap>...
    #   Error: Permission denied @ apply2files - .../Formula/<name>.rb
    # preActivation runs as root, so hand undeclared tap trees back to the brew
    # user before zap reaches them. Scoped to *undeclared* taps: the declared
    # ones are never zapped, and walking homebrew-core on every switch is slow.
    # Idempotent.
    declaredTaps=" ${lib.concatStringsSep " " (builtins.attrNames config.nix-homebrew.taps)} "
    for tapPath in ${config.homebrew.prefix}/Library/Taps/*/*; do
      [ -d "$tapPath" ] || continue
      tapName="$(basename "$(dirname "$tapPath")")/$(basename "$tapPath")"
      case "$declaredTaps" in
        *" $tapName "*) continue ;;
      esac
      if [ -n "$(find "$tapPath" ! -user ${config.homebrew.user} -print -quit)" ]; then
        echo >&2 "Reclaiming undeclared tap $tapName for ${config.homebrew.user} so zap-cleanup can untap it..."
        chown -R ${config.homebrew.user} "$tapPath" || true
      fi
    done
  '';

  # Keep sudo credentials alive through the whole `just switch` run.
  # The activation runs as root, but Homebrew's bundle step drops back to
  # the regular user (`sudo --user=lex … brew bundle`), so any cask that
  # needs root (pkg installer, launchctl removal)
  # re-runs `sudo` as that user. The nix build between the initial
  # `sudo -v` and that point exceeds sudo's default 5-minute timeout,
  # which is why a second password prompt appears mid-activation.
  # 60 minutes covers any switch; still bounded, so an unlocked session
  # does not stay privileged indefinitely.
  security.sudo.extraConfig = ''
    Defaults:${config.homebrew.user} timestamp_timeout=60
  '';

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
