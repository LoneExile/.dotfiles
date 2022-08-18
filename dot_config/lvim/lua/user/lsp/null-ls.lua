-- set a formatter, this will override the language server formatting capabilities (if it exists)
local formatters = require("lvim.lsp.null-ls.formatters")
formatters.setup({
	{
		-- each formatter accepts a list of options identical to https://github.com/jose-elias-alvarez/null-ls.nvim/blob/main/doc/BUILTINS.md#Configuration
		command = "prettier",
		---@usage arguments to pass to the formatter
		-- these cannot contain whitespaces, options such as `--line-width 80` become either `{'--line-width', '80'}` or `{'--line-width=80'}`
		extra_args = {
			"--no-semi",
			"--single-quote",
			"--jsx-single-quote",
		},
		---@usage specify which filetypes to enable. By default a providers will attach to all the filetypes it supports.
		-- filetypes = { "typescript", "typescriptreact", "json" },
		disabled_filetypes = { "lua", "python" },
		extra_filetypes = { "toml" },
	},
	{
		command = "stylua",
		extra_args = { "--column-width", "80" },
	},
	-- { command = "black", extra_args = { "--fast" } },
	{
		command = "isort",
		filetypes = { "python" },
	},
})

-- set additional linters
local linters = require("lvim.lsp.null-ls.linters")
linters.setup({
	{
		command = "flake8",
		filetypes = { "python" },
	},
	{
		-- each linter accepts a list of options identical to https://github.com/jose-elias-alvarez/null-ls.nvim/blob/main/doc/BUILTINS.md#Configuration
		command = "shellcheck",
		---@usage arguments to pass to the formatter
		-- these cannot contain whitespaces, options such as `--line-width 80` become either `{'--line-width', '80'}` or `{'--line-width=80'}`
		extra_args = { "--severity", "warning" },
	},
	{
		command = "codespell",
		---@usage specify which filetypes to enable. By default a providers will attach to all the filetypes it supports.
		-- filetypes = { "javascript", "python", "typescript", "typescriptreact" },
	},
})
