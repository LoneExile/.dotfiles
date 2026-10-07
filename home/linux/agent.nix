# Home Manager for the agent user of a NixOS VM (modules/nixos/agent-dev.nix imports it).
# It is not the Mac's home/default.nix, which assumes darwin, Homebrew and secretspec: this one
# holds the shell, the dev tools and the config files an agent needs, and nothing that needs a
# secret. Secrets stay with the user on the VM (~/.omp/.env, `gh auth login`).
{
  config,
  lib,
  ...
}: let
  cfg = config.dotfiles.agent;

  # omp's config files, copied from this repo as writable files at every activation: omp and the
  # user write to them (models, settings), and a store symlink would be read-only. A live file that
  # differs is kept next to the new one as <name>.dotfiles-backup, never dropped silently, the
  # same pattern as the Mac's Tern settings (home/default.nix).
  ompFiles = {
    "config.yml" = ../omp/config.yml;
    "models.yml" = ../omp/models.yml;
    "mcp.json" = ../omp/mcp.json;
  };
  ompInstall = name: src: ''
    ompLive="$ompDir/${name}"
    if [ -f "$ompLive" ] && ! cmp -s "$ompLive" "${src}"; then
      run mv -f "$ompLive" "$ompLive.dotfiles-backup"
      echo "omp config: ${name} differed from the repo copy, kept as ${name}.dotfiles-backup"
    fi
    if [ ! -f "$ompLive" ]; then
      run cp -f "${src}" "$ompLive"
      run chmod u+w "$ompLive"
    fi
  '';
in {
  options.dotfiles.agent = {
    omp.enable = lib.mkEnableOption "omp's writable config files in ~/.omp/agent";
    mise.enable = lib.mkEnableOption "mise with the global tools";
    tern.enable = lib.mkEnableOption "the Tern remote service settings";
  };

  config = lib.mkMerge [
    {
      home.stateVersion = "25.11";

      # Tern's binary (~/.local/bin, put there by `tern remote setup`) and mise's shims are on the
      # PATH of every zsh, also a non-interactive one that runs an agent's command.
      home.sessionPath = ["$HOME/.local/bin" "$HOME/.local/share/mise/shims"];

      programs = {
        zsh = {
          enable = true;
          # NixOS's programs.zsh already runs compinit for every interactive shell.
          enableCompletion = false;
        };

        starship = {
          enable = true;
          enableZshIntegration = true;
          settings = lib.importTOML ../starship/starship.toml;
        };

        # The identity of the Mac (home/default.nix), and the few defaults that matter for an agent.
        git = {
          enable = true;
          settings = {
            user = {
              email = "Hello@Apinant.dev";
              name = "Apinant U-suwantim";
            };
            init.defaultBranch = "main";
            pull.rebase = true;
          };
        };

        direnv = {
          enable = true;
          nix-direnv.enable = true;
          mise.enable = cfg.mise.enable;
        };
      };
    }

    (lib.mkIf cfg.mise.enable {
      programs.mise = {
        enable = true;
        enableZshIntegration = true;
        enableBashIntegration = true;
        globalConfig = {
          tools = {
            node = "latest";
            python = "3";
            uv = "latest";
            go = "latest";
            rust = "latest";
            bun = "latest";
            "npm:pnpm" = "latest";
          };
          settings = {
            not_found_auto_install = true;
            plugin_autoupdate_last_check_duration = "0";
            idiomatic_version_file_enable_tools = [];
          };
        };
      };
    })

    (lib.mkIf cfg.omp.enable {
      home.activation.ompConfig = lib.hm.dag.entryAfter ["writeBoundary"] ''
        ompDir="$HOME/.omp/agent"
        run mkdir -p "$ompDir"
        ${lib.concatStrings (lib.mapAttrsToList ompInstall ompFiles)}
      '';
    })
  ];
}
