local lsp = require("lsp-zero")

-- lsp.preset("lsp-compe")
lsp.preset("per-project")
lsp.set_preferences({
	-- suggest_lsp_servers = true,
	-- setup_servers_on_start = true,
	set_lsp_keymaps = false,
	-- configure_diagnostics = true,
	-- cmp_capabilities = true,
	-- manage_nvim_cmp = true,
	-- call_servers = "local",
	sign_icons = {
		error = "✘",
		warn = "▲",
		hint = "⚑",
		info = "",
	},
})
require("user.lsp.mason")
require("user.lsp.lspConfig")
require("user.lsp.cmp")

lsp.use("sumneko_lua", {
	settings = {
		Lua = {
			completion = {
				callSnippet = "Replace",
			},
			diagnostics = {
				globals = { "vim" },
			},
		},
	},
})

lsp.use("jsonls", {
	settings = {
		json = {
			schemas = require("schemastore").json.schemas(),
			validate = { enable = true },
		},
	},
})

lsp.use("pyright", {
	settings = {
		python = {
			analysis = {
				autoSearchPaths = true,
				useLibraryCodeForTypes = true,
				typeCheckingMode = "off",
			},
		},
	},
})

lsp.setup()
