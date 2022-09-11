local api = vim.api

-- api.nvim_create_autocmd("ColorScheme", {
-- 	pattern = "*", callback = function() vim.api.nvim_set_hl(0, "CmpItemKindCopilot", { fg = "#6CC644" }) end,
-- })
-- vim.api.nvim_set_hl(0, "CmpItemKindCopilot", { fg = "#6CC644" })

-- Highlight on yank
local yankGrp = api.nvim_create_augroup("YankHighlight", { clear = true })
api.nvim_create_autocmd("TextYankPost", {
	command = "silent! lua vim.highlight.on_yank()",
	group = yankGrp,
})

-------------------------------------------------------------
