{ config, lib, pkgs, ... }:
let
  cfg = config.modules.home.development.editors;
in {
  options.modules.home.development.editors = {
    enable = lib.mkEnableOption "Development editors configuration";
    
    neovim = {
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

    vscode = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Visual Studio Code";
      };

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.vscode;
        description = "VS Code package to use";
      };

      extensions = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [];
        description = "VS Code extensions to install";
      };
    };

    helix = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Helix editor";
      };

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.helix;
        description = "Helix package to use";
      };
    };
  };
  
  config = lib.mkIf cfg.enable {
    # Neovim configuration
    programs.neovim = lib.mkIf cfg.neovim.enable {
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

      plugins = with pkgs.vimPlugins; [
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
      ] ++ cfg.neovim.plugins;
    };

    # VS Code configuration
    programs.vscode = lib.mkIf cfg.vscode.enable {
      enable = true;
      package = cfg.vscode.package;
      extensions = cfg.vscode.extensions;
      
      userSettings = {
        "editor.fontSize" = 14;
        "editor.fontFamily" = "'JetBrains Mono', 'Fira Code', monospace";
        "editor.fontLigatures" = true;
        "editor.tabSize" = 2;
        "editor.insertSpaces" = true;
        "editor.wordWrap" = "on";
        "editor.minimap.enabled" = false;
        "editor.rulers" = [80 120];
        "workbench.colorTheme" = "Catppuccin Mocha";
        "terminal.integrated.fontSize" = 14;
        "terminal.integrated.fontFamily" = "'JetBrains Mono'";
      };
    };

    # Helix configuration
    programs.helix = lib.mkIf cfg.helix.enable {
      enable = true;
      package = cfg.helix.package;
      
      settings = {
        theme = "catppuccin_mocha";
        
        editor = {
          line-number = "relative";
          mouse = true;
          cursor-shape = {
            insert = "bar";
            normal = "block";
            select = "underline";
          };
          
          file-picker = {
            hidden = false;
          };
          
          auto-save = true;
          
          indent-guides = {
            render = true;
            character = "┊";
          };
        };
        
        keys.normal = {
          space.w = ":w";
          space.q = ":q";
          space.x = ":wq";
        };
      };
    };

    # Add editor packages to home.packages
    home.packages = lib.mkMerge [
      (lib.mkIf cfg.neovim.enable [ cfg.neovim.package ])
      (lib.mkIf cfg.vscode.enable [ cfg.vscode.package ])
      (lib.mkIf cfg.helix.enable [ cfg.helix.package ])
    ];
  };
}