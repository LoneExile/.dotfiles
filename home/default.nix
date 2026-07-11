{
  config,
  inputs,
  pkgs,
  lib,
  unstablePkgs,
  ...
}: {
  home.stateVersion = "25.11";

  # Development tools packages
  home.packages = with pkgs; [
    terraform
    neovim
    dua
    unstablePkgs.duf

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
        "npm:pnpm" = "latest";
        yarn = "latest";
        deno = "latest";
        bun = "latest";
        herdr = "latest";
        gup = "latest";
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
    # We run compinit ourselves in zshrc (cached, daily) — HM's default
    # `autoload -U compinit && compinit` is uncached and slower.
    enableCompletion = false;
    # Early bailout must run before tools that need a TTY (order 500),
    # so non-interactive shells (omp ! commands, CI, scripted `zsh -i`)
    initContent = lib.mkMerge [
      (lib.mkOrder 500 ''
        # Non-TTY / agent path (omp ! commands, CI, scripted zsh -i)
        if [[ ! -t 0 || ! -t 1 ]]; then
          export PATH="$HOME/.local/bin:$HOME/.bun/bin:$HOME/bin:/opt/homebrew/opt/libpq/bin:/opt/homebrew/opt/postgresql@18/bin:$PATH"
          export PNPM_HOME="$HOME/Library/pnpm"
          case ":$PATH:" in
            *":$PNPM_HOME/bin:"*) ;;
            *) export PATH="$PNPM_HOME/bin:$PATH" ;;
          esac
          [[ -x "$(command -v mise)" ]] && eval "$(mise activate zsh)" 2>/dev/null || true
          return 2>/dev/null || true
        fi
      '')
      (lib.mkOrder 1000 (builtins.readFile ./zsh/zshrc))
    ];
    # mise activates only in interactive shells (.zshrc). Login/non-interactive
    # shells (`zsh -lc`) used by GUI apps — e.g. ZenNotes' Raycast/CLI installer
    # probing for node/npm — skip .zshrc, so expose mise's shims here too.
    profileExtra = ''
      export PATH="$HOME/.local/share/mise/shims:$PATH"
    '';
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
  programs.nix-index.enable = false;

  # programs.alacritty.enable = true;

  programs.bat.enable = true;
  programs.bat.config.theme = "Nord";
  #programs.zsh.shellAliases.cat = "${pkgs.bat}/bin/bat";

  programs.zoxide.enable = true;

  programs.k9s = {
    enable = true;
    settings = {
      k9s = {
        ui = {
          headless = true;
          logoless = true;
          skin = "transparent";
        };
      };
    };
    skins = {
      transparent = {
        k9s = {
          body.bgColor = "default";
          prompt.bgColor = "default";
          info.sectionColor = "default";
          dialog = {
            bgColor = "default";
            labelFgColor = "default";
            fieldFgColor = "default";
          };
          frame = {
            crumbs.bgColor = "default";
            title = {
              bgColor = "default";
              counterColor = "default";
            };
            menu.fgColor = "default";
          };
          views = {
            charts.bgColor = "default";
            table = {
              bgColor = "default";
              header = {
                fgColor = "default";
                bgColor = "default";
              };
            };
            xray.bgColor = "default";
            logs = {
              bgColor = "default";
              indicator = {
                bgColor = "default";
                toggleOnColor = "default";
                toggleOffColor = "default";
              };
            };
            yaml = {
              colonColor = "default";
              valueColor = "default";
            };
          };
        };
      };
    };
  };

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings = {
      # Global defaults (Host *)
      "*" = {
        User = "root";
        StrictHostKeyChecking = "no";
      };

      # ~/.ssh/config
      "github.com" = {
        HostName = "ssh.github.com";
        Port = 443;
      };

      ## office
      "jumphost_server" = {
        HostName = "192.168.50.29";
        User = "jumphost";
        IdentityFile = "~/.ssh/id_ed25519_unit_px";
      };
      "jumphost_server_lab" = {
        HostName = "192.168.50.12";
        User = "ubuntu";
        IdentityFile = "~/.ssh/id_crypt";
      };
      "th-dc" = {
        HostName = "10.159.0.63";
        User = "root";
      };
      "git.cloud.local" = {
        HostName = "10.159.0.65";
        User = "git";
        IdentityFile = "~/.ssh/id_ed25519";
      };

      ## homelab
      "pxc_lab" = {
        HostName = "10.0.10.180";
        User = "root";
        IdentityFile = "~/.ssh/id_crypt";
      };
      "pxc_root" = {
        HostName = "10.0.10.10";
        User = "root";
        IdentityFile = "~/.ssh/id_crypt";
      };
      "pxc_llm" = {
        HostName = "10.0.10.79";
        User = "root";
        IdentityFile = "~/.ssh/id_crypt";
      };
      "pxc_hermes" = {
        HostName = "10.0.10.29";
        User = "ubuntu";
        IdentityFile = "~/.ssh/id_ed25519";
      };
      "px_root" = {
        HostName = "192.168.1.179";
        User = "root";
        IdentityFile = "~/.ssh/id_crypt";
      };
      "px_lab" = {
        HostName = "192.168.1.31";
        User = "root";
        IdentityFile = "~/.ssh/id_crypt";
      };

      ## homelab-remote
      "dxc.0dl.me" = {
        ProxyCommand = "cloudflared access ssh --hostname %h";
        User = "root";
      };
      "hs.0dl.me" = {
        ProxyCommand = "cloudflared access ssh --hostname %h";
        User = "ubuntu";
      };
      "sxc.voidbox.io" = {
        ProxyCommand = "cloudflared access ssh --hostname %h";
        User = "root";
      };
    };
  };
}
