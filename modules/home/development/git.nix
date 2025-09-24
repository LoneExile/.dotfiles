{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.modules.home.development.git;
in {
  options.modules.home.development.git = {
    enable = lib.mkEnableOption "Git configuration";

    userName = lib.mkOption {
      type = lib.types.str;
      default = "Apinant U-suwantim";
      description = "Git user name";
    };

    userEmail = lib.mkOption {
      type = lib.types.str;
      default = "Hello@Apinant.dev";
      description = "Git user email";
    };

    defaultBranch = lib.mkOption {
      type = lib.types.str;
      default = "main";
      description = "Default branch name for new repositories";
    };

    enableDiffSoFancy = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable diff-so-fancy for better git diffs";
    };

    enableLfs = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Git LFS (Large File Storage)";
    };

    enableLazygit = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Lazygit TUI";
    };

    extraConfig = lib.mkOption {
      type = lib.types.attrs;
      default = {};
      description = "Additional Git configuration";
    };

    signing = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable commit signing";
      };

      key = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "GPG key ID for signing commits";
      };

      signByDefault = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Sign all commits by default";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    programs.git = {
      enable = true;
      userName = cfg.userName;
      userEmail = cfg.userEmail;

      diff-so-fancy.enable = cfg.enableDiffSoFancy;
      lfs.enable = cfg.enableLfs;

      extraConfig = lib.mkMerge [
        {
          init = {
            defaultBranch = cfg.defaultBranch;
          };

          merge = {
            conflictStyle = "diff3";
            tool = "meld";
          };

          pull = {
            rebase = true;
          };

          push = {
            default = "simple";
            autoSetupRemote = true;
          };

          core = {
            editor = "nvim";
            autocrlf = false;
          };

          color = {
            ui = "auto";
          };

          diff = {
            algorithm = "patience";
            compactionHeuristic = true;
          };

          rerere = {
            enabled = true;
          };

          branch = {
            autosetupmerge = "always";
            autosetuprebase = "always";
          };
        }

        (lib.mkIf cfg.signing.enable {
          user.signingkey = cfg.signing.key;
          commit.gpgsign = cfg.signing.signByDefault;
          tag.gpgsign = cfg.signing.signByDefault;
        })

        cfg.extraConfig
      ];

      # Useful Git aliases
      aliases = {
        # Status and info
        st = "status";
        br = "branch";
        co = "checkout";
        ci = "commit";

        # Logging
        lg = "log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit";
        lol = "log --graph --decorate --pretty=oneline --abbrev-commit";
        lola = "log --graph --decorate --pretty=oneline --abbrev-commit --all";

        # Shortcuts
        unstage = "reset HEAD --";
        last = "log -1 HEAD";
        visual = "!gitk";

        # Workflow helpers
        wip = "commit -am 'WIP'";
        unwip = "reset HEAD~1";
        amend = "commit --amend --no-edit";

        # Branch management
        cleanup = "!git branch --merged | grep -v '\\*\\|main\\|master\\|develop' | xargs -n 1 git branch -d";

        # Diff helpers
        diffc = "diff --cached";
        diffstat = "diff --stat";
      };
    };

    # Install lazygit if enabled
    home.packages = lib.mkIf cfg.enableLazygit [
      pkgs.lazygit
    ];

    # Configure lazygit
    programs.lazygit = lib.mkIf cfg.enableLazygit {
      enable = true;
      settings = {
        gui = {
          theme = {
            lightTheme = false;
            activeBorderColor = ["#a6e3a1" "bold"];
            inactiveBorderColor = ["#cdd6f4"];
            optionsTextColor = ["#89b4fa"];
            selectedLineBgColor = ["#313244"];
            selectedRangeBgColor = ["#313244"];
            cherryPickedCommitBgColor = ["#45475a"];
            cherryPickedCommitFgColor = ["#a6e3a1"];
          };
        };

        git = {
          paging = {
            colorArg = "always";
            pager = "diff-so-fancy";
          };
        };

        refresher = {
          refreshInterval = 10;
          fetchInterval = 60;
        };
      };
    };
  };
}
