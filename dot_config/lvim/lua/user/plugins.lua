-- Additional Plugins
lvim.plugins = {
  -- theme
  { "folke/tokyonight.nvim" },

  -- debugger
  { "rcarriga/nvim-dap-ui" },
  -- { "Pocco81/dap-buddy.nvim" },
  { "theHamsta/nvim-dap-virtual-text" },
  { "leoluz/nvim-dap-go" },
  { "nvim-telescope/telescope-dap.nvim" },
  { "mfussenegger/nvim-dap-python" },

  -- LSP
  { "glepnir/lspsaga.nvim",
    branch = "main",
    config = function()
      local saga = require("lspsaga")

      saga.init_lsp_saga({
        -- your configuration
      })
    end, },

  -- utility
  { "unblevable/quick-scope" }, -- jumpy but in line
  --
  {
    "folke/trouble.nvim",
    cmd = "TroubleToggle",
  },
  {
    "norcalli/nvim-colorizer.lua"
  }
}
