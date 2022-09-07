local null_ls_status_ok, null_ls = pcall(require, "null-ls")
if not null_ls_status_ok then
	return
end

local formatting = null_ls.builtins.formatting
local diagnostics = null_ls.builtins.diagnostics

local config = {
	debug = false,
	sources = {
		formatting.prettier.with({
			extra_args = { "--no-semi", "--single-quote", "--jsx-single-quote" },
			filetypes = { "typescript", "typescriptreact" },
		}),
		formatting.black.with({ extra_args = { "--fast" }, filetypes = { "python" } }),
		formatting.stylua,
		diagnostics.flake8,
		formatting.isort.with({ filetypes = { "python" } }),
	},
}

null_ls.setup(config)
