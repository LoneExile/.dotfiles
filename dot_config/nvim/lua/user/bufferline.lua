local status_ok, bufferline = pcall(require, "bufferline")
if not status_ok then
	vim.notify("bufferline" .. " not found!")
	return
end

local function is_ft(b, ft)
	return vim.bo[b].filetype == ft
end

local function diagnostics_indicator(num, _, diagnostics, _)
	local result = {}
	local symbols = { error = "", warning = "", info = "" }
	for name, count in pairs(diagnostics) do
		if symbols[name] and count > 0 then
			table.insert(result, symbols[name] .. " " .. count)
		end
	end
	result = table.concat(result, " ")
	return #result > 0 and result or ""
end

local function custom_filter(buf, buf_nums)
	local logs = vim.tbl_filter(function(b)
		return is_ft(b, "log")
	end, buf_nums)
	if vim.tbl_isempty(logs) then
		return true
	end
	local tab_num = vim.fn.tabpagenr()
	local last_tab = vim.fn.tabpagenr("$")
	local is_log = is_ft(buf, "log")
	if last_tab == 1 then
		return true
	end
	-- only show log buffers in secondary tabs
	return (tab_num == last_tab and is_log) or (tab_num ~= last_tab and not is_log)
end

local config = {
	options = {
		numbers = "none",
		close_command = "bdelete! %d",
		right_mouse_command = "vert sbuffer %d",
		left_mouse_command = "buffer %d",
		middle_mouse_command = nil,
		indicator = { style = "icon", icon = "▎" },
		-- buffer_close_icon = "",
		modified_icon = "●",
		close_icon = "",
		left_trunc_marker = "",
		right_trunc_marker = "",
		name_formatter = function(buf)
			if buf.name:match("%.md") then
				return vim.fn.fnamemodify(buf.name, ":t:r")
			end
		end,
		max_name_length = 18,
		max_prefix_length = 15,
		tab_size = 18,
		-- diagnostics = "nvim_lsp",
		-- diagnostics_update_in_insert = false,
		-- diagnostics_indicator = diagnostics_indicator,
		custom_filter = custom_filter,
		offsets = {
			{
				filetype = "undotree",
				text = "Undotree",
				highlight = "PanelHeading",
				padding = 1,
			},
			{
				filetype = "NvimTree",
				text = "Explorer",
				highlight = "PanelHeading",
				padding = 1,
			},
			{
				filetype = "neo-tree",
				text = "Explorer",
				highlight = "PanelHeading",
				padding = 1,
			},
			{
				filetype = "DiffviewFiles",
				text = "Diff View",
				highlight = "PanelHeading",
				padding = 1,
			},
			{
				filetype = "flutterToolsOutline",
				text = "Flutter Outline",
				highlight = "PanelHeading",
			},
			{
				filetype = "packer",
				text = "Packer",
				highlight = "PanelHeading",
				padding = 1,
			},
		},
		show_buffer_icons = true,
		show_buffer_close_icons = false,
		show_close_icon = false,
		show_tab_indicators = true,
		persist_buffer_sort = true,
		separator_style = "thin",
		enforce_regular_tabs = false,
		always_show_bufferline = false,
		sort_by = "id",
	},
	highlights = {
		background = {
			-- fg = "#CBA6F7",
			italic = true,
		},
		buffer_selected = {
			fg = "#8A2BE2",
			italic = true,
			bold = true,
		},
		separator = {
			fg = "#CBA6F7",
			-- bg = "#8A2BE2",
		},
	},
}

bufferline.setup(config)

