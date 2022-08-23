-- Autocommands (https://neovim.io/doc/user/autocmd.html)
-- vim.api.nvim_create_autocmd("BufEnter", {
--   pattern = { "*.json", "*.jsonc" },
--   -- enable wrap mode for json files only
--   command = "setlocal wrap",
-- })

vim.api.nvim_create_autocmd("ColorScheme", {
	pattern = "*",
	callback = function()
		local hl_groups = {
			-- "Normal",
			-- "SignColumn",
			-- "NormalNC",
			-- "TelescopeBorder",
			-- "NvimTreeNormal",
			-- "EndOfBuffer",
			-- "MsgArea",
			"WhichKeyFloat",
			"FloatBorder",
			"NormalFloat",
			-- "StatusLine",
			-- "StatusLineNC",
		}
		for _, name in ipairs(hl_groups) do
			vim.cmd(string.format("highlight %s ctermbg=none guibg=none", name))

			vim.cmd([[highlight IndentBlanklineIndent1 guifg=#E06C75 gui=nocombine]])
			-- vim.cmd([[highlight IndentBlanklineIndent1 guifg=#E06C75 gui=nocombine]])
			-- vim.cmd([[highlight IndentBlanklineIndent2 guifg=#E5C07B gui=nocombine]])
			-- vim.cmd([[highlight IndentBlanklineIndent3 guifg=#98C379 gui=nocombine]])
			-- vim.cmd([[highlight IndentBlanklineIndent4 guifg=#56B6C2 gui=nocombine]])
			-- vim.cmd([[highlight IndentBlanklineIndent5 guifg=#61AFEF gui=nocombine]])
			-- vim.cmd([[highlight IndentBlanklineIndent6 guifg=#C678DD gui=nocombine]])
			vim.cmd([[highlight IndentBlanklineContextChar guifg=#61AFEF gui=nocombine]])
			vim.cmd([[highlight IndentBlanklineSpaceChar guifg=#5c6370 gui=nocombine]])
			-- vim.cmd([[highlight IndentBlanklineContextStart guifg=#C678DD gui=underline]])
		end
	end,
})
