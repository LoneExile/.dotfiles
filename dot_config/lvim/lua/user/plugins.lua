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

	-- utility
	{ "unblevable/quick-scope" }, -- jumpy but in line
	{ "norcalli/nvim-colorizer.lua" }, --color highlighter
	--
	{
		"folke/trouble.nvim",
		cmd = "TroubleToggle",
		requires = "kyazdani42/nvim-web-devicons",
		config = function()
			require("trouble").setup({
				-- your configuration comes here
				-- or leave it empty to use the default settings
				-- refer to the configuration section below
			})
		end,
	},
}
