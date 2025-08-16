{ config, inputs, pkgs, lib, unstablePkgs, ... }:
let
  nvimConfig = pkgs.fetchFromGitHub {
    owner = "LoneExile";
    repo = "nvim";
    rev = "main";
    sha256 = "sha256-fc3VE/Uz/50hSXgiO8IpH6fI4oVBWJ9+GCv8fuo20pk=";
  };
in
{
  home.stateVersion = "23.11";


  # Development tools packages
  home.packages = with pkgs; [
    # Language runtimes and tools
    dotnet-sdk_8        # .NET SDK (latest LTS)
    elixir             # Elixir
    erlang             # Erlang
    go                 # Go (already in system packages, but adding here for user access)
    openjdk21          # Java (OpenJDK 21 LTS)
    lua                # Lua
    nodejs             # Node.js (uses overlay from helpers.nix)
    python3            # Python 3
    rustc              # Rust compiler
    cargo              # Rust package manager
    uv                 # Python package installer
    neovim             # Neovim nightly (from overlay)
  ];

  # list of programs
  # https://mipmip.github.io/home-manager-option-search

  # aerospace config and nvim config
  home.file = lib.mkMerge [
    {
      # Copy nvim configuration from GitHub (writable)
      ".config/nvim" = {
        source = nvimConfig;
        recursive = true;
        # Make files writable by copying instead of symlinking
        onChange = ''
          if [ -L ~/.config/nvim ]; then
            rm ~/.config/nvim
            cp -r ${nvimConfig} ~/.config/nvim
            chmod -R +w ~/.config/nvim
          fi
        '';
      };
    }
    (lib.mkIf pkgs.stdenv.isDarwin {
      ".config/aerospace/aerospace.toml".text = builtins.readFile ./aerospace/aerospace.toml;
      ".config/wezterm/wezterm.lua".text = builtins.readFile ./wezterm/wezterm.lua;
      # ".config/tmux/tmux.conf".text = builtins.readFile ./tmux/tmux.conf;
      ".zshrc".text = builtins.readFile ./zsh/zshrc;
      ".config/zsh/aliases.zsh".text = builtins.readFile ./zsh/config/aliases.zsh;
      ".config/zsh/keybindings.zsh".text = builtins.readFile ./zsh/config/keybindings.zsh;
      ".config/zsh/options.zsh".text = builtins.readFile ./zsh/config/options.zsh;
      "Library/Application Support/MTMR/items.json".text = builtins.readFile ./mtmr/items.json;
      "Library/Keyboard\ Layouts/English.bundle".source = ./keyboard-layouts/English.bundle;
      "Library/Keyboard\ Layouts/Thai.bundle".source = ./keyboard-layouts/Thai.bundle;
    })
  ];

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
    userEmail = "Hello@Apinant.dev";
    userName = "Apinant U-suwantim";
    diff-so-fancy.enable = true;
    lfs.enable = true;
    extraConfig = {
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
    enableCompletion = true;
    autosuggestion.enable = true;
    #initExtra = (builtins.readFile ../mac-dot-zshrc);
  };

  programs.tmux = {
    enable = true;
    #keyMode = "vi";
    # clock24 = true;
    # historyLimit = 10000;
    plugins = with pkgs.tmuxPlugins; [
      # gruvbox
      vim-tmux-navigator
      sensible
      pain-control
      open
      copycat
      resurrect
      continuum
      cpu
      battery
    ];
    extraConfig = ''
      new-session -s main
      unbind C-b
      bind-key -n C-a send-prefix
      set -g base-index 1
      set -g mouse on
      set-option -g mouse on

      setw -g xterm-keys on
      set -g default-terminal "tmux-256color"
      set-option -g default-terminal "screen-256color"
      set -g default-terminal "screen-256color"
      set-option -sa terminal-features ',xterm-256color:RGB'

      unbind-key n
      unbind-key e
      unbind-key y
      unbind-key o

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

      # set -g default-shell /bin/zsh
      set -g default-shell "$SHELL"
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
}
