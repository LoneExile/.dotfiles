{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.modules.home.development.languages;
in {
  options.modules.home.development.languages = {
    enable = lib.mkEnableOption "Development language tools";

    # Use mise for language version management
    enableMise = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable mise for language version management";
    };

    nodejs = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Node.js development tools";
      };

      enablePnpm = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable pnpm package manager";
      };

      enableYarn = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Yarn package manager";
      };

      enableDeno = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Deno runtime";
      };
    };

    python = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Python development tools";
      };

      enableUv = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable uv Python package manager";
      };

      version = lib.mkOption {
        type = lib.types.str;
        default = "3";
        description = "Python version to use";
      };
    };

    rust = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Rust development tools";
      };

      enableRustAnalyzer = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable rust-analyzer LSP";
      };
    };

    go = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Go development tools";
      };
    };

    java = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Java development tools";
      };
    };

    dotnet = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable .NET development tools";
      };
    };

    elixir = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Elixir development tools";
      };

      enableErlang = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Erlang (required for Elixir)";
      };
    };

    lua = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Lua development tools";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Configure mise for language version management
    programs.mise = lib.mkIf cfg.enableMise {
      enable = true;
      enableZshIntegration = true;
      enableBashIntegration = true;

      globalConfig = {
        tools = lib.mkMerge [
          (lib.mkIf cfg.nodejs.enable {
            node = "latest";
            pnpm = lib.mkIf cfg.nodejs.enablePnpm "latest";
            yarn = lib.mkIf cfg.nodejs.enableYarn "latest";
            deno = lib.mkIf cfg.nodejs.enableDeno "latest";
          })

          (lib.mkIf cfg.python.enable {
            python = cfg.python.version;
            uv = lib.mkIf cfg.python.enableUv "latest";
          })

          (lib.mkIf cfg.rust.enable {
            rust = "latest";
          })

          (lib.mkIf cfg.go.enable {
            go = "latest";
          })

          (lib.mkIf cfg.java.enable {
            java = "latest";
          })

          (lib.mkIf cfg.dotnet.enable {
            dotnet = "latest";
          })

          (lib.mkIf cfg.elixir.enable {
            elixir = "latest";
            erlang = lib.mkIf cfg.elixir.enableErlang "latest";
          })

          (lib.mkIf cfg.lua.enable {
            lua = "latest";
          })
        ];

        settings = {
          not_found_auto_install = true;
          plugin_autoupdate_last_check_duration = "0";
        };
      };
    };

    # Language-specific packages and tools
    home.packages = with pkgs;
      lib.mkMerge [
        # Node.js ecosystem
        (lib.mkIf cfg.nodejs.enable [
          nodejs
          (lib.mkIf cfg.nodejs.enablePnpm nodePackages.pnpm)
          (lib.mkIf cfg.nodejs.enableYarn yarn)
          (lib.mkIf cfg.nodejs.enableDeno deno)
        ])

        # Python ecosystem
        (lib.mkIf cfg.python.enable [
          python3
          (lib.mkIf cfg.python.enableUv uv)
        ])

        # Rust ecosystem
        (lib.mkIf cfg.rust.enable [
          rustc
          cargo
          rustfmt
          clippy
          (lib.mkIf cfg.rust.enableRustAnalyzer rust-analyzer)
        ])

        # Go ecosystem
        (lib.mkIf cfg.go.enable [
          go
          gopls
          golangci-lint
        ])

        # Java ecosystem
        (lib.mkIf cfg.java.enable [
          openjdk
          maven
          gradle
        ])

        # .NET ecosystem
        (lib.mkIf cfg.dotnet.enable [
          dotnet-sdk
        ])

        # Elixir/Erlang ecosystem
        (lib.mkIf cfg.elixir.enable [
          elixir
          (lib.mkIf cfg.elixir.enableErlang erlang)
        ])

        # Lua ecosystem
        (lib.mkIf cfg.lua.enable [
          lua
          luarocks
        ])
      ];

    # Language-specific environment variables and configuration
    home.sessionVariables = lib.mkMerge [
      (lib.mkIf cfg.nodejs.enable {
        # pnpm configuration
        PNPM_HOME = "$HOME/Library/pnpm";
      })

      (lib.mkIf cfg.go.enable {
        GOPATH = "$HOME/go";
        GOBIN = "$HOME/go/bin";
      })
    ];

    # Add language binaries to PATH
    home.sessionPath = lib.mkMerge [
      (lib.mkIf cfg.nodejs.enable [
        "$HOME/Library/pnpm"
      ])

      (lib.mkIf cfg.go.enable [
        "$HOME/go/bin"
      ])
    ];

    # Language-specific shell integration
    programs.zsh.initExtra = lib.mkMerge [
      (lib.mkIf cfg.nodejs.enable ''
        # pnpm configuration
        export PNPM_HOME="$HOME/Library/pnpm"
        case ":$PATH:" in
          *":$PNPM_HOME:"*) ;;
          *) export PATH="$PNPM_HOME:$PATH" ;;
        esac
      '')
    ];
  };
}
