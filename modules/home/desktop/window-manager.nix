{ config, lib, pkgs, ... }:
let
  cfg = config.modules.home.desktop.windowManager;
  
  # Default Aerospace configuration
  defaultAerospaceConfig = ''
    # Start AeroSpace at login
    start-at-login = true

    # Normalizations
    enable-normalization-flatten-containers = true
    enable-normalization-opposite-orientation-for-nested-containers = true

    # Layouts
    accordion-padding = 30
    default-root-container-layout = 'tiles'
    default-root-container-orientation = 'auto'

    # Mouse follows focus when focused monitor changes
    on-focused-monitor-changed = ['move-mouse monitor-lazy-center']

    # Don't hide applications automatically
    automatically-unhide-macos-hidden-apps = false

    # Key mapping
    [key-mapping]
        preset = 'qwerty'

    # Gaps between windows
    [gaps]
        inner.horizontal = 10
        inner.vertical =   10
        outer.left =       10
        outer.bottom =     10
        outer.top =        10
        outer.right =      10

    # Main binding mode
    [mode.main.binding]
        # Layout commands
        alt-slash = 'layout tiles horizontal vertical'
        alt-comma = 'layout accordion horizontal vertical'

        # Focus commands
        alt-h = 'focus left'
        alt-j = 'focus down'
        alt-k = 'focus up'
        alt-l = 'focus right'

        # Move commands
        alt-shift-h = 'move left'
        alt-shift-j = 'move down'
        alt-shift-k = 'move up'
        alt-shift-l = 'move right'

        # Resize commands
        alt-minus = 'resize smart -50'
        alt-equal = 'resize smart +50'

        # Workspace commands
        alt-1 = 'workspace 1'
        alt-2 = 'workspace 2'
        alt-3 = 'workspace 3'
        alt-4 = 'workspace 4'
        alt-5 = 'workspace 5'
        alt-6 = 'workspace 6'
        alt-7 = 'workspace 7'
        alt-8 = 'workspace 8'
        alt-9 = 'workspace 9'

        # Move to workspace commands
        alt-shift-1 = ['move-node-to-workspace 1', 'workspace 1']
        alt-shift-2 = ['move-node-to-workspace 2', 'workspace 2']
        alt-shift-3 = ['move-node-to-workspace 3', 'workspace 3']
        alt-shift-4 = ['move-node-to-workspace 4', 'workspace 4']
        alt-shift-5 = ['move-node-to-workspace 5', 'workspace 5']
        alt-shift-6 = ['move-node-to-workspace 6', 'workspace 6']
        alt-shift-7 = ['move-node-to-workspace 7', 'workspace 7']
        alt-shift-8 = ['move-node-to-workspace 8', 'workspace 8']
        alt-shift-9 = ['move-node-to-workspace 9', 'workspace 9']

        # Workspace navigation
        alt-tab = 'workspace-back-and-forth'
        alt-shift-tab = 'move-workspace-to-monitor --wrap-around next'

        # Service mode
        alt-shift-semicolon = 'mode service'

    # Service binding mode
    [mode.service.binding]
        esc = ['reload-config', 'mode main']
        r = ['flatten-workspace-tree', 'mode main']
        f = ['layout floating tiling', 'mode main']
        backspace = ['close-all-windows-but-current', 'mode main']

        # Stack windows
        h = ['join-with left', 'mode main']
        j = ['join-with down', 'mode main']
        k = ['join-with up', 'mode main']
        l = ['join-with right', 'mode main']
        
        # Alternative stacking
        alt-shift-h = ['join-with left', 'mode main']
        alt-shift-j = ['join-with down', 'mode main']
        alt-shift-k = ['join-with up', 'mode main']
        alt-shift-l = ['join-with right', 'mode main']

        # Volume controls
        down = 'volume down'
        up = 'volume up'
        shift-down = ['volume set 0', 'mode main']
  '';
