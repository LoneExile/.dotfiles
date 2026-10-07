# Home Manager for the agent user of a NixOS VM (modules/nixos/agent-dev.nix imports it).
# It is not the Mac's home/default.nix, which assumes darwin, Homebrew and secretspec: this one
# holds the shell, the dev tools and the config files an agent needs, and nothing that needs a
# secret. Secrets stay with the user on the VM (~/.omp/.env, `gh auth login`).
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.dotfiles.agent;

  # A config file that the program or the user writes to (omp's settings and models, mise's global
  # tools) cannot be a Home Manager link: the target is in the read-only Nix store, so
  # `mise use -g` fails with "Read-only file system". It is copied in as a real, writable file at
  # every activation instead. A live file that differs is kept next to the new one as
  # <name>.dotfiles-backup, never dropped silently: the repo copy wins, and an edit made on the VM
  # survives only as that backup, until the repo copy is changed to match. Same pattern as the Mac's
  # Tern settings (home/default.nix).
  writableCopy = dir: name: src: ''
    live="${dir}/${name}"
    if [ -f "$live" ] && ! cmp -s "$live" "${src}"; then
      run mv -f "$live" "$live.dotfiles-backup"
      echo "agent config: $live differed from the repo copy, kept as ${name}.dotfiles-backup"
    fi
    if [ ! -f "$live" ]; then
      run mkdir -p "${dir}"
      run cp -f "${src}" "$live"
      run chmod u+w "$live"
    fi
  '';

  ompFiles = {
    "config.yml" = ../omp/config.yml;
    "models.yml" = ../omp/models.yml;
    "mcp.json" = ../omp/mcp.json;
  };

  # mise's global tools. The tools are installed on first use (not_found_auto_install) or by
  # `mise install`, not by Nix. node.compile is off: without it mise compiled node from source on
  # this VM (it ran ./configure and failed on a missing python), while the prebuilt node runs
  # through nix-ld (measured). Installed tools live in ~/.local/share/mise, outside Nix.
  miseConfig = (pkgs.formats.toml {}).generate "mise-config.toml" {
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
      node.compile = false;
    };
  };
in {
  options.dotfiles.agent = {
    omp.enable = lib.mkEnableOption "omp's writable config files in ~/.omp/agent";
    mise = {
      enable = lib.mkEnableOption "mise with the global tools";
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.mise;
        defaultText = lib.literalExpression "pkgs.mise";
        description = "The mise package.";
      };
    };
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
        inherit (cfg.mise) package;
        enableZshIntegration = true;
        enableBashIntegration = true;
      };

      home.activation.miseConfig = lib.hm.dag.entryAfter ["writeBoundary"] (
        writableCopy "$HOME/.config/mise" "config.toml" miseConfig
      );
    })

    (lib.mkIf cfg.omp.enable {
      home.activation.ompConfig = lib.hm.dag.entryAfter ["writeBoundary"] (
        lib.concatStrings (lib.mapAttrsToList (writableCopy "$HOME/.omp/agent") ompFiles)
      );
    })

    (lib.mkIf cfg.tern.enable {
      # `tern remote setup <user>@<ip>`, run from the Mac, downloads Tern into ~/.local/share/tern
      # (the binary is not managed here, nor updated by a deploy) and writes the user service
      # ~/.config/systemd/user/tern-remote.service itself. This drop-in only changes how that
      # service serves: its own ExecStart (measured, Tern 0.6.0) plus --relay none --pkarr none
      # --no-iroh, so it listens on UDP 8376 and nothing is announced to iroh.stencil.so or any
      # relay: the Mac reaches the VM on the LAN directly, or not at all. The drop-in is there
      # before the unit is, which is fine: systemd merges it when the unit appears.
      xdg.configFile."systemd/user/tern-remote.service.d/10-direct-lan.conf".text = ''
        [Service]
        ExecStart=
        ExecStart=%h/.local/share/tern/build/tern remote serve --user --state-dir %h/.config/tern --relay none --pkarr none --no-iroh
      '';
    })
  ];
}
