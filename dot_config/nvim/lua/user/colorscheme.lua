local colorscheme = "onedarker"

local status_ok, _ = pcall(vim.cmd, "colorscheme " .. colorscheme)
if not status_ok then
	vim.notify("colorscheme " .. colorscheme .. " not found!")
	return
end

-- transparent
require("transparent").setup({
	enable = true,
	extra_groups = {
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
	},
	exclude = {}, -- table: groups you don't want to clear
})
