-- Additional Plugins
lvim.plugins = {
	-- theme
	{ "folke/tokyonight.nvim" },

	-- debugger
	{ "rcarriga/nvim-dap-ui" },
	-- { "Pocco81/dap-buddy.nvim" },
	{ "theHamsta/nvim-dap-virtual-text" },
	{ "leoluz/nvim-dap-go" },
	{ "nvim-telescope/telescope-dap.nvim" },
	{ "mfussenegger/nvim-dap-python" },

	-- LSP
	{ "glepnir/lspsaga.nvim", branch = "main" },
	{
		"folke/trouble.nvim",
		cmd = "TroubleToggle",
		requires = "kyazdani42/nvim-web-devicons",
	},
	{ "windwp/nvim-ts-autotag" },

	-- utility
	{ "unblevable/quick-scope" }, -- jumpy but in line
	{ "norcalli/nvim-colorizer.lua" }, --color highlighter
	{ "phaazon/hop.nvim" }, -- EasyMotion
	{ "nacro90/numb.nvim" }, -- Peek lines just when you intend
	-- { "andymass/vim-matchup" }, -- highlight, navigate, and operate on sets of matching text
	{
		"windwp/nvim-spectre",
		requires = "nvim-lua/plenary.nvim",
	},
	{
		"metakirby5/codi.vim",
		cmd = "Codi",
	},
	{ "lukas-reineke/indent-blankline.nvim" },
	-- { "nvim-telescope/telescope-project.nvim" },
	--
}
