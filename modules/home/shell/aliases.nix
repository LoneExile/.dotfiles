{ config, lib, pkgs, ... }:
let
  cfg = config.modules.home.shell.aliases;
  
  # Default aliases from the existing configuration
  defaultAliases = {
    # Safety aliases
    cp = "cp -i";
    mv = "mv -i";
    
    # System utilities
    df = "df -h";
    free = "free -m";
    top = "btop";
    c = "clear";
    ":q" = "exit";
    
    # Development tools
    v = "nvim";
    gdu = "gdu-go";
    ld = "lazydocker";
    
    # Package management
    bu = "brew update && brew upgrade && brew cleanup && brew doctor";
    zu = "zap update all && zap clean";
    
    # Kubernetes
    k = "kubectl";
    kx = "kubectl config use-context";
    kns = "kubectl config set-context --current --namespace";
    mk = "minikube";
    
    # Terraform
    tf = "terraform";
    tg = "terragrunt";
    
    # TMUX
    t = "tmux attach || tmux new-session";
    ta = "tmux attach -t";
    tl = "tmux ls";
    tk = "tmux kill-session -t";
    tka = "tmux kill-session -a";
    
    # SSH
    ssha = "eval $(ssh-agent) && ssh-add";
    
    # ls variants
    l = "ls -lh";
    la = "ls -A";
    lm = "ls -m";
    lr = "ls -R";
    llg = "ls -l --group-directories-first";
    
    # Git aliases
    gcl = "git clone";
    gcld = "git clone --depth";
    gi = "git init";
    ga = "git add";
    gc = "git commit -m";
    gp = "git pull";
    gpa = "git pull --recurse-submodules";
    gf = "git fetch";
    gfa = "git fetch --recurse-submodules";
    gP = "git push";
    gs = "git status";
    gl = "git log";
    grl = "git reflog";
    gco = "git checkout";
    gw = "git worktree";
    gclb = "git clone --bare";
  };

  # Complex git log aliases that need special formatting
  gitLogAliases = {
    glg = "git log --graph --abbrev-commit --decorate --format=format:'%C(bold blue)%h%C(reset) - %C(bold green)(%ar)%C(reset) %C(white)%s%C(reset) %C(dim white)- %an%C(reset)%C(bold yellow)%d%C(reset)'";
    glg1 = "git log --graph --abbrev-commit --decorate --format=format:'%C(bold blue)%h%C(reset) - %C(bold cyan)%aD%C(reset) %C(bold green)(%ar)%C(reset)%C(bold yellow)%d%C(reset)%n''          %C(white)%s%C(reset) %C(dim white)- %an%C(reset)'";
  };

  # Shell functions that need to be defined
  shellFunctions = ''
    # Lazygit with directory change support
    lg() {
        export LAZYGIT_NEW_DIR_FILE="$HOME/.lazygit/newdir"
        lazygit "$@"
        if [ -f $LAZYGIT_NEW_DIR_FILE ]; then
            cd "$(cat $LAZYGIT_NEW_DIR_FILE)" || return
            rm -f $LAZYGIT_NEW_DIR_FILE > /dev/null
        fi
    }

    # Docker/Colima management
    dk() {
        if [ "$1" = "start" ]; then
            colima start
            sudo ln -s /Users/$USER/.colima/default/docker.sock /var/run/docker.sock
        elif [ "$1" = "stop" ]; then
            colima stop
            sudo rm /var/run/docker.sock
        elif [ "$1" = "restart" ]; then
            colima restart
        elif [ "$1" = "status" ]; then
            colima status
        else
            echo "Usage: dk [start|stop|restart|status]"
        fi
    }
  '';
in {
  options.modules.home.shell.aliases = {
    enable = lib.mkEnableOption "Shell aliases and functions";
    
    customAliases = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      description = "Custom shell aliases to add or override defaults";
    };

    enableDefaultAliases = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable the default set of aliases";
    };

    enableGitAliases = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Git-related aliases";
    };

    enableKubernetesAliases = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Kubernetes-related aliases";
    };

    enableTerraformAliases = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Terraform-related aliases";
    };

    enableTmuxAliases = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable TMUX-related aliases";
    };

    enableShellFunctions = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable custom shell functions (lg, dk)";
    };

    enableGithubCopilot = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable GitHub Copilot CLI aliases";
    };
  };
  
  config = lib.mkIf cfg.enable {
    # Set up shell aliases
    programs.zsh.shellAliases = lib.mkMerge [
      # Base aliases (always enabled if module is enabled)
      (lib.mkIf cfg.enableDefaultAliases (lib.filterAttrs (n: v: 
        !(lib.hasPrefix "g" n) && # Filter out git aliases
        !(lib.elem n ["k" "kx" "kns" "mk"]) && # Filter out k8s aliases
        !(lib.elem n ["tf" "tg"]) && # Filter out terraform aliases
        !(lib.elem n ["t" "ta" "tl" "tk" "tka"]) # Filter out tmux aliases
      ) defaultAliases))
      
      # Git aliases
      (lib.mkIf cfg.enableGitAliases (lib.filterAttrs (n: v: lib.hasPrefix "g" n) defaultAliases))
      (lib.mkIf cfg.enableGitAliases gitLogAliases)
      
      # Kubernetes aliases
      (lib.mkIf cfg.enableKubernetesAliases {
        k = defaultAliases.k;
        kx = defaultAliases.kx;
        kns = defaultAliases.kns;
        mk = defaultAliases.mk;
      })
      
      # Terraform aliases
      (lib.mkIf cfg.enableTerraformAliases {
        tf = defaultAliases.tf;
        tg = defaultAliases.tg;
      })
      
      # TMUX aliases
      (lib.mkIf cfg.enableTmuxAliases {
        t = defaultAliases.t;
        ta = defaultAliases.ta;
        tl = defaultAliases.tl;
        tk = defaultAliases.tk;
        tka = defaultAliases.tka;
      })
      
      # Custom user aliases (highest priority)
      cfg.customAliases
    ];

    # Add shell functions and GitHub Copilot setup
    programs.zsh.initExtra = lib.mkMerge [
      (lib.mkIf cfg.enableShellFunctions shellFunctions)
      (lib.mkIf cfg.enableGithubCopilot ''
        # GitHub Copilot CLI setup
        if command -v gh >/dev/null 2>&1; then
          eval "$(gh copilot alias -- zsh)"
        fi
      '')
    ];

    # Create aliases config file for compatibility with existing setup
    home.file.".config/zsh/aliases.zsh".text = ''
      # This file is managed by the aliases.nix module
      # Aliases are configured through Home Manager programs.zsh.shellAliases
      # Functions and additional setup are in programs.zsh.initExtra
      
      # Note: Individual aliases are now managed by the module configuration
      # To add custom aliases, use the modules.home.shell.aliases.customAliases option
    '';
  };
}