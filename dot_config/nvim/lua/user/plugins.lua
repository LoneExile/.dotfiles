local fn = vim.fn

-- Automatically install packer
local install_path = fn.stdpath("data") .. "/site/pack/packer/start/packer.nvim"
if fn.empty(fn.glob(install_path)) > 0 then
  PACKER_BOOTSTRAP = fn.system({
    "git",
    "clone",
    "--depth",
    "1",
    "https://github.com/wbthomason/packer.nvim",
    install_path,
  })
  print("Installing packer close and reopen Neovim...")
  vim.cmd([[packadd packer.nvim]])
end

-- Autocommand that reloads neovim whenever you save the plugins.lua file
vim.cmd([[
  augroup packer_user_config
    autocmd!
    autocmd BufWritePost plugins.lua source <afile> | PackerSync
  augroup end
]])

-- Use a protected call so we don't error out on first use
local status_ok, packer = pcall(require, "packer")
if not status_ok then
  vim.notify("packer" .. " not found!")
  return
end

-- Have packer use a popup window
packer.init({
  display = {
    open_fn = function()
      return require("packer.util").float({ border = "rounded" })
    end,
  },
})

-- Install your plugins here
return packer.startup(function(use)
  -- My plugins here

  -- base
  use({ "wbthomason/packer.nvim", commit = "" }) -- Have packer manage itself
  use({ "nvim-lua/plenary.nvim", commit = "" }) -- Useful lua functions used by lots of plugins
  use({ "nvim-lua/popup.nvim", commit = "" })

  -- utility
  use { 'iamcco/markdown-preview.nvim', run = 'cd app && yarn install', cmd = 'MarkdownPreview', commit = "" }

  use({ "kyazdani42/nvim-tree.lua", commit = "" }) -- file explorer
  use({ "akinsho/bufferline.nvim", commit = "" }) -- switch between buffers tabs and window
  use({ "moll/vim-bbye", commit = "" })
  use({ "kyazdani42/nvim-web-devicons", commit = "" }) -- icon

  -- use({ "nvim-lualine/lualine.nvim", commit = "3362b28f917acc37538b1047f187ff1b5645ecdd" })
  -- use({ "akinsho/toggleterm.nvim", commit = "aaeed9e02167c5e8f00f25156895a6fd95403af8" })
  -- use({ "ahmedkhalf/project.nvim", commit = "541115e762764bc44d7d3bf501b6e367842d3d4f" })
  -- use({ "lewis6991/impatient.nvim", commit = "969f2c5c90457612c09cf2a13fee1adaa986d350" })
  -- use({ "lukas-reineke/indent-blankline.nvim", commit = "6177a59552e35dfb69e1493fd68194e673dc3ee2" })

  -- shortcut plugins
  use({ "folke/which-key.nvim", commit = "" }) -- which-key
  use({ "justinmk/vim-sneak", commit = "" }) -- jumpy
  use({ "unblevable/quick-scope", commit = "" }) -- jumpy but in line

  -- dashboard
  use({ "goolord/alpha-nvim", commit = "" })

  -- Colorschemes
  use({ "xiyaowong/nvim-transparent", commit = "" }) -- transparent :Transparent* (config in Colorschemes)
  use({ "folke/tokyonight.nvim", commit = "" })
  use({ "lunarvim/darkplus.nvim" })

  -- cmp plugins
  use({ "hrsh7th/nvim-cmp", commit = "" }) -- The completion plugin
  use({ "hrsh7th/cmp-buffer", commit = "" }) -- buffer completions
  use({ "hrsh7th/cmp-path", commit = "" }) -- path completions
  use({ "saadparwaiz1/cmp_luasnip", commit = "" }) -- snippet completions
  use({ "hrsh7th/cmp-nvim-lsp", commit = "" })
  use({ "hrsh7th/cmp-nvim-lua", commit = "" })

  -- snippets
  use({ "L3MON4D3/LuaSnip", commit = "" }) --snippet engine
  use({ "rafamadriz/friendly-snippets", commit = "" }) -- a bunch of snippets to use

  -- LSP
  vim.g.python3_host_prog = '$HOME/.pyenv/versions/nvim/bin/python'
  use({ "neovim/nvim-lspconfig", commit = "" }) -- enable LSP
  use({ "williamboman/nvim-lsp-installer", commit = "" }) -- simple to use language server installer
  use({ "jose-elias-alvarez/null-ls.nvim", commit = "" }) -- for formatters and linters
  use({ "windwp/nvim-autopairs" }) -- Autopairs, integrates with both cmp and treesitter

  -- Telescope
  use({ "nvim-telescope/telescope.nvim", commit = "" })
  -- use({ "nvim-telescope/telescope-project.nvim" })

  -- Treesitter
  use({
    "nvim-treesitter/nvim-treesitter",
    commit = "",
  })
  use({ "p00f/nvim-ts-rainbow", commit = "" })
  use({ "numToStr/Comment.nvim", commit = "" })
  use({ "JoosepAlviste/nvim-ts-context-commentstring" })

  -- Git
  use({ "lewis6991/gitsigns.nvim", commit = "" })

  -- Automatically set up your configuration after cloning packer.nvim
  -- Put this at the end after all plugins
  if PACKER_BOOTSTRAP then
    require("packer").sync()
  end
end)
