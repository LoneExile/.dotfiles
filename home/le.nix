{
  config,
  inputs,
  pkgs,
  lib,
  unstablePkgs,
  ...
}: {
  home.stateVersion = "25.11";

  # Import nixCats home module
  imports = [
    inputs.nixCats.homeModule
  ];

  # Development tools packages
  home.packages = with pkgs; [
    terraform
    neovim
    dua
    unstablePkgs.duf

    unstablePkgs.mise
    unstablePkgs.lazygit
    unstablePkgs.pgformatter
    unstablePkgs.pngpaste
    unstablePkgs.tree-sitter
    #julia
    unstablePkgs.ripgrep
    unstablePkgs.ripgrep-all
    unstablePkgs.lynx
    unstablePkgs.xmlformat
    # unstablePkgs.terragrunt
    unstablePkgs.nixpkgs-fmt
    unstablePkgs.wget
    unstablePkgs.nmap
    unstablePkgs.cloudflared
    unstablePkgs.gnutar
    unstablePkgs.gnused
    unstablePkgs.gawk
    unstablePkgs.gnugrep
    unstablePkgs.git-filter-repo

    # terragrunt
  ];

  # Previous editors module configuration (commented out for nixCats migration)
  # Custom settings preserved for migration to nixCats:
  # - number, relativenumber, tabstop=2, shiftwidth=2, expandtab
  # - wrap, linebreak
  # - colorscheme catppuccin-mocha
  # - plugins: vim-airline, nerdtree
  # - defaultEditor = true
  #
  # modules.home.development.editors = {
  #   enable = true;
  #   neovim = {
  #     enable = true;
  #     defaultEditor = true;
  #     extraConfig = ''
  #       " Personal Neovim configuration
  #       set number
  #       set relativenumber
  #       set tabstop=2
  #       set shiftwidth=2
  #       set expandtab
  #
  #       " Personal preferences
  #       set wrap
  #       set linebreak
  #       colorscheme catppuccin-mocha
  #     '';
  #     plugins = with pkgs.vimPlugins; [
  #       # Add any personal plugins here
  #       vim-airline
  #       nerdtree
  #     ];
  #   };
  #
  #   # Optionally enable other editors
  #   vscode.enable = false; # VS Code is installed via Homebrew cask
  #   helix.enable = false; # Not needed for this setup
  # };

  # list of programs
  # https://mipmip.github.io/home-manager-option-search

  # aerospace config and nvim config
  home.file = lib.mkMerge [
    (lib.mkIf pkgs.stdenv.isDarwin {
      ".config/aerospace/aerospace.toml".text = builtins.readFile ./aerospace/aerospace.toml;
      ".config/wezterm/wezterm.lua".text = builtins.readFile ./wezterm/wezterm.lua;
      # ".config/tmux/tmux.conf".text = builtins.readFile ./tmux/tmux.conf;
      ".config/zsh/aliases.zsh".text = builtins.readFile ./zsh/config/aliases.zsh;
      ".config/zsh/keybindings.zsh".text = builtins.readFile ./zsh/config/keybindings.zsh;
      ".config/zsh/options.zsh".text = builtins.readFile ./zsh/config/options.zsh;
      "Library/Application Support/MTMR/items.json".text = builtins.readFile ./mtmr/items.json;
      "Library/Keyboard\ Layouts/English.bundle" = {
        source = ./keyboard-layouts/English.bundle;
        recursive = true;
      };
      "Library/Keyboard\ Layouts/Thai.bundle" = {
        source = ./keyboard-layouts/Thai.bundle;
        recursive = true;
      };
    })
  ];

  # home.activation.myCustomScript = lib.hm.dag.entryAfter ["writeBoundary"] ''
  #   echo "Hello, this runs after home-manager switch!"
  #   # Place your script/commands here
  # '';

  # programs.aerospace = {
  #   enable = true;
  #   userSettings = {
  #     start-at-login = true;
  #   };
  # };

  programs.gpg.enable = true;

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    mise.enable = true;
  };

  programs.mise = {
    enable = true;
    enableZshIntegration = true;
    enableBashIntegration = true;
    globalConfig = {
      tools = {
        dotnet = "latest";
        elixir = "latest";
        erlang = "latest";
        go = "latest";
        java = "latest";
        lua = "latest";
        node = "latest";
        python = "3";
        rust = "latest";
        uv = "latest";
        pnpm = "latest";
        yarn = "latest";
        deno = "latest";
        bun = "latest";
      };
      settings = {
        not_found_auto_install = true;
        plugin_autoupdate_last_check_duration = "0";
        idiomatic_version_file_enable_tools = [];
      };
    };
  };

  programs.eza = {
    enable = true;
    enableZshIntegration = true;
    icons = "auto";
    git = true;
    extraOptions = [
      "--group-directories-first"
      "--header"
      "--color=auto"
    ];
  };

  programs.fzf = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    tmux.enableShellIntegration = true;
    defaultOptions = [
      "--no-mouse"
    ];
  };

  programs.git = {
    enable = true;
    settings = {
      user = {
        email = "Hello@Apinant.dev";
        name = "Apinant U-suwantim";
      };
      diff-so-fancy = {
        enable = true;
      };
      lfs = {
        enable = true;
      };
      init = {
        defaultBranch = "main";
      };
      merge = {
        conflictStyle = "diff3";
        tool = "meld";
      };
      pull = {
        rebase = true;
      };
    };
  };

  programs.htop = {
    enable = true;
    settings.show_program_path = true;
  };

  programs.lf.enable = true;

  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    enableBashIntegration = true;
    settings = pkgs.lib.importTOML ./starship/starship.toml;
  };

  programs.bash.enable = true;

  programs.zsh = {
    enable = true;
    # enableCompletion = true;
    # autosuggestion.enable = true;
    initContent = builtins.readFile ./zsh/zshrc;
  };

  programs.tmux = {
    enable = true;
    #keyMode = "vi";
    # clock24 = true;
    # historyLimit = 10000;
    prefix = "C-a";
    plugins = with pkgs.tmuxPlugins; [
      # gruvbox
      vim-tmux-navigator
      # sensible
      pain-control
      open
      copycat
      resurrect
      continuum
      cpu
      battery
      vim-tmux-navigator
    ];
    extraConfig = ''
      new-session -s main
      set -g base-index 1
      set -g mouse on
      set-option -g mouse on

      setw -g xterm-keys on
      set -g default-terminal "tmux-256color"
      set-option -g default-terminal "screen-256color"
      set -g default-terminal "screen-256color"
      set-option -sa terminal-features ',xterm-256color:RGB'
      set-option -g focus-events on
      set-option -sg escape-time 10

      unbind-key n
      unbind-key e
      unbind-key y
      unbind-key o

      set-window-option -g mode-keys vi
      bind-key -T copy-mode-vi v send -X begin-selection
      bind-key -T copy-mode-vi V send -X select-line
      set -s copy-command 'pbcopy'
      bind-key -T copy-mode-vi y send -X copy-pipe-and-cancel 'pbcopy'

      set -g status-justify "left"
      set -g status "on"
      set -g status-style "none"
      set -g message-command-style "bg=colour31"
      set -g status-left-length "100"
      set -g pane-active-border-style "fg=colour254"
      set -g message-command-style "fg=colour231"
      set -g pane-border-style "fg=colour240"
      set -g message-style "bg=colour31"
      set -g status-left-style "none"
      set -g status-right-style "none"
      set -g status-right-length "100"
      set -g message-style "fg=colour231"
      setw -g window-status-style "fg=colour250,bg=default,none"
      setw -g window-status-activity-style "fg=colour250,bg=default,none"
      setw -g window-status-separator ""
      set -g status-left "#[fg=colour16,bg=colour254,bold] #S #[fg=colour254,bg=default,nobold,nounderscore,noitalics]"
      set -g status-right ""
      setw -g window-status-format "#[fg=colour244,bg=default] #I #[fg=colour250,bg=default] #W#{?window_zoomed_flag,[Z],} "
      setw -g window-status-current-format "#[fg=colour234,bg=colour31,nobold,nounderscore,noitalics]#[fg=colour117,bg=colour31] #I #[fg=colour231,bg=colour31,bold] #W#{?window_zoomed_flag,[Z],} #[fg=colour31,bg=default,nobold,nounderscore,noitalics]"
      set -g status-position top

      set -g default-shell /bin/zsh
    '';
  };

  programs.home-manager.enable = true;
  programs.nix-index.enable = true;

  # programs.alacritty.enable = true;

  programs.bat.enable = true;
  programs.bat.config.theme = "Nord";
  #programs.zsh.shellAliases.cat = "${pkgs.bat}/bin/bat";

  programs.zoxide.enable = true;

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    extraConfig = ''
      StrictHostKeyChecking no
    '';
    matchBlocks = {
      # ~/.ssh/config
      "github.com" = {
        hostname = "ssh.github.com";
        port = 443;
      };
      "*" = {
        user = "root";
      };
    };
  };

  # nixCats configuration
  nixCats = let
    tokyonight-latest = pkgs.vimUtils.buildVimPlugin {
      name = "tokyonight-nvim";
      src = inputs.tokyonight-nvim;
      # Skip the require check that's failing
      doCheck = false;
    };
    # tokyonight-latest = pkgs.vimUtils.buildVimPlugin {
    #   name = "tokyonight-nvim";
    #   src = pkgs.fetchFromGitHub {
    #     owner = "folke";
    #     repo = "tokyonight.nvim";
    #     rev = "14fd5ff7f84027064724ec3157fe903199e77ded"; # v4.12.0
    #     hash = "sha256-fj6x7R11+s0/lhWCe0s3ELTRLgvU25Rjp4M5vZw5i3c=";
    #   };
    #   # Skip the require check that's failing
    #   doCheck = false;
    # };
  in {
    enable = true;
    addOverlays = [(inputs.nixCats.utils.standardPluginOverlay inputs)];
    packageNames = ["leNvim"];
    luaPath = ./nvim-config;

    categoryDefinitions.replace = {
      pkgs,
      settings,
      categories,
      name,
      ...
    }: {
      # LSPs, formatters, linters, and runtime dependencies
      lspsAndRuntimeDeps = with pkgs; {
        general = [
          # Essential tools
          lazygit
          ripgrep
          fd
          tree-sitter
        ];
        lua = [
          lua-language-server
          stylua
        ];
        nix = [
          nixd
          alejandra
        ];
        go = [
          gopls
          golangci-lint
          delve
        ];
      };

      # Essential plugins loaded at startup
      startupPlugins = with unstablePkgs.vimPlugins; {
        general = [
          # Core functionality
          plenary-nvim
          nvim-treesitter.withAllGrammars
          nvim-treesitter-textobjects

          # Plugin loader and extras
          lze
          lzextras
          snacks-nvim

          # UI and navigation
          lualine-nvim
          lualine-lsp-progress
          mini-nvim
          which-key-nvim

          # Colorscheme (latest from GitHub)
          tokyonight-latest

          # Git integration
          gitsigns-nvim

          # Completion
          blink-cmp

          # Development tools
          vim-startuptime
        ];
      };

      # Language-specific and optional plugins
      optionalPlugins = with unstablePkgs.vimPlugins; {
        general = [
          # LSP and development tools
          nvim-lspconfig
          nvim-lint
          conform-nvim

          # Debugging
          nvim-dap
          nvim-dap-ui
          nvim-dap-virtual-text
        ];
        lua = [
          lazydev-nvim
        ];
        nix = [
          # Nix-specific plugins if needed
        ];
        go = [
          nvim-dap-go
        ];
      };
    };

    packageDefinitions.replace = {
      leNvim = {
        pkgs,
        name,
        ...
      }: {
        settings = {
          suffix-path = true;
          suffix-LD = true;
          wrapRc = true;
          aliases = ["nvim-nix"];
          hosts.python3.enable = true;
          hosts.node.enable = true;
        };
        categories = {
          general = true;
          lua = true;
          nix = true;
          go = true; # Enable Go support based on mise configuration
        };
        extra = {
          nixdExtras.nixpkgs = ''import ${pkgs.path} {}'';
        };
      };
    };
  };
}
