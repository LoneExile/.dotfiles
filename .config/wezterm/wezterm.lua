-- Pull in the wezterm API
local wezterm = require('wezterm')

-- This table will hold the configuration.
local config = {}

-- In newer versions of wezterm, use the config_builder which will
-- help provide clearer error messages
if wezterm.config_builder then
  config = wezterm.config_builder()
end

-- This is where you actually apply your config choices

-- For example, changing the color scheme:
-- config.color_scheme = 'AdventureTime'
-- config.color_scheme = 'Batman'
-- config.color_scheme = 'SpaceGray'
-- config.color_scheme = 'tokyonight_moon'
config.color_scheme = 'tokyonight_night'
-- config.color_scheme = 'Tomorrow (dark) (terminal.sexy)'
-- config.color_scheme = 'Tomorrow Night'
-- config.color_scheme = 'Twilight'

config.colors = {
  background = '#1a1b26',
}

-- config.font = wezterm.font('JetBrains Mono')
-- config.font = wezterm.font('JetBrains Mono', { weight = 'Bold', italic = true })
config.font = wezterm.font_with_fallback({
  'JetBrains Mono',
  'Noto Looped Thai',
  'Noto Color Emoji',
})
config.use_dead_keys = false

-- config.use_fancy_tab_bar = false
-- config.enable_tab_bar = true
-- config.tab_bar_at_bottom = true
config.hide_tab_bar_if_only_one_tab = true
config.window_decorations = 'RESIZE'

config.window_padding = {
  left = 2,
  right = 2,
  top = 0,
  bottom = 0,
}
config.font_size = 14.0

config.window_close_confirmation = 'NeverPrompt'
config.window_background_opacity = 0.75
-- config.window_background_opacity = 0.60
-- config.text_background_opacity = 1.0

-- config.exit_behavior = 'Close'
config.adjust_window_size_when_changing_font_size = false
-- config.disable_default_mouse_bindings = true
-- config.keys = {
--   { action = wezterm.action.CopyTo('Clipboard'), mods = 'CTRL|SHIFT', key = 'C' },
--   { action = wezterm.action.DecreaseFontSize, mods = 'CTRL', key = '-' },
--   { action = wezterm.action.IncreaseFontSize, mods = 'CTRL', key = '=' },
--   { action = wezterm.action.Nop, mods = 'ALT', key = 'Enter' },
--   { action = wezterm.action.PasteFrom('Clipboard'), mods = 'CTRL|SHIFT', key = 'V' },
--   { action = wezterm.action.ResetFontSize, mods = 'CTRL', key = '0' },
--   { action = wezterm.action.ToggleFullScreen, key = 'F11' },
-- }

config.window_frame = {
  -- The font used in the tab bar.
  -- Roboto Bold is the default; this font is bundled
  -- with wezterm.
  -- Whatever font is selected here, it will have the
  -- main font setting appended to it to pick up any
  -- fallback fonts you may have used there.
  font = wezterm.font({ family = 'Roboto', weight = 'Bold' }),

  -- The size of the font in the tab bar.
  -- Default to 10. on Windows but 12.0 on other systems
  font_size = 12.0,

  -- The overall background color of the tab bar when
  -- the window is focused
  active_titlebar_bg = '#333333',

  -- The overall background color of the tab bar when
  -- the window is not focused
  inactive_titlebar_bg = '#333333',
}

-- and finally, return the configuration to wezterm
return config
