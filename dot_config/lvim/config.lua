require("user.autocmd")
require("user.setting")
require("user.plugins")
require("user.file-manager")
require("user.lsp")
require("user.treesitter")
require("user.dap")
require("user.utility")
require("user.copilot")

-- local cmp = require("cmp")
-- cmp.setup({
-- 	completion = {
-- 		autocomplete = false,
-- 	},
-- })

lvim.builtin.cmp.experimental.ghost_text = false

lvim.builtin.alpha.custom_header = {
	" ███╗   ██╗ ███████╗ ██████╗  ██╗   ██╗ ██╗ ███╗   ███╗",
	" ████╗  ██║ ██╔════╝██╔═══██╗ ██║   ██║ ██║ ████╗ ████║",
	" ██╔██╗ ██║ █████╗  ██║   ██║ ██║   ██║ ██║ ██╔████╔██║",
	" ██║╚██╗██║ ██╔══╝  ██║   ██║ ╚██╗ ██╔╝ ██║ ██║╚██╔╝██║",
	" ██║ ╚████║ ███████╗╚██████╔╝  ╚████╔╝  ██║ ██║ ╚═╝ ██║",
	" ╚═╝  ╚═══╝ ╚══════╝ ╚═════╝    ╚═══╝   ╚═╝ ╚═╝     ╚═╝",
}

lvim.lsp.buffer_mappings = {
	normal_mode = {
		-- ["K"] = { vim.lsp.buf.hover, "Show hover" },
		-- ["gd"] = { vim.lsp.buf.definition, "Goto Definition" },
		["gs"] = { vim.lsp.buf.signature_help, "show signature help" },
		-- ["gr"] = { vim.lsp.buf.references, "Goto references" },
		["K"] = { "<cmd>Lspsaga hover_doc<CR>", "Show hover" },
		["gD"] = { vim.lsp.buf.declaration, "Goto declaration" },
		["gI"] = { vim.lsp.buf.implementation, "Goto Implementation" },
		["gp"] = {
			function()
				require("lvim.lsp.peek").Peek("definition")
			end,
			"Peek definition",
		},
		["gl"] = {
			function()
				local config = lvim.lsp.diagnostics.float
				config.scope = "line"
				vim.diagnostic.open_float(0, config)
			end,
			"Show line diagnostics",
		},
	},
	insert_mode = {},
	visual_mode = {},
}
