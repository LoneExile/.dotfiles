-- nixCats Neovim Configuration
-- Main initialization file - modular approach

-- NOTE: These 2 need to be set up before any plugins are loaded.
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Set colorscheme early
vim.cmd.colorscheme('onedark')

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