----------------------------------------------------
-- fill = {
--     fg = '<colour-value-here>',
--     bg = '<colour-value-here>',
-- },
-- background = {
--     fg = '<colour-value-here>',
--     bg = '<colour-value-here>'
-- },
-- tab = {
--     fg = '<colour-value-here>',
--     bg = '<colour-value-here>'
-- },
-- tab_selected = {
--     fg = tabline_sel_bg,
--     bg = '<colour-value-here>'
-- },
-- tab_close = {
--     fg = '<colour-value-here>',
--     bg = '<colour-value-here>'
-- },
-- close_button = {
--     fg = '<colour-value-here>',
--     bg = '<colour-value-here>'
-- },
-- close_button_visible = {
--     fg = '<colour-value-here>',
--     bg = '<colour-value-here>'
-- },
-- close_button_selected = {
--     fg = '<colour-value-here>',
--     bg = '<colour-value-here>'
-- },
-- buffer_visible = {
--     fg = '<colour-value-here>',
--     bg = '<colour-value-here>'
-- },
-- buffer_selected = {
--     fg = normal_fg,
--     bg = '<colour-value-here>',
--     bold = true,
--     italic = true,
-- },
-- numbers = {
--     fg = '<colour-value-here>',
--     bg = '<colour-value-here>',
-- },
-- numbers_visible = {
--     fg = '<colour-value-here>',
--     bg = '<colour-value-here>',
-- },
-- numbers_selected = {
--     fg = '<colour-value-here>',
--     bg = '<colour-value-here>',
--     bold = true,
--     italic = true,
-- },
-- diagnostic = {
--     fg = '<colour-value-here>',
--     bg = '<colour-value-here>',
-- },
-- diagnostic_visible = {
--     fg = '<colour-value-here>',
--     bg = '<colour-value-here>',
-- },
-- diagnostic_selected = {
--     fg = '<colour-value-here>',
--     bg = '<colour-value-here>',
--     bold = true,
--     italic = true,
-- },
-- hint = {
--     fg = '<colour-value-here>',
--     sp = '<colour-value-here>',
--     bg = '<colour-value-here>'
-- },
-- hint_visible = {
--     fg = '<colour-value-here>',
--     bg = '<colour-value-here>'
-- },
-- hint_selected = {
--     fg = '<colour-value-here>',
--     bg = '<colour-value-here>',
--     sp = '<colour-value-here>'
--     bold = true,
--     italic = true,
-- },
-- hint_diagnostic = {
--     fg = '<colour-value-here>',
--     sp = '<colour-value-here>',
--     bg = '<colour-value-here>'
-- },
-- hint_diagnostic_visible = {
--     fg = '<colour-value-here>',
--     bg = '<colour-value-here>'
-- },
-- hint_diagnostic_selected = {
--     fg = '<colour-value-here>',
--     bg = '<colour-value-here>',
--     sp = '<colour-value-here>'
--     bold = true,
--     italic = true,
-- },
-- info = {
--     fg = '<colour-value-here>',
--     sp = '<colour-value-here>',
--     bg = '<colour-value-here>'
-- },
-- info_visible = {
--     fg = '<colour-value-here>',
--     bg = '<colour-value-here>'
-- },
-- info_selected = {
--     fg = '<colour-value-here>',
--     bg = '<colour-value-here>',
--     sp = '<colour-value-here>'
--     bold = true,
--     italic = true,
-- },
-- info_diagnostic = {
--     fg = '<colour-value-here>',
--     sp = '<colour-value-here>',
--     bg = '<colour-value-here>'
-- },
-- info_diagnostic_visible = {
--     fg = '<colour-value-here>',
--     bg = '<colour-value-here>'
-- },
-- info_diagnostic_selected = {
--     fg = '<colour-value-here>',
--     bg = '<colour-value-here>',
--     sp = '<colour-value-here>'
--     bold = true,
--     italic = true,
-- },
-- warning = {
--     fg = '<colour-value-here>',
--     sp = '<colour-value-here>',
--     bg = '<colour-value-here>'
-- },
-- warning_visible = {
--     fg = '<colour-value-here>',
--     bg = '<colour-value-here>'
-- },
-- warning_selected = {
--     fg = '<colour-value-here>',
--     bg = '<colour-value-here>',
--     sp = '<colour-value-here>'
--     bold = true,
--     italic = true,
-- },
-- warning_diagnostic = {
--     fg = '<colour-value-here>',
--     sp = '<colour-value-here>',
--     bg = '<colour-value-here>'
-- },
-- warning_diagnostic_visible = {
--     fg = '<colour-value-here>',
--     bg = '<colour-value-here>'
-- },
-- warning_diagnostic_selected = {
--     fg = '<colour-value-here>',
--     bg = '<colour-value-here>',
--     sp = warning_diagnostic_fg
--     bold = true,
--     italic = true,
-- },
-- error = {
--     fg = '<colour-value-here>',
--     bg = '<colour-value-here>',
--     sp = '<colour-value-here>'
-- },
-- error_visible = {
--     fg = '<colour-value-here>',
--     bg = '<colour-value-here>'
-- },
-- error_selected = {
--     fg = '<colour-value-here>',
--     bg = '<colour-value-here>',
--     sp = '<colour-value-here>'
--     bold = true,
--     italic = true,
-- },
-- error_diagnostic = {
--     fg = '<colour-value-here>',
--     bg = '<colour-value-here>',
--     sp = '<colour-value-here>'
-- },
-- error_diagnostic_visible = {
--     fg = '<colour-value-here>',
--     bg = '<colour-value-here>'
-- },
-- error_diagnostic_selected = {
--     fg = '<colour-value-here>',
--     bg = '<colour-value-here>',
--     sp = '<colour-value-here>'
--     bold = true,
--     italic = true,
-- },
-- modified = {
--     fg = '<colour-value-here>',
--     bg = '<colour-value-here>'
-- },
-- modified_visible = {
--     fg = '<colour-value-here>',
--     bg = '<colour-value-here>'
-- },
-- modified_selected = {
--     fg = '<colour-value-here>',
--     bg = '<colour-value-here>'
-- },
-- duplicate_selected = {
--     fg = '<colour-value-here>',
--     bg = '<colour-value-here>'
--     italic = true,
-- },
-- duplicate_visible = {
--     fg = '<colour-value-here>',
--     bg = '<colour-value-here>'
--     italic = true
-- },
-- duplicate = {
--     fg = '<colour-value-here>',
--     bg = '<colour-value-here>'
--     italic = true
-- },
-- separator_selected = {
--     fg = '<colour-value-here>',
--     bg = '<colour-value-here>'
-- },
-- separator_visible = {
--     fg = '<colour-value-here>',
--     bg = '<colour-value-here>'
-- },
-- separator = {
--     fg = '<colour-value-here>',
--     bg = '<colour-value-here>'
-- },
-- indicator_selected = {
--     fg = '<colour-value-here>',
--     bg = '<colour-value-here>'
-- },
-- pick_selected = {
--     fg = '<colour-value-here>',
--     bg = '<colour-value-here>',
--     bold = true,
--     italic = true,
-- },
-- pick_visible = {
--     fg = '<colour-value-here>',
--     bg = '<colour-value-here>',
--     bold = true,
--     italic = true,
-- },
-- pick = {
--     fg = '<colour-value-here>',
--     bg = '<colour-value-here>',
--     bold = true,
--     italic = true,
-- },
-- offset_separator = {
--     fg = win_separator_fg,
--     bg = separator_background_color,
-- },
