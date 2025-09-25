-- UI and Navigation Plugins Configuration
-- This file contains configuration for UI-related plugins

-- Load UI plugins with lze
  require('lze').load {
    {
      "nvim-treesitter",
      enabled = nixCats('general') or false,
      event = "DeferredUIEnter",
      load = function (name)
          vim.cmd.packadd(name)
          vim.cmd.packadd("nvim-treesitter-textobjects")
      end,
      after = function (plugin)
        -- [[ Configure Treesitter ]]
        -- See `:help nvim-treesitter`
        require('nvim-treesitter.configs').setup {
          highlight = { enable = true, },
          indent = { enable = false, },
          incremental_selection = {
            enable = true,
            keymaps = {
              init_selection = '<c-space>',
              node_incremental = '<c-space>',
              scope_incremental = '<c-s>',
              node_decremental = '<M-space>',
            },
          },
          textobjects = {
            select = {
              enable = true,
              lookahead = true, -- Automatically jump forward to textobj, similar to targets.vim
              keymaps = {
                -- You can use the capture groups defined in textobjects.scm
                ['aa'] = '@parameter.outer',
                ['ia'] = '@parameter.inner',
                ['af'] = '@function.outer',
                ['if'] = '@function.inner',
                ['ac'] = '@class.outer',
                ['ic'] = '@class.inner',
              },
            },
            move = {
              enable = true,
              set_jumps = true, -- whether to set jumps in the jumplist
              goto_next_start = {
                [']m'] = '@function.outer',
                [']]'] = '@class.outer',
              },
              goto_next_end = {
                [']M'] = '@function.outer',
                [']['] = '@class.outer',
              },
              goto_previous_start = {
                ['[m'] = '@function.outer',
                ['[['] = '@class.outer',
              },
              goto_previous_end = {
                ['[M'] = '@function.outer',
                ['[]'] = '@class.outer',
              },
            },
            -- swap = {
            --   enable = true,
            --   swap_next = {
            --     ['<leader>a'] = '@parameter.inner',
            --   },
            --   swap_previous = {
            --     ['<leader>A'] = '@parameter.inner',
            --   },
            -- },
          },
        }
      end,
    },
    {
      "mini.nvim",
      enabled = nixCats('general') or false,
      event = "DeferredUIEnter",
      after = function (plugin)
        require('mini.pairs').setup()
        require('mini.icons').setup()
        require('mini.ai').setup()
      end,
    },
    {
      "vim-startuptime",
      enabled = nixCats('general') or false,
      cmd = { "StartupTime" },
      before = function(_)
        vim.g.startuptime_event_width = 0
        vim.g.startuptime_tries = 10
        vim.g.startuptime_exe_path = nixCats.packageBinPath
      end,
    },
    {
      "lualine.nvim",
      enabled = nixCats('general') or false,
      event = "DeferredUIEnter",
      load = function (name)
        vim.cmd.packadd(name)
        vim.cmd.packadd("lualine-lsp-progress")
      end,
      after = function (plugin)
        require('lualine').setup({
          options = {
            icons_enabled = true,
            theme = 'tokyonight',
            component_separators = '|',
            section_separators = '',
          },
          -- sections = {
          --   lualine_c = {
          --     {
          --       'filename', path = 1, status = true,
          --     },
          --   },
          -- },
          -- inactive_sections = {
          --   lualine_b = {
          --     {
          --       'filename', path = 3, status = true,
          --     },
          --   },
          --   lualine_x = {'filetype'},
          -- },
          -- tabline = {
          --   lualine_a = { 'buffers' },
          --   lualine_b = { 'lsp_progress', },
          --   lualine_z = { 'tabs' }
          -- },
          winbar = nil,
          inactive_sections = nil,
          sections = nil,
        })
      end,
    },
    {
      "gitsigns.nvim",
      enabled = nixCats('general') or false,
      event = "DeferredUIEnter",
      after = function (plugin)
        require('gitsigns').setup({
          -- See `:help gitsigns.txt`
          signs = {
            add = { text = '+' },
            change = { text = '~' },
            delete = { text = '_' },
            topdelete = { text = '‾' },
            changedelete = { text = '~' },
          },
          on_attach = function(bufnr)
            local gs = package.loaded.gitsigns

            local function map(mode, l, r, opts)
              opts = opts or {}
              opts.buffer = bufnr
              vim.keymap.set(mode, l, r, opts)
            end

            -- Navigation
            -- map({ 'n', 'v' }, ']c', function()
            --   if vim.wo.diff then
            --     return ']c'
            --   end
            --   vim.schedule(function()
            --     gs.next_hunk()
            --   end)
            --   return '<Ignore>'
            -- end, { expr = true, desc = 'Jump to next hunk' })

            -- map({ 'n', 'v' }, '[c', function()
            --   if vim.wo.diff then
            --     return '[c'
            --   end
            --   vim.schedule(function()
            --     gs.prev_hunk()
            --   end)
            --   return '<Ignore>'
            -- end, { expr = true, desc = 'Jump to previous hunk' })

            -- -- Actions
            -- -- visual mode
            -- map('v', '<leader>hs', function()
            --   gs.stage_hunk { vim.fn.line '.', vim.fn.line 'v' }
            -- end, { desc = 'stage git hunk' })
            -- map('v', '<leader>hr', function()
            --   gs.reset_hunk { vim.fn.line '.', vim.fn.line 'v' }
            -- end, { desc = 'reset git hunk' })
            -- -- normal mode
            -- map('n', '<leader>gs', gs.stage_hunk, { desc = 'git stage hunk' })
            -- map('n', '<leader>gr', gs.reset_hunk, { desc = 'git reset hunk' })
            -- map('n', '<leader>gS', gs.stage_buffer, { desc = 'git Stage buffer' })
            -- map('n', '<leader>gu', gs.undo_stage_hunk, { desc = 'undo stage hunk' })
            -- map('n', '<leader>gR', gs.reset_buffer, { desc = 'git Reset buffer' })
            -- map('n', '<leader>gp', gs.preview_hunk, { desc = 'preview git hunk' })
            -- map('n', '<leader>gb', function()
            --   gs.blame_line { full = false }
            -- end, { desc = 'git blame line' })
            -- map('n', '<leader>gd', gs.diffthis, { desc = 'git diff against index' })
            -- map('n', '<leader>gD', function()
            --   gs.diffthis '~'
            -- end, { desc = 'git diff against last commit' })

            -- -- Toggles
            -- map('n', '<leader>gtb', gs.toggle_current_line_blame, { desc = 'toggle git blame line' })
            -- map('n', '<leader>gtd', gs.toggle_deleted, { desc = 'toggle git show deleted' })

            -- -- Text object
            -- map({ 'o', 'x' }, 'ih', ':<C-U>Gitsigns select_hunk<CR>', { desc = 'select git hunk' })
          end,
        })
        vim.cmd([[hi GitSignsAdd guifg=#04de21]])
        vim.cmd([[hi GitSignsChange guifg=#83fce6]])
        vim.cmd([[hi GitSignsDelete guifg=#fa2525]])
      end,
    },
    {
      "which-key.nvim",
      enabled = nixCats('general') or false,
      event = "DeferredUIEnter",
      after = function (plugin)
        require('which-key').setup({})
        -- require('which-key').add {
        --   { "<leader><leader>", group = "buffer commands" },
        --   { "<leader><leader>_", hidden = true },
        --   { "<leader>c", group = "[c]ode" },
        --   { "<leader>c_", hidden = true },
        --   { "<leader>d", group = "[d]ocument" },
        --   { "<leader>d_", hidden = true },
        --   { "<leader>g", group = "[g]it" },
        --   { "<leader>g_", hidden = true },
        --   { "<leader>r", group = "[r]ename" },
        --   { "<leader>r_", hidden = true },
        --   { "<leader>f", group = "[f]ind" },
        --   { "<leader>f_", hidden = true },
        --   { "<leader>s", group = "[s]earch" },
        --   { "<leader>s_", hidden = true },
        --   { "<leader>t", group = "[t]oggles" },
        --   { "<leader>t_", hidden = true },
        --   { "<leader>w", group = "[w]orkspace" },
        --   { "<leader>w_", hidden = true },
        -- }
      end,
    },
  }