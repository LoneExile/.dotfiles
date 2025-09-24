{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.modules.home.shell.starship;

  # Default starship configuration optimized for development
  defaultSettings = {
    format = lib.concatStrings [
      "$all"
      "$fill"
      "$cmd_duration"
      "$line_break"
      "$jobs"
      "$battery"
      "$time"
      "$status"
      "$container"
      "$shell"
      "$character"
    ];

    fill = {
      symbol = " ";
    };

    # Add a blank line between shell prompts
    add_newline = true;

    # Timeout for commands (in milliseconds)
    command_timeout = 1000;

    # Character configuration
    character = {
      success_symbol = "[❯](bold green)";
      error_symbol = "[❯](bold red)";
      vimcmd_symbol = "[❮](bold green)";
    };

    # Directory configuration
    directory = {
      truncation_length = 3;
      truncation_symbol = "…/";
      home_symbol = "~";
      read_only = " 󰌾";
      style = "bold cyan";
      truncate_to_repo = true;
    };

    # Git configuration
    git_branch = {
      symbol = " ";
      format = "[$symbol$branch(:$remote_branch)]($style) ";
      style = "bold purple";
    };

    git_status = {
      format = "([$all_status$ahead_behind]($style) )";
      style = "bold red";
      conflicted = "⚡";
      ahead = "⇡$count";
      behind = "⇣$count";
      diverged = "⇕⇡$ahead_count⇣$behind_count";
      untracked = "?$count";
      stashed = "$$count";
      modified = "!$count";
      staged = "+$count";
      renamed = "»$count";
      deleted = "✘$count";
    };

    # Command duration
    cmd_duration = {
      min_time = 2000;
      format = "[$duration]($style)";
      style = "bold yellow";
    };

    # Time
    time = {
      disabled = false;
      format = "[$time]($style)";
      style = "bold white";
      time_format = "%T";
    };

    # Battery
    battery = {
      full_symbol = "🔋";
      charging_symbol = "🔌";
      discharging_symbol = "⚡";
      display = [
        {
          threshold = 10;
          style = "bold red";
        }
        {
          threshold = 30;
          style = "bold yellow";
        }
      ];
    };

    # Programming languages
    nodejs = {
      symbol = " ";
      format = "[$symbol($version )]($style)";
      style = "bold green";
    };

    python = {
      symbol = " ";
      format = "[$symbol$pyenv_prefix($version )(\($virtualenv\) )]($style)";
      style = "bold yellow";
    };

    rust = {
      symbol = " ";
      format = "[$symbol($version )]($style)";
      style = "bold red";
    };

    golang = {
      symbol = " ";
      format = "[$symbol($version )]($style)";
      style = "bold cyan";
    };

    java = {
      symbol = " ";
      format = "[$symbol($version )]($style)";
      style = "bold red";
    };

    lua = {
      symbol = " ";
      format = "[$symbol($version )]($style)";
      style = "bold blue";
    };

    # Docker
    docker_context = {
      symbol = " ";
      format = "[$symbol$context]($style) ";
      style = "blue bold";
    };

    # Kubernetes
    kubernetes = {
      format = "[$symbol$context( \($namespace\))]($style) ";
      style = "cyan bold";
      symbol = "☸ ";
      disabled = false;
    };

    # AWS
    aws = {
      format = "[$symbol($profile )(\($region\) )(\[$duration\] )]($style)";
      symbol = "☁️ ";
      style = "bold blue";
    };

    # Terraform
    terraform = {
      format = "[$symbol$workspace]($style) ";
      symbol = "💠 ";
      style = "bold purple";
    };

    # Package version
    package = {
      format = "[$symbol$version]($style) ";
      symbol = "📦 ";
      style = "208";
    };

    # Jobs
    jobs = {
      symbol = "";
      style = "bold red";
      number_threshold = 1;
      format = "[$symbol$number]($style)";
    };

    # Status
    status = {
      style = "bg:blue";
      symbol = "🔴 ";
      success_symbol = "🟢 SUCCESS";
      format = "[$symbol$common_meaning$signal_name$maybe_int]($style) ";
      map_symbol = true;
      disabled = false;
    };
  };
in {
  options.modules.home.shell.starship = {
    enable = lib.mkEnableOption "Starship prompt configuration";

    settings = lib.mkOption {
      type = lib.types.attrs;
      default = defaultSettings;
      description = "Starship configuration settings";
    };

    enableZshIntegration = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Starship integration with Zsh";
    };

    enableBashIntegration = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Starship integration with Bash";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.starship = {
      enable = true;
      enableZshIntegration = cfg.enableZshIntegration;
      enableBashIntegration = cfg.enableBashIntegration;
      settings = cfg.settings;
    };
  };
}
