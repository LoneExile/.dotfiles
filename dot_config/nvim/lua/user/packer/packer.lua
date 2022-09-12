local execute = vim.api.nvim_command
local fn = vim.fn

-- ensure that packer is installed
local install_path = fn.stdpath("data") .. "/site/pack/packer/opt/packer.nvim"
if fn.empty(fn.glob(install_path)) > 0 then
	execute("!git clone https://github.com/wbthomason/packer.nvim " .. install_path)
	execute("packadd packer.nvim")
end
vim.cmd("packadd packer.nvim")
local packer = require("packer")
local util = require("packer.util")
packer.init({
	package_root = util.join_paths(vim.fn.stdpath("data"), "site", "pack"),
})

packer.startup(function(use)
	-- base
	use({ "wbthomason/packer.nvim" })
	use({ "nvim-lua/plenary.nvim" })
	use({ "nvim-lua/popup.nvim" })
	use({ "kyazdani42/nvim-web-devicons" })

	-- Treesitter
	use({ "nvim-treesitter/nvim-treesitter" })
	use({ "p00f/nvim-ts-rainbow" })
	use({ "numToStr/Comment.nvim" })
	use({ "JoosepAlviste/nvim-ts-context-commentstring" })
	use({ "nvim-treesitter/nvim-treesitter-context" })
	use({ "lukas-reineke/indent-blankline.nvim" })
	-- use({ "windwp/nvim-autopairs" })
	-- use{ "windwp/nvim-ts-autotag" }

	-- utility
	use({ "lewis6991/impatient.nvim" })
	use({ "windwp/nvim-spectre" })
	use({ "nacro90/numb.nvim" })
	use({ "michaelb/sniprun", run = "bash ./install.sh" })
	use({ "metakirby5/codi.vim", cmd = "Codi" })
	use({ "tpope/vim-repeat" })
	use({ "folke/zen-mode.nvim" })
	use({ "ThePrimeagen/harpoon" })

	-- color management
	use({ "norcalli/nvim-colorizer.lua" })
	use({
		"max397574/colortils.nvim",
		cmd = "Colortils",
		config = function()
			require("colortils").setup()
		end,
	})

	-- LSP
	vim.g.python3_host_prog = "$HOME/.pyenv/versions/nvim/bin/python"
	use({
		"VonHeikemen/lsp-zero.nvim",
		requires = {
			-- LSP Support
			{ "neovim/nvim-lspconfig" },
			{ "williamboman/mason.nvim" },
			{ "williamboman/mason-lspconfig.nvim" },

			-- Autocompletion
			{ "hrsh7th/nvim-cmp" },
			{ "hrsh7th/cmp-buffer" },
			{ "hrsh7th/cmp-path" },
			{ "saadparwaiz1/cmp_luasnip" },
			{ "hrsh7th/cmp-nvim-lsp" },
			{ "hrsh7th/cmp-nvim-lua" },

			-- Snippets
			{ "L3MON4D3/LuaSnip" },
			{ "rafamadriz/friendly-snippets" },
		},
	})
	use({ "jose-elias-alvarez/null-ls.nvim" })
	use({ "glepnir/lspsaga.nvim", branch = "main" })
	use({ "github/copilot.vim" })
	use({
		"zbirenbaum/copilot.lua",
		commit = "ede741d935cf5d962c9a9e44db2400ed1a4aaf13",
		event = { "VimEnter" },
		config = function()
			vim.defer_fn(function()
				require("copilot").setup()
			end, 100)
		end,
	})
	use({
		"zbirenbaum/copilot-cmp",
		commit = "67825246fa2aa6226ec3320d554640aa4697e1b1",
		module = "copilot_cmp",
	})
	use({ "ThePrimeagen/refactoring.nvim" })
	use({ "echasnovski/mini.nvim" })

	-- debugger
	use({ "mfussenegger/nvim-dap" })
	use({ "Pocco81/dap-buddy.nvim" })
	use({ "rcarriga/nvim-dap-ui" })
	use({ "theHamsta/nvim-dap-virtual-text" })
	use({ "nvim-telescope/telescope-dap.nvim" })
	use({ "mfussenegger/nvim-dap-python" })
	use({ "leoluz/nvim-dap-go" })

	-- UI
	use({ "goolord/alpha-nvim" })
	use({ "nvim-neo-tree/neo-tree.nvim", requires = { "MunifTanjim/nui.nvim" } })
	use({ "akinsho/bufferline.nvim" })
	use({ "nvim-lualine/lualine.nvim" })
	use({ "akinsho/toggleterm.nvim" })

	-- use({ "ahmedkhalf/project.nvim", commit = "541115e762764bc44d7d3bf501b6e367842d3d4f" })

	-- shortcut plugins
	use({ "folke/which-key.nvim", commit = "" })

	-- Colorschemes
	use({ "LunarVim/onedarker.nvim" })

	-- Telescope
	use({ "nvim-telescope/telescope.nvim" })
	use({ "nvim-telescope/telescope-fzf-native.nvim" })

	-- Git
	use({ "lewis6991/gitsigns.nvim", commit = "" })
end)
