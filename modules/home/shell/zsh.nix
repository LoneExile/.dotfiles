{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.modules.home.shell.zsh;
in {
  options.modules.home.shell.zsh = {
    enable = lib.mkEnableOption "Zsh shell configuration";

    enableAutosuggestions = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable zsh autosuggestions";
    };

    enableSyntaxHighlighting = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable zsh syntax highlighting";
    };

    enableCompletion = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable zsh completion system";
    };

    historySize = lib.mkOption {
      type = lib.types.int;
      default = 10000;
      description = "Number of commands to keep in history";
    };

    enableZap = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Zap plugin manager";
    };

    extraConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Extra configuration to add to zshrc";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.zsh = {
      enable = true;
      enableCompletion = cfg.enableCompletion;
      autosuggestion.enable = cfg.enableAutosuggestions;
      syntaxHighlighting.enable = cfg.enableSyntaxHighlighting;

      history = {
        size = cfg.historySize;
        save = cfg.historySize;
        ignoreDups = true;
        ignoreSpace = true;
        extended = true;
      };

      # Zsh options for better UX
      setOptions = [
        "CORRECT" # Auto correct mistakes
        "EXTENDED_GLOB" # Extended globbing with regular expressions
        "NO_CASE_GLOB" # Case insensitive globbing
        "RC_EXPAND_PARAM" # Array expansion with parameters
        "NO_CHECK_JOBS" # Don't warn about running processes when exiting
        "NUMERIC_GLOB_SORT" # Sort filenames numerically when it makes sense
        "NO_BEEP" # No beep
        "APPEND_HISTORY" # Immediately append history instead of overwriting
        "HIST_IGNORE_ALL_DUPS" # If a new command is a duplicate, remove the older one
        "AUTO_CD" # If only directory path is entered, cd there
        "INC_APPEND_HISTORY" # Save commands immediately to history
        "HIST_IGNORE_SPACE" # Don't save commands that start with space
      ];

      # Key bindings for better navigation
      initExtra = ''
        # Keybindings
        bindkey -e
        bindkey '^[[7~' beginning-of-line                               # Home key
        bindkey '^[[H' beginning-of-line                                # Home key
        if [[ "''${terminfo[khome]}" != "" ]]; then
            bindkey "''${terminfo[khome]}" beginning-of-line                # [Home] - Go to beginning of line
        fi
        bindkey '^[[8~' end-of-line                                     # End key
        bindkey '^[[F' end-of-line                                     # End key
        if [[ "''${terminfo[kend]}" != "" ]]; then
            bindkey "''${terminfo[kend]}" end-of-line                       # [End] - Go to end of line
        fi
        bindkey '^[[2~' overwrite-mode                                  # Insert key
        bindkey '^[[3~' delete-char                                     # Delete key
        bindkey '^[[C'  forward-char                                    # Right key
        bindkey '^[[D'  backward-char                                   # Left key
        bindkey '^[[5~' history-beginning-search-backward               # Page up key
        bindkey '^[[6~' history-beginning-search-forward                # Page down key

        # Navigate words with ctrl+arrow keys
        bindkey '^[Oc' forward-word                                     #
        bindkey '^[Od' backward-word                                    #
        bindkey '^[[1;5D' backward-word                                 #
        bindkey '^[[1;5C' forward-word                                  #
        bindkey '^H' backward-kill-word                                 # delete previous word with ctrl+backspace
        bindkey '^[[Z' undo                                             # Shift+tab undo last action

        # Completion styling
        zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'       # Case insensitive tab completion
        zstyle ':completion:*' rehash true                              # automatically find new executables in path
        # Speed up completions
        zstyle ':completion:*' accept-exact '*(N)'
        zstyle ':completion:*' use-cache on
        zstyle ':completion:*' cache-path ~/.zsh/cache
        zstyle ':completion:*' list-colors "''${(s.:.)LS_COLORS}"         # Colored completion (different colors for dirs/files/etc)

        # Editor configuration
        nvim_path=$(which nvim 2>/dev/null || echo "nvim")
        export EDITOR="$nvim_path"
        export VISUAL="$nvim_path"

        # Color man pages
        export LESS_TERMCAP_mb=$'\E[01;32m'
        export LESS_TERMCAP_md=$'\E[01;32m'
        export LESS_TERMCAP_me=$'\E[0m'
        export LESS_TERMCAP_se=$'\E[0m'
        export LESS_TERMCAP_so=$'\E[01;47;34m'
        export LESS_TERMCAP_ue=$'\E[0m'
        export LESS_TERMCAP_us=$'\E[01;36m'
        export LESS=-R

        # File and Dir colors for ls and other outputs
        export LS_OPTIONS='--color=auto'
        alias ls='ls $LS_OPTIONS'

        # Auto-source .env files when changing directories
        : ''${ZSH_DOTENV_FILE:=".env"}
        source_env_file() {
          if [[ -f "''${ZSH_DOTENV_FILE}" ]]; then
            >&2 echo "Auto-sourcing ''${ZSH_DOTENV_FILE} file"
            source "''${ZSH_DOTENV_FILE}"
          fi
        }
        autoload -U add-zsh-hook
        add-zsh-hook chpwd source_env_file

        # AWS CLI completion
        if [[ -x "$(command -v aws_completer)" ]]; then
          compdef _aws aws
          function _aws {
            local IFS=$'\n'
            compadd -- "$(aws_completer "$@")"
          }
          compdef _aws aws-vault
          compdef _aws sudo
        fi

        # Kubectl completion
        [[ ''${commands[kubectl]} ]] && source <(kubectl completion zsh)

        # pnpm configuration
        export PNPM_HOME="$HOME/Library/pnpm"
        case ":$PATH:" in
          *":$PNPM_HOME:"*) ;;
          *) export PATH="$PNPM_HOME:$PATH" ;;
        esac

        ${lib.optionalString cfg.enableZap ''
          # Zap plugin manager setup
          if [ ! -f "''${XDG_DATA_HOME:-$HOME/.local/share}/zap/zap.zsh" ]; then
            zsh <(curl -s https://raw.githubusercontent.com/zap-zsh/zap/master/install.zsh) --branch release-v1 --keep
          fi
          [ -f "''${XDG_DATA_HOME:-$HOME/.local/share}/zap/zap.zsh" ] && source "''${XDG_DATA_HOME:-$HOME/.local/share}/zap/zap.zsh"

          # Zap plugins
          plug "zsh-users/zsh-syntax-highlighting"
          plug "zsh-users/zsh-autosuggestions"
          plug "zsh-users/zsh-completions"
          plug "zsh-users/zsh-history-substring-search"
          plug "Aloxaf/fzf-tab"
          plug "Freed-Wu/fzf-tab-source"
        ''}

        ${cfg.extraConfig}
      '';
    };

    # Additional shell tools integration
    programs.fzf = {
      enable = true;
      enableZshIntegration = true;
      tmux.enableShellIntegration = true;
      defaultOptions = [
        "--no-mouse"
      ];
    };

    programs.zoxide = {
      enable = true;
      enableZshIntegration = true;
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

    # Create config files for zsh plugins
    home.file = {
      ".config/zsh/aliases.zsh".text =
        if config.modules.home.shell.aliases.enable
        then "# Aliases managed by aliases.nix module"
        else builtins.readFile ../../../home/zsh/config/aliases.zsh;

      ".config/zsh/keybindings.zsh".text = builtins.readFile ../../../home/zsh/config/keybindings.zsh;
      ".config/zsh/options.zsh".text = builtins.readFile ../../../home/zsh/config/options.zsh;
    };
  };
}
