{ config, lib, pkgs, ... }:
let
  cfg = config.modules.home.desktop.terminal;
  
  # WezTerm configuration
  weztermConfig = ''
    -- Pull in the wezterm API
    local wezterm = require('wezterm')

    -- This table will hold the configuration.
    local config = {}

    -- In newer versions of wezterm, use the config_builder which will
    -- help provide clearer error messages
    if wezterm.config_builder then
      config = wezterm.config_builder()
    end

    -- Color scheme
    config.color_scheme = 'tokyonight_night'
    config.colors = {
      background = '#1a1b26',
    }

    -- Font configuration
    config.font = wezterm.font_with_fallback({
      'JetBrains Mono',
      'Noto Looped Thai',
      'Noto Color Emoji',
    })
    config.font_size = 14.0
    config.use_dead_keys = false

    -- Window configuration
    config.hide_tab_bar_if_only_one_tab = true
    config.window_decorations = 'RESIZE'
    config.window_padding = {
      left = 2,
      right = 2,
      top = 0,
      bottom = 0,
    }
    config.window_close_confirmation = 'NeverPrompt'
    config.window_background_opacity = 0.85
    config.adjust_window_size_when_changing_font_size = false

    -- Tab bar configuration
    config.window_frame = {
      font = wezterm.font({ family = 'Roboto', weight = 'Bold' }),
      font_size = 12.0,
      active_titlebar_bg = '#333333',
      inactive_titlebar_bg = '#333333',
    }

    return config
  '';
in {
  options.modules.home.desktop.terminal = {
    enable = lib.mkEnableOption "Terminal emulator configuration";
    
    wezterm = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable WezTerm configuration";
      };

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.wezterm;
        description = "WezTerm package to use";
      };

      fontSize = lib.mkOption {
        type = lib.types.float;
        default = 14.0;
        description = "Font size for WezTerm";
      };

      colorScheme = lib.mkOption {
        type = lib.types.str;
        default = "tokyonight_night";
        description = "Color scheme for WezTerm";
      };

      opacity = lib.mkOption {
        type = lib.types.float;
        default = 0.85;
        description = "Window background opacity (0.0 to 1.0)";
      };

      extraConfig = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = "Extra WezTerm configuration";
      };
    };

    alacritty = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Alacritty configuration";
      };

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.alacritty;
        description = "Alacritty package to use";
      };
    };

    kitty = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Kitty configuration";
      };

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.kitty;
        description = "Kitty package to use";
      };
    };
  };
  
  config = lib.mkIf cfg.enable {
    # WezTerm configuration
    home.file.".config/wezterm/wezterm.lua" = lib.mkIf cfg.wezterm.enable {
      text = ''
        -- Pull in the wezterm API
        local wezterm = require('wezterm')

        -- This table will hold the configuration.
        local config = {}

        -- In newer versions of wezterm, use the config_builder which will
        -- help provide clearer error messages
        if wezterm.config_builder then
          config = wezterm.config_builder()
        end

        -- Color scheme
        config.color_scheme = '${cfg.wezterm.colorScheme}'
        config.colors = {
          background = '#1a1b26',
        }

        -- Font configuration
        config.font = wezterm.font_with_fallback({
          'JetBrains Mono',
          'Noto Looped Thai',
          'Noto Color Emoji',
        })
        config.font_size = ${toString cfg.wezterm.fontSize}
        config.use_dead_keys = false

        -- Window configuration
        config.hide_tab_bar_if_only_one_tab = true
        config.window_decorations = 'RESIZE'
        config.window_padding = {
          left = 2,
          right = 2,
          top = 0,
          bottom = 0,
        }
        config.window_close_confirmation = 'NeverPrompt'
        config.window_background_opacity = ${toString cfg.wezterm.opacity}
        config.adjust_window_size_when_changing_font_size = false

        -- Tab bar configuration
        config.window_frame = {
          font = wezterm.font({ family = 'Roboto', weight = 'Bold' }),
          font_size = 12.0,
          active_titlebar_bg = '#333333',
          inactive_titlebar_bg = '#333333',
        }

        ${cfg.wezterm.extraConfig}

        return config
      '';
    };

    # Alacritty configuration
    programs.alacritty = lib.mkIf cfg.alacritty.enable {
      enable = true;
      package = cfg.alacritty.package;
      
      settings = {
        window = {
          opacity = 0.9;
          padding = {
            x = 2;
            y = 2;
          };
        };
        
        font = {
          normal = {
            family = "JetBrains Mono";
            style = "Regular";
          };
          size = 14.0;
        };
        
        colors = {
          primary = {
            background = "#1a1b26";
            foreground = "#c0caf5";
          };
        };
      };
    };

    # Kitty configuration
    programs.kitty = lib.mkIf cfg.kitty.enable {
      enable = true;
      package = cfg.kitty.package;
      
      font = {
        name = "JetBrains Mono";
        size = 14;
      };
      
      settings = {
        background_opacity = "0.9";
        window_padding_width = 2;
        
        # Tokyo Night theme colors
        foreground = "#c0caf5";
        background = "#1a1b26";
        selection_foreground = "#1a1b26";
        selection_background = "#c0caf5";
        
        # Cursor colors
        cursor = "#c0caf5";
        cursor_text_color = "#1a1b26";
        
        # URL underline color when hovering with mouse
        url_color = "#73daca";
      };
    };

    # Add terminal packages to home.packages
    home.packages = lib.mkMerge [
      (lib.mkIf cfg.wezterm.enable [ cfg.wezterm.package ])
      (lib.mkIf cfg.alacritty.enable [ cfg.alacritty.package ])
      (lib.mkIf cfg.kitty.enable [ cfg.kitty.package ])
    ];
  };
}