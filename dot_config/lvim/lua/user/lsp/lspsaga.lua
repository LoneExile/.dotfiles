-- ~/.local/share/lunarvim/lvim/lua/lvim/lsp/config.lua

-- local action = require("lspsaga.codeaction")s
local status_ok_code, action = pcall(require, "lspsaga.codeaction")
if not status_ok_code then
	vim.notify("lspsaga action" .. " not found!")
	return
end

local status_ok, lspsaga = pcall(require, "lspsaga")
if not status_ok then
	vim.notify("lspsaga" .. " not found!")
	return
end

local opts = { noremap = true, silent = true }

vim.keymap.set("n", "K", "<cmd>Lspsaga hover_doc<CR>", opts)
vim.keymap.set("n", "gr", "<cmd>Lspsaga lsp_finder<CR>", opts)
-- vim.keymap.set("n", "gs", "<Cmd>Lspsaga signature_help<CR>", opts)
vim.keymap.set("n", "gd", "<cmd>Lspsaga preview_definition<CR>", opts)
vim.keymap.set("n", "gR", "<cmd>Lspsaga rename<CR>", opts)
vim.keymap.set("n", "gq", "<cmd>Lspsaga code_action<CR>", opts)
vim.keymap.set("n", "gj", "<cmd>Lspsaga diagnostic_jump_next<CR>", opts)
vim.keymap.set("n", "gk", "<cmd>Lspsaga diagnostic_jump_prev<CR>", opts)
-- vim.keymap.set("n", "gr", "<cmd>Trouble lsp_references<cr>", opts)
-- vim.keymap.set("n", "]e", "<cmd>Lspsaga diagnostic_jump_next<CR>", opts)
-- vim.keymap.set("n", "[e", "<cmd>Lspsaga diagnostic_jump_prev<CR>", opts)

-- vim.keymap.set("n", "<leader>Ca", "<cmd>Lspsaga code_action<CR>", opts)
-- vim.keymap.set("v", "<leader>Ca", "<cmd><C-U>Lspsaga range_code_action<CR>", opts)

----
-- K
-- scroll down hover doc or scroll in definition preview
-- vim.keymap.set("n", "<C-f>", function()
-- 	action.smart_scroll_with_saga(1)
-- end, { silent = true })
-- -- scroll up hover doc
-- vim.keymap.set("n", "<C-b>", function()
-- 	action.smart_scroll_with_saga(-1)
-- end, { silent = true })

--- config

local config = {
	border_style = "rounded",
	code_action_lightbulb = {
		enable = false,
		sign = true,
		enable_in_insert = true,
		sign_priority = 20,
		virtual_text = false,
	},
	symbol_in_winbar = {
		in_custom = false,
	},
}

-- local saga = require("lspsaga")
lspsaga.setup()

lspsaga.init_lsp_saga(config)

-- winbar

local function get_file_name(include_path)
	local file_name = require("lspsaga.symbolwinbar").get_file_name()
	if vim.fn.bufname("%") == "" then
		return ""
	end
	if include_path == false then
		return file_name
	end
	-- Else if include path: ./lsp/saga.lua -> lsp > saga.lua
	local sep = vim.loop.os_uname().sysname == "Windows" and "\\" or "/"
	local path_list = vim.split(string.gsub(vim.fn.expand("%:~:.:h"), "%%", ""), sep)
	local file_path = ""
	for _, cur in ipairs(path_list) do
		file_path = (cur == "." or cur == "~") and ""
			or file_path .. cur .. " " .. "%#LspSagaWinbarSep#>%*" .. " %*"
	end
	return file_path .. file_name
end

local function config_winbar_or_statusline()
	local exclude = {
		["teminal"] = true,
		["toggleterm"] = true,
		["prompt"] = true,
		["NvimTree"] = true,
		["help"] = true,
	} -- Ignore float windows and exclude filetype
	if vim.api.nvim_win_get_config(0).zindex or exclude[vim.bo.filetype] then
		vim.wo.winbar = ""
	else
		local ok, lspsaga = pcall(require, "lspsaga.symbolwinbar")
		local sym
		if ok then
			sym = lspsaga.get_symbol_node()
		end
		local win_val = ""
		win_val = get_file_name(true) -- set to true to include path
		if sym ~= nil then
			win_val = win_val .. sym
		end
		vim.wo.winbar = win_val
		-- if work in statusline
		vim.wo.stl = win_val
	end
end

local events = { "BufEnter", "BufWinEnter", "CursorMoved" }

vim.api.nvim_create_autocmd(events, {
	pattern = "*",
	callback = function()
		config_winbar_or_statusline()
	end,
})

vim.api.nvim_create_autocmd("User", {
	pattern = "LspsagaUpdateSymbol",
	callback = function()
		config_winbar_or_statusline()
	end,
})
