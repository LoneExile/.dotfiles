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

  # The jumphost's host values, one source with the Mac (home/default.nix): home/ssh/jumphost.nix.
  jumphost = import ../ssh/jumphost.nix;
  jumphostKeyFile = "~/.ssh/id_ed25519_jumphost";

  # lazydocker for an ssh:// Docker context: the wrapper of home/linux/lazydocker-ssh.sh in front of the real binary (see its header
  # for why lazydocker cannot use the ssh:// context itself with the restricted key).
  lazydockerSsh = pkgs.symlinkJoin {
    pname = "lazydocker";
    inherit (pkgs.lazydocker) version;
    paths = [pkgs.lazydocker];
    passthru.wrapped = true;
    postBuild = ''
      rm $out/bin/lazydocker
      install -m 755 ${pkgs.replaceVars ./lazydocker-ssh.sh {
        lazydocker = "${pkgs.lazydocker}/bin/lazydocker";
        docker = "${cfg.docker.package}/bin/docker";
        socat = "${pkgs.socat}/bin/socat";
        ssh = "${pkgs.openssh}/bin/ssh";
      }} $out/bin/lazydocker
    '';
    meta.mainProgram = "lazydocker";
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
    docker = {
      enable = lib.mkEnableOption "the Docker contexts of the user and the start of the rootless Docker user unit (NixOS defines it) when Home Manager activates";
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.docker_29;
        defaultText = lib.literalExpression "pkgs.docker_29";
        description = "The docker package whose CLI makes the contexts (the NixOS module runs the same package as the rootless daemon).";
      };
    };
    jumphost.enable = lib.mkEnableOption "the jumphost: its ssh entry with a pinned host key, the user's own key made on this machine, the Docker context `jumphost`, and lazydocker through a bridge";
    browser.enable = lib.mkEnableOption "the idle timeout of the chrome-devtools-axi CLI in every zsh of the user (the browser is the NixOS side of the piece)";
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
      # config file of any of them is managed: lazygit and lazydocker write their own under ~/.config. With the jumphost piece
      # lazydocker is the wrapper for ssh:// contexts (lazydockerSsh above).
      home.packages = [
        pkgs.just
        pkgs.lazygit
        (
          if cfg.jumphost.enable
          then lazydockerSsh
          else pkgs.lazydocker
        )
      ];
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

      # The local daemon is the Docker context `rootless`, current when Home Manager creates it: DOCKER_HOST is not exported, because
      # while it is set `docker context use`, DOCKER_CONTEXT and lazydocker's context lookup are ignored (measured). A context that
      # the user switched to stays current (docker-contexts.sh). With the jumphost piece, the context `jumphost` is ssh://<alias>.
      home.activation.dockerContexts = lib.hm.dag.entryAfter ["writeBoundary"] ''
        ${builtins.readFile ./docker-contexts.sh}
        ensure_docker_context ${cfg.docker.package}/bin/docker rootless "unix:///run/user/$(id -u)/docker.sock" current
        ${lib.optionalString cfg.jumphost.enable "ensure_docker_context ${cfg.docker.package}/bin/docker jumphost ssh://${jumphost.alias}"}
      '';
    })

    (lib.mkIf cfg.jumphost.enable {
      # ssh for the jumphost, and nothing else: one entry (HostName and User from home/ssh/jumphost.nix, shared with the Mac, whose
      # `Host *` block, User root, StrictHostKeyChecking no and UseKeychain are not here), the key that is made on this VM (below),
      # only that key (IdentitiesOnly), strict host key checking against one pinned ed25519 key and no other known_hosts file.
      # The pinned key is the jumphost's PUBLIC host key, which is fine in the repo.
      programs.ssh = {
        enable = true;
        enableDefaultConfig = false;
        matchBlocks.${jumphost.alias} = {
          inherit (jumphost) hostname user;
          identityFile = [jumphostKeyFile];
          identitiesOnly = true;
          userKnownHostsFile = "~/.ssh/known_hosts.d/${jumphost.alias}";
          extraOptions = {
            StrictHostKeyChecking = "yes";
            GlobalKnownHostsFile = "/dev/null";
          };
        };
      };
      home.file.".ssh/known_hosts.d/${jumphost.alias}".text = "${jumphost.hostname} ${jumphost.hostKey}\n";

      # The user's own key for it, made here, once, and never replaced: its private half never leaves the VM (ssh-key.sh). Before
      # the links of Home Manager, so that a missing ~/.ssh is made with mode 700. `just vm-jumphost-authorize <vm>` (on the Mac) reads
      # the public half and restricts it on the jumphost to `docker system dial-stdio`. The context `jumphost` is made by dockerContexts.
      home.activation.jumphostKey = lib.hm.dag.entryBetween ["linkGeneration"] ["writeBoundary"] ''
        ${builtins.readFile ./ssh-key.sh}
        ensure_ssh_key ${pkgs.openssh}/bin/ssh-keygen "$HOME/.ssh/id_ed25519_jumphost" docker-jumphost
      '';
    })

    (lib.mkIf cfg.browser.enable {
      # The browser itself is NixOS side (modules/nixos/agent-dev.nix: the link at /opt/google/chrome/chrome). What is here is how the CLI runs it.
      # chrome-devtools-axi starts a small bridge process (a listener on 127.0.0.1) and, through chrome-devtools-mcp, a browser, at the first
      # command, and keeps both until its `stop`. An agent that forgets `stop` would leave a browser of about 1.5 GiB of resident memory (0.7 GiB
      # with shared pages counted once; measured) on a 7.8 GiB machine, and a port open. With this timeout the CLI stops its own bridge, and the browser with it, after 15 minutes without a command.
      # .zshenv, like the Hindsight snippet below: every zsh reads it (an ssh login, `zsh -c`, the shell of a Tern session, the shell that omp runs
      # its commands in). Nothing else of the CLI is set: its default is a headless, isolated browser of the stable channel, which is what the link serves.
      programs.zsh.envExtra = ''
        export CHROME_DEVTOOLS_AXI_IDLE_TIMEOUT_MS=900000
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
