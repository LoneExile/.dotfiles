-- nixCats Neovim Configuration
-- Main initialization file - modular approach

-- NOTE: These 2 need to be set up before any plugins are loaded.
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Set colorscheme early
-- Configure Tokyo Night theme
require("tokyonight").setup({
  style = "storm",        -- The theme comes in three styles, `storm`, `moon`, a darker variant `night` and `day`
  transparent = false,    -- Enable this to disable setting the background color
  terminal_colors = true, -- Configure the colors used when opening a `:terminal` in Neovim
  styles = {
    comments = { italic = true },
    keywords = { italic = true },
    functions = {},
    variables = {},
  },
})

vim.cmd.colorscheme('tokyonight')

-- Load core configuration modules
require('config.options')
require('config.keymaps')
require('config.autocmds')

-- Setup Snacks for UI components first
require("snacks").setup({
  explorer = {},
  picker = {},
  bigfile = {},
  image = {},
  lazygit = {},
  terminal = {},
  rename = {},
  notifier = {},
  indent = {},
  gitbrowse = {},
  scope = {},
})

-- Load plugin configurations
require('plugins.ui')
require('plugins.completion')
require('plugins.development')
require('plugins.lsp')
