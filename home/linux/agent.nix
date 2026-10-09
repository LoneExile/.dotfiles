# Home Manager for the agent user of a NixOS VM (modules/nixos/agent-dev.nix imports it).
# It is not the Mac's home/default.nix, which assumes darwin, Homebrew and secretspec: this one
# holds the shell, the dev tools and the config files an agent needs, and nothing that needs a
# secret. Secrets stay with the user on the VM (~/.omp/.env, `gh auth login`); the one exception is
# what `just vm-sync` writes from the vault (infra/vm-sync-lib.sh): the Hindsight URL and key. Nix
# never holds it; it only sets up how it is read.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.dotfiles.agent;

  # Config files that the program or the user writes to (omp's settings and models, mise's global
  # tools) cannot be Home Manager links: the target is in the read-only Nix store, and
  # `mise use -g` fails with "Read-only file system". They are installed as real, writable files by
  # writable-copy.sh (tested by writable-copy_test.sh). The repo copy wins only when it is new: an
  # edit made on the VM survives deploys and reboots, and is kept as <name>.dotfiles-backup when a
  # changed repo copy replaces it. The Mac's Tern settings (home/default.nix) differ in one way:
  # there, a differing file is backed up and replaced at every `just home`; here Home Manager also
  # activates at every boot, which would undo an edit at the next reboot.
  writableCopies = copies: ''
    ${builtins.readFile ./writable-copy.sh}
    ${lib.concatMapStringsSep "\n" ({
      src,
      dest,
    }: ''writable_copy "${src}" "${dest}"'')
    copies}
  '';

  ompFiles = {
    "config.yml" = ../omp/config.yml;
    "models.yml" = ../omp/models.yml;
    "mcp.json" = ../omp/mcp.json;
  };

  # The captured omp plugins (just omp-plugins-capture): the manifests are installed as writable
  # files (omp rewrites them), and a user service runs `bun install --frozen-lockfile` when their
  # hash is new. The hash is part of the unit, so a changed capture restarts the service at the
  # next deploy; the script keeps a stamp too, so a boot with nothing new installs nothing.
  pluginFiles = ["package.json" "bun.lock" "omp-plugins.lock.json"];
  pluginsDir = ../omp/plugins;
  pluginsHash = builtins.hashString "sha256" (lib.concatMapStringsSep "\n" (f: builtins.hashFile "sha256" (pluginsDir + "/${f}")) pluginFiles);
  pluginsInstall = pkgs.writeScript "omp-plugins-install" (builtins.readFile ./omp-plugins-install.sh);

  # The Mason language servers (just mason-capture): names only, one per line. A user service installs
  # the ones that are missing with a headless Neovim that loads mason.nvim and nothing else, into
  # ~/.local/share/nvim/mason, which pi-mason-bridge (one of the captured omp plugins) puts on omp's PATH.
  # The list's hash is part of the unit, so a changed list restarts the service at the next deploy; the
  # script keeps a stamp too, so a boot with nothing new installs nothing.
  masonList = ../omp/mason-lsp.txt;
  masonNames = lib.filter (n: n != "") (lib.splitString "\n" (builtins.readFile masonList));
  masonHash = builtins.hashFile "sha256" masonList;
  masonInstall = pkgs.writeScript "mason-lsp-install" (builtins.readFile ./mason-lsp-install.sh);

  # mise's global tools. The tools are installed on first use (not_found_auto_install) or by
  # `mise install`, not by Nix. node.compile and python.compile are off: with them unset mise
  # compiled node and python from source on this VM (node: ./configure failed on a missing python;
  # python: python-build exited 1 after minutes), while the prebuilt runtimes run through nix-ld
  # (measured). Installed tools live in ~/.local/share/mise, outside Nix.
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
      python.compile = false;
    };
  };
