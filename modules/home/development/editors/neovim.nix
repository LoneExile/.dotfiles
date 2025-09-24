{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.modules.home.development.editors;
in {
  options.modules.home.development.editors.neovim = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Neovim";
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.neovim;
      description = "Neovim package to use";
    };

    defaultEditor = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Set Neovim as default editor";
    };

    extraConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Extra Neovim configuration";
    };

    plugins = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [];
      description = "Additional Neovim plugins";
    };
  };

  config = lib.mkIf (cfg.enable && cfg.neovim.enable) {
    # Neovim configuration
    programs.neovim = {
      enable = true;
      package = cfg.neovim.package;
      defaultEditor = cfg.neovim.defaultEditor;

      viAlias = true;
      vimAlias = true;
      vimdiffAlias = true;

      extraConfig = ''
        " Basic Neovim configuration
        set number
        set relativenumber
        set tabstop=2
        set shiftwidth=2
        set expandtab
        set smartindent
        set wrap
        set smartcase
        set noswapfile
        set nobackup
        set undodir=~/.vim/undodir
        set undofile
        set incsearch
        set scrolloff=8
        set colorcolumn=80
        set signcolumn=yes

        " Enable mouse support
        set mouse=a

        " Better search highlighting
        set hlsearch
        nnoremap <Esc> :nohlsearch<CR>

        " Leader key
        let mapleader = " "

        " Basic key mappings
        nnoremap <leader>w :w<CR>
        nnoremap <leader>q :q<CR>
        nnoremap <leader>x :x<CR>

        " Window navigation
        nnoremap <C-h> <C-w>h
        nnoremap <C-j> <C-w>j
        nnoremap <C-k> <C-w>k
        nnoremap <C-l> <C-w>l

        ${cfg.neovim.extraConfig}
      '';

      plugins = with pkgs.vimPlugins;
        [
          # Essential plugins
          vim-sensible
          vim-surround
          vim-commentary
          vim-repeat

          # File navigation
          telescope-nvim
          nvim-tree-lua

          # Git integration
          vim-fugitive
          gitsigns-nvim

          # Language support
          nvim-treesitter.withAllGrammars
          nvim-lspconfig

          # Completion
          nvim-cmp
          cmp-nvim-lsp
          cmp-buffer
          cmp-path

          # Snippets
          luasnip
          cmp_luasnip

          # UI enhancements
          lualine-nvim
          nvim-web-devicons

          # Theme
          catppuccin-nvim
        ]
        ++ cfg.neovim.plugins;
    };


  };
}