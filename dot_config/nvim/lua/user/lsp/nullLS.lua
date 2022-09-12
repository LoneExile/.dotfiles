local null_ls_status_ok, null_ls = pcall(require, "null-ls")
if not null_ls_status_ok then
	return
end

local formatting = null_ls.builtins.formatting
local diagnostics = null_ls.builtins.diagnostics
-- local code_actions = null_ls.builtins.code_actions
-- local completion = null_ls.builtins.completion

local configs = {
	debug = false,
	sources = {
		-- formatting
		formatting.prettier.with({
			extra_args = { "--no-semi", "--single-quote", "--jsx-single-quote" },
			filetypes = { "typescript", "typescriptreact" },
		}),
		formatting.black.with({ extra_args = { "--fast" }, filetypes = { "python" } }),
		formatting.stylua.with({ filetypes = { "lua" } }),
		-- formatting.isort.with({ filetypes = { "python" } }),

		-- diagnostics
		diagnostics.flake8,
	},
}

require("null-ls").setup(configs)