in {
  imports = [./zsh.nix];

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
    gh.enable = lib.mkEnableOption "gh as git's credential helper for github.com (the user logs in with `gh auth login`)";
    tools.enable = lib.mkEnableOption "just, lazygit and lazydocker as packages of the user";
    docker.enable = lib.mkEnableOption "starting the rootless Docker user unit (NixOS defines it) when Home Manager activates";
    sync = {
      plugins = lib.mkEnableOption "the captured omp plugins: manifests in ~/.omp/plugins and a user service that installs them";
      hindsight = lib.mkEnableOption "reading ~/.config/dotfiles/hindsight.env (written by vm-sync) into HINDSIGHT_API_URL and HINDSIGHT_API_TOKEN in every zsh";
      pluginPackages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [pkgs.bun pkgs.nodejs];
        defaultText = lib.literalExpression "[pkgs.bun pkgs.nodejs]";
        description = "bun and node, on the PATH of the plugin install service (some plugins run node in their install scripts).";
      };
    };
    mason = {
      enable = lib.mkEnableOption "the Mason language servers of home/omp/mason-lsp.txt, installed by a user service";
      toolPackages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [pkgs.nodejs pkgs.go pkgs.getconf pkgs.curl pkgs.gzip pkgs.gnutar pkgs.cargo pkgs.rustc pkgs.gcc pkgs.git pkgs.nix];
        defaultText = lib.literalExpression "[pkgs.nodejs pkgs.go pkgs.getconf pkgs.curl pkgs.gzip pkgs.gnutar pkgs.cargo pkgs.rustc pkgs.gcc pkgs.git pkgs.nix]";
        description = "What the install of the listed servers runs, on the PATH of the install service (bash and coreutils are added for the script itself): nothing else.";
      };
    };
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

      home.activation.miseConfig = lib.hm.dag.entryAfter ["writeBoundary"] (writableCopies [
        {
          src = miseConfig;
          dest = "$HOME/.config/mise/config.toml";
        }
      ]);
    })

    (lib.mkIf cfg.omp.enable {
      home.activation.ompConfig = lib.hm.dag.entryAfter ["writeBoundary"] (writableCopies (
        lib.mapAttrsToList (name: src: {
          inherit src;
          dest = "$HOME/.omp/agent/${name}";
        })
        ompFiles
      ));
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

    (lib.mkIf cfg.gh.enable {
      # gh answers git's credential requests for github.com with the login that the user makes on the VM
      # (`gh auth login`: gh keeps it in ~/.config/gh, a plain directory that nothing here manages, so gh
      # can write its own config and hosts files and no deploy overwrites them). Without a login git asks
      # for nothing and fails as before. The store path keeps it working in a shell that has no gh on its PATH.
      programs.git.settings.credential = {
        "https://github.com".helper = "!${pkgs.gh}/bin/gh auth git-credential";
        "https://gist.github.com".helper = "!${pkgs.gh}/bin/gh auth git-credential";
      };
    })

    (lib.mkIf cfg.tools.enable {
      # On lex's PATH (/etc/profiles/per-user/lex/bin), which every login shell, Tern shell and `zsh -c` gets. No
      # config file of any of them is managed: lazygit and lazydocker write their own under ~/.config.
      home.packages = [pkgs.just pkgs.lazygit pkgs.lazydocker];
    })

    (lib.mkIf cfg.docker.enable {
      # The rootless Docker daemon is a NixOS user unit (virtualisation.docker.rootless, modules/nixos/agent-dev.nix),
      # and the NixOS switch only loads a user unit that it adds: it starts with the user manager, at the next boot.
      # Home Manager starts only its own units, so this step, after reloadSystemd, starts docker.service; at boot
      # Home Manager runs before the user manager exists, and the step does nothing then (start-user-unit.sh).
      home.activation.dockerRootlessStart = lib.hm.dag.entryAfter ["reloadSystemd"] ''
        ${builtins.readFile ./start-user-unit.sh}
        start_user_unit ${pkgs.systemd}/bin/systemctl docker.service
      '';
    })

    (lib.mkIf cfg.sync.hindsight {
      # omp reads HINDSIGHT_API_URL and HINDSIGHT_API_TOKEN from the environment before its config
      # file (measured on the VM). .zshenv runs for every zsh: the login shell of an ssh session, the
      # shell of a Tern session and the one that runs `ssh host command`. ~/.omp/.env stays the
      # user's own: `just vm-sync` never writes it. The file is only read when it exists, so a VM
      # with no entry in the vault map runs as before. `set -a` exports what the file sets and
      # nothing else: allexport is put back as it was (infra/roles-check.sh runs this in zsh).
      programs.zsh.envExtra = ''
        if [[ -r "$HOME/.config/dotfiles/hindsight.env" ]]; then
          [[ -o allexport ]] && hindsight_allexport=1 || hindsight_allexport=0
          set -a
          . "$HOME/.config/dotfiles/hindsight.env"
          [[ $hindsight_allexport == 1 ]] || set +a
          unset hindsight_allexport
        fi
      '';
    })

    (lib.mkIf cfg.sync.plugins {
      # Before reloadSystemd, so that the manifests are in place when the unit is (re)started.
      home.activation.ompPlugins = lib.hm.dag.entryBetween ["reloadSystemd"] ["writeBoundary"] (writableCopies (map (f: {
          src = pluginsDir + "/${f}";
          dest = "$HOME/.omp/plugins/${f}";
        })
        pluginFiles));

      # Type=simple: a first install downloads about a gigabyte, and a Home Manager activation must
      # not wait for it. A failure (network, registry) is retried a few times an hour, and again at
      # the next boot.
      systemd.user.services.omp-plugins-install = {
        Unit = {
          Description = "Install the captured omp plugins (bun install --frozen-lockfile)";
          StartLimitIntervalSec = 3600;
          StartLimitBurst = 5;
        };
        Service = {
          Type = "simple";
          ExecStart = "${pluginsInstall} ${pluginsHash}";
          Restart = "on-failure";
          RestartSec = 60;
          Environment = "PATH=${lib.makeBinPath (cfg.sync.pluginPackages ++ [pkgs.bash pkgs.coreutils])}";
        };
        Install.WantedBy = ["default.target"];
      };
    })

    (lib.mkIf cfg.mason.enable {
      # bash-language-server gets its diagnostics from shellcheck (it runs the binary on PATH, and Mason's
      # own shellcheck is a linter, which this role does not install). On lex's login PATH, which omp inherits;
      # not on the PATH of the install unit, which names only what the installs need.
      home.packages = [pkgs.shellcheck];

      # Type=simple, like the plugin install: a first install downloads some 900 MB, and a Home Manager
      # activation must not wait for it. A failure (network, registry) is retried a few times an hour,
      # and again at the next boot. Neovim and mason.nvim are on no PATH: the unit names them by store
      # path, and the init file (home/linux/mason-init.lua) loads mason.nvim from MASON_NVIM only.
      systemd.user.services.mason-lsp-install = {
        Unit = {
          Description = "Install the Mason language servers of home/omp/mason-lsp.txt (headless MasonInstall)";
          StartLimitIntervalSec = 3600;
          StartLimitBurst = 5;
        };
        Service = {
          Type = "simple";
          ExecStart = "${masonInstall} ${masonHash} ${pkgs.neovim}/bin/nvim ${./mason-init.lua} ${lib.concatStringsSep " " masonNames}";
          Restart = "on-failure";
          RestartSec = 60;
          Environment = [
            "PATH=${lib.makeBinPath (cfg.mason.toolPackages ++ [pkgs.bash pkgs.coreutils])}"
            "MASON_NVIM=${pkgs.vimPlugins.mason-nvim}"
          ];
        };
        Install.WantedBy = ["default.target"];
      };
    })
  ];
}
