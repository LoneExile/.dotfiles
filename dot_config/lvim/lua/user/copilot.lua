-- vim.g.copilot_filetypes = { xml = false }
vim.g.copilot_no_tab_map = true
vim.api.nvim_set_keymap(
	"i",
	"<C-a>",
	"copilot#Accept('<CR>')",
	{ expr = true, silent = true }
)
vim.api.nvim_set_keymap(
	"i",
	"<C-.>",
	"copilot-next('<CR>')",
	{ expr = true, silent = true }
)

vim.cmd([[highlight CopilotSuggestion guifg=#555555 ctermfg=8]])

-----------------------
-- vim.api.nvim_set_hl(0, "CmpItemKindCopilot", { fg = "#6CC644" })
-- lvim.builtin.cmp.formatting.format = function(entry, vim_item)
-- 	local max_width = lvim.builtin.cmp.formatting.max_width
-- 	if max_width ~= 0 and #vim_item.abbr > max_width then
-- 		vim_item.abbr = string.sub(vim_item.abbr, 1, max_width - 1) .. "…"
-- 	end
-- 	if lvim.use_icons then
-- 		vim_item.kind = lvim.builtin.cmp.formatting.kind_icons[vim_item.kind]
-- 	end
-- 	if entry.source.name == "copilot" then
-- 		vim_item.kind = "[] Copilot"
-- 		vim_item.kind_hl_group = "CmpItemKindCopilot"
-- 	end
-- 	vim_item.menu = lvim.builtin.cmp.formatting.source_names[entry.source.name]
-- 	vim_item.dup = lvim.builtin.cmp.formatting.duplicates[entry.source.name]
-- 		or lvim.builtin.cmp.formatting.duplicates_default
-- 	return vim_item
-- end
-- table.insert(lvim.builtin.cmp.sources, { name = "copilot", group_index = 2 })
---------------------------

-- local status_ok, copilot = pcall(require, "copilot")
-- if not status_ok then
-- 	return
-- end

-- copilot.setup({
-- 	cmp = {
-- 		enabled = true,
-- 		method = "getCompletionsCycling",
-- 	},
-- 	panel = { -- no config options yet
-- 		enabled = true,
-- 	},
-- 	ft_disable = { "markdown" },
-- 	-- plugin_manager_path = vim.fn.stdpath "data" .. "/site/pack/packer",
-- 	server_opts_overrides = {
-- 		-- trace = "verbose",
-- 		settings = {
-- 			advanced = {
-- 				-- listCount = 10, -- #completions for panel
-- 				inlineSuggestCount = 3, -- #completions for getCompletions
-- 			},
-- 		},
-- 	},
-- })
