-- Init file of the user service mason-lsp-install (home/linux/mason-lsp-install.sh), handed to nvim with
-- `-u`. It loads mason.nvim and nothing else: the runtime path is mason.nvim and Neovim's own runtime,
-- so a config in ~/.config/nvim, a plugin in ~/.local/share/nvim/site and anything else of a Neovim
-- that the user may set up later is neither read nor run, and nothing is written outside Mason's own
-- directories (stdpath("data")/mason, the log and the registry timestamp).
-- The service sets MASON_NVIM to the Nix store path of mason.nvim.
local mason = assert(vim.env.MASON_NVIM, "MASON_NVIM is not set")
vim.opt.runtimepath = { mason, vim.env.VIMRUNTIME }
vim.opt.packpath = {}
require("mason").setup()
