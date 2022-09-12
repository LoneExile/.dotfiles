local api = vim.api

-- Highlight on yank
local yankGrp = api.nvim_create_augroup("YankHighlight", { clear = true })
api.nvim_create_autocmd("TextYankPost", {
	command = "silent! lua vim.highlight.on_yank()",
	group = yankGrp,
})

-------------------------------------------------------------

vim.api.nvim_create_autocmd("ColorScheme", {
	pattern = "*",
	callback = function()
		local hl_groups = {
			"BufferLineTabClose",
			"BufferlineBufferSelected",
			"BufferLineFill",
			"BufferLineBackground",
			"BufferLineSeparator",
			"BufferLineIndicatorSelected",
			"BufferLineDevIconDefault",
			"Normal",
			"SignColumn",
			"NormalNC",
			"TelescopeBorder",
			"NvimTreeNormal",
			"EndOfBuffer",
			"MsgArea",
			"WhichKeyFloat",
			"FloatBorder",
			"NormalFloat",
			"VertSplit",
			"WinBar",
			"StatusLine",
			"StatusLineNC",
			"WinBarNC",
		}
		for _, name in ipairs(hl_groups) do
			vim.cmd(string.format("highlight %s ctermbg=none guibg=none", name))
		end
	end,
})