in {
  options.modules.home.desktop.windowManager = {
    enable = lib.mkEnableOption "Window manager configuration";
    
    aerospace = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Aerospace window manager";
      };

      startAtLogin = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Start Aerospace at login";
      };

      gaps = {
        inner = lib.mkOption {
          type = lib.types.int;
          default = 10;
          description = "Inner gaps between windows";
        };

        outer = lib.mkOption {
          type = lib.types.int;
          default = 10;
          description = "Outer gaps from screen edges";
        };
      };

      defaultLayout = lib.mkOption {
        type = lib.types.enum [ "tiles" "accordion" ];
        default = "tiles";
        description = "Default root container layout";
      };

      extraConfig = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = "Extra Aerospace configuration";
      };
    };

    yabai = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Yabai window manager";
      };

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.yabai;
        description = "Yabai package to use";
      };
    };

    skhd = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable skhd hotkey daemon";
      };

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.skhd;
        description = "skhd package to use";
      };
    };
  };
  
  config = lib.mkIf cfg.enable {
    # Aerospace configuration
    home.file.".config/aerospace/aerospace.toml" = lib.mkIf cfg.aerospace.enable {
      text = ''
        # Start AeroSpace at login
        start-at-login = ${lib.boolToString cfg.aerospace.startAtLogin}

        # Normalizations
        enable-normalization-flatten-containers = true
        enable-normalization-opposite-orientation-for-nested-containers = true

        # Layouts
        accordion-padding = 30
        default-root-container-layout = '${cfg.aerospace.defaultLayout}'
        default-root-container-orientation = 'auto'

        # Mouse follows focus when focused monitor changes
        on-focused-monitor-changed = ['move-mouse monitor-lazy-center']

        # Don't hide applications automatically
        automatically-unhide-macos-hidden-apps = false

        # Key mapping
        [key-mapping]
            preset = 'qwerty'

        # Gaps between windows
        [gaps]
            inner.horizontal = ${toString cfg.aerospace.gaps.inner}
            inner.vertical =   ${toString cfg.aerospace.gaps.inner}
            outer.left =       ${toString cfg.aerospace.gaps.outer}
            outer.bottom =     ${toString cfg.aerospace.gaps.outer}
            outer.top =        ${toString cfg.aerospace.gaps.outer}
            outer.right =      ${toString cfg.aerospace.gaps.outer}

        # Main binding mode
        [mode.main.binding]
            # Layout commands
            alt-slash = 'layout tiles horizontal vertical'
            alt-comma = 'layout accordion horizontal vertical'

            # Focus commands
            alt-h = 'focus left'
            alt-j = 'focus down'
            alt-k = 'focus up'
            alt-l = 'focus right'

            # Move commands
            alt-shift-h = 'move left'
            alt-shift-j = 'move down'
            alt-shift-k = 'move up'
            alt-shift-l = 'move right'

            # Resize commands
            alt-minus = 'resize smart -50'
            alt-equal = 'resize smart +50'

            # Workspace commands
            alt-1 = 'workspace 1'
            alt-2 = 'workspace 2'
            alt-3 = 'workspace 3'
            alt-4 = 'workspace 4'
            alt-5 = 'workspace 5'
            alt-6 = 'workspace 6'
            alt-7 = 'workspace 7'
            alt-8 = 'workspace 8'
            alt-9 = 'workspace 9'

            # Move to workspace commands
            alt-shift-1 = ['move-node-to-workspace 1', 'workspace 1']
            alt-shift-2 = ['move-node-to-workspace 2', 'workspace 2']
            alt-shift-3 = ['move-node-to-workspace 3', 'workspace 3']
            alt-shift-4 = ['move-node-to-workspace 4', 'workspace 4']
            alt-shift-5 = ['move-node-to-workspace 5', 'workspace 5']
            alt-shift-6 = ['move-node-to-workspace 6', 'workspace 6']
            alt-shift-7 = ['move-node-to-workspace 7', 'workspace 7']
            alt-shift-8 = ['move-node-to-workspace 8', 'workspace 8']
            alt-shift-9 = ['move-node-to-workspace 9', 'workspace 9']

            # Workspace navigation
            alt-tab = 'workspace-back-and-forth'
            alt-shift-tab = 'move-workspace-to-monitor --wrap-around next'

            # Service mode
            alt-shift-semicolon = 'mode service'

        # Service binding mode
        [mode.service.binding]
            esc = ['reload-config', 'mode main']
            r = ['flatten-workspace-tree', 'mode main']
            f = ['layout floating tiling', 'mode main']
            backspace = ['close-all-windows-but-current', 'mode main']

            # Stack windows
            h = ['join-with left', 'mode main']
            j = ['join-with down', 'mode main']
            k = ['join-with up', 'mode main']
            l = ['join-with right', 'mode main']
            
            # Alternative stacking
            alt-shift-h = ['join-with left', 'mode main']
            alt-shift-j = ['join-with down', 'mode main']
            alt-shift-k = ['join-with up', 'mode main']
            alt-shift-l = ['join-with right', 'mode main']

            # Volume controls
            down = 'volume down'
            up = 'volume up'
            shift-down = ['volume set 0', 'mode main']

        ${cfg.aerospace.extraConfig}
      '';
    };

    # Yabai configuration
    services.yabai = lib.mkIf cfg.yabai.enable {
      enable = true;
      package = cfg.yabai.package;
      
      config = {
        layout = "bsp";
        auto_balance = "off";
        split_ratio = "0.50";
        window_border = "on";
        window_border_width = 2;
        window_gap = 10;
        top_padding = 10;
        bottom_padding = 10;
        left_padding = 10;
        right_padding = 10;
      };
    };

    # skhd configuration
    services.skhd = lib.mkIf cfg.skhd.enable {
      enable = true;
      package = cfg.skhd.package;
      
      skhdConfig = ''
        # Focus window
        alt - h : yabai -m window --focus west
        alt - j : yabai -m window --focus south
        alt - k : yabai -m window --focus north
        alt - l : yabai -m window --focus east

        # Move window
        shift + alt - h : yabai -m window --warp west
        shift + alt - j : yabai -m window --warp south
        shift + alt - k : yabai -m window --warp north
        shift + alt - l : yabai -m window --warp east

        # Resize windows
        shift + alt - a : yabai -m window --resize left:-20:0; yabai -m window --resize right:-20:0
        shift + alt - s : yabai -m window --resize bottom:0:20; yabai -m window --resize top:0:20
        shift + alt - w : yabai -m window --resize top:0:-20; yabai -m window --resize bottom:0:-20
        shift + alt - d : yabai -m window --resize right:20:0; yabai -m window --resize left:20:0

        # Focus space
        alt - 1 : yabai -m space --focus 1
        alt - 2 : yabai -m space --focus 2
        alt - 3 : yabai -m space --focus 3
        alt - 4 : yabai -m space --focus 4
        alt - 5 : yabai -m space --focus 5

        # Move window to space
        shift + alt - 1 : yabai -m window --space 1; yabai -m space --focus 1
        shift + alt - 2 : yabai -m window --space 2; yabai -m space --focus 2
        shift + alt - 3 : yabai -m window --space 3; yabai -m space --focus 3
        shift + alt - 4 : yabai -m window --space 4; yabai -m space --focus 4
        shift + alt - 5 : yabai -m window --space 5; yabai -m space --focus 5

        # Toggle window split type
        alt - e : yabai -m window --toggle split

        # Float / Unfloat window
        alt - t : yabai -m window --toggle float; yabai -m window --grid 4:4:1:1:2:2

        # Restart yabai
        shift + alt - r : yabai --restart-service
      '';
    };

    # Add window manager packages to home.packages if needed
    home.packages = lib.mkMerge [
      (lib.mkIf cfg.yabai.enable [ cfg.yabai.package ])
      (lib.mkIf cfg.skhd.enable [ cfg.skhd.package ])
    ];
  };
}