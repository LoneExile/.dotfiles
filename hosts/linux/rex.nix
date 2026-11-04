# rex: a CachyOS desktop (Hyprland, the Sunshine stream host), reached over SSH and from the Mac's Tern. The home of
# its user is the agent VMs' (home/linux/agent.nix) with Neovim on top; the desktop and the rest of the system stay
# CachyOS's own (pacman/paru), and no secret is written here: `gh auth login`, ~/.omp/.env and the Neovim config's
# .env.lua are the user's own. The one-time root steps and the first switch are in the README.
{
  inputs,
  lib,
  options,
  pkgs,
  ...
}: let
  inherit (pkgs.stdenv.hostPlatform) system;
  # nixpkgs-unstable with unfree allowed, like the Mac's unstablePkgs (lib/builders.nix): rtk is unfree and only in
  # unstable. The agent pieces' pins read the same instance.
  unstable = import inputs.nixpkgs-unstable {
    inherit system;
    config.allowUnfree = true;
  };
  agentPkgs = import ../../modules/nixos/agent-dev/packages.nix {inherit pkgs unstable;};

  # greetd logs the user in at boot (initial_session in /etc/greetd/config.toml, README), so Sunshine streams without a
  # login at the machine; this locks that session. Noctalia answers `msg session lock` with "ok" before its lock screen
  # can lock (measured: "ok" 1 s after Noctalia started, and the session stayed unlocked), so the proof is logind's
  # LockedHint, which the lock screen sets: ask again until it is set. Only right after boot: a manual login later, or a
  # `just switch` that starts the unit mid-session, must not lock. Exits 1 when it gives up, so a session left unlocked
  # shows as a failed unit.
  lockAfterAutologin = pkgs.writeShellScript "lock-after-autologin" ''
    up=$(cut -d. -f1 /proc/uptime)
    if [ "$up" -gt 300 ]; then
      echo "up ''${up}s, not right after boot: not locking"
      exit 0
    fi
    for i in $(seq 60); do
      session=$(loginctl show-user "$(id -un)" -p Display --value)
      if [ -n "$session" ] && [ "$(loginctl show-session "$session" -p LockedHint --value)" = yes ]; then
        echo "session $session locked after $i tries"
        exit 0
      fi
      /usr/bin/noctalia msg session lock >/dev/null 2>&1 || true
      sleep 1
    done
    echo "the session is NOT locked after 60 s" >&2
    exit 1
  '';
in {
  # What a VM gets on its system PATH from modules/nixos/agent-dev.nix for these pieces, here as packages of the user: gh
  # (the gh piece only makes it git's credential helper) and harper-cli (the captured pi-harper-grammar plugin). curl, gcc
  # and make come from pacman (base-devel).
  home.packages =
    [pkgs.gh agentPkgs.harper]
    # Command-line tools the Mac also has, picked for rex. Desktop programs and services come from pacman (README:
    # Non-NixOS Linux hosts).
    ++ (with pkgs; [
      # shell and files
      yazi
      htop
      atuin
      sshpass
      yq-go
      # git and code
      git-lfs
      git-filter-repo
      jujutsu
      glab
      vale
      xmlformat
      pgformatter
      # databases and APIs
      postgresql_18
      redis
      mongosh
      sqlcmd
      protoc-gen-go
      protoc-gen-go-grpc
      # Kubernetes
      kubernetes-helm
      fluxcd
      talosctl
      kubevirt
      krew
      kubelogin-oidc
      argocd
      k3sup
      skaffold
      telepresence2
      harbor-cli
      # images and registries
      crane
      skopeo
      # cloud and IaC
      opentofu
      terraform
      terragrunt
      packer
      awscli2
      aws-vault
      cloudflared
      # network
      nmap
      bandwhich
      # media and documents
      yt-dlp
      vhs
      asciinema
      asciinema-agg
      # Nix
      alejandra
      deadnix
      statix
      nixpkgs-fmt
    ])
    # Only in unstable.
    ++ [unstable.rtk unstable.llmfit];

  # Games (Steam and Proton from pacman) on the RX 9070 XT: Mesa keeps at most 1 GiB of compiled shaders, and a large game
  # needs more, or it compiles them again at every launch (CachyOS gaming guide). environment.d, so the Hyprland session,
  # Sunshine and everything they start read it.
  systemd.user.sessionVariables.MESA_SHADER_CACHE_MAX_SIZE = "12G";

  # The stream host (README: Stream host on rex). Sunshine's own settings, as a writable file: its web UI saves into it,
  # and an edit made there stays until this copy changes (home/linux/writable-copy.sh). Its pairing state
  # (sunshine_state.json) and web UI login (credentials/) are secrets of the host and stay out of the repo.
  home.activation.sunshineConfig = lib.hm.dag.entryAfter ["writeBoundary"] ''
    ${builtins.readFile ../../home/linux/writable-copy.sh}
    writable_copy ${./rex-sunshine.conf} "$HOME/.config/sunshine/sunshine.conf"
  '';

  systemd.user.services.lock-after-autologin = {
    Unit = {
      Description = "Lock the session greetd logs in at boot, once Noctalia answers";
      After = ["graphical-session.target"];
      PartOf = ["graphical-session.target"];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${lockAfterAutologin}";
    };
    Install.WantedBy = ["graphical-session.target"];
  };

  dotfiles.agent = {
    zsh = {
      enable = true;
      # Standalone Home Manager's profile link (the justfile's `hm_profile` finds the same one); no /run/current-system here.
      generationLink = "\${XDG_STATE_HOME:-$HOME/.local/state}/nix/profiles/home-manager";
    };
    tools.enable = true;
    omp = {
      enable = true;
      package = agentPkgs.omp;
    };
    mise = {
      enable = true;
      package = agentPkgs.mise;
      # No Python: pacman's python3 stays first on PATH. Arch's own Python tools (powerprofilesctl, which
      # `game-performance` runs) start with `#!/usr/bin/env python3` and need its system modules (gi), which mise's lacks.
      tools = builtins.removeAttrs options.dotfiles.agent.mise.tools.default ["python"];
    };
    gh.enable = true;
    tern = {
      enable = true;
      # Arch: /bin and /sbin are links into /usr/bin; tar and zstd for Tern's updater are in base.
      servicePath = "/usr/local/sbin:/usr/local/bin:/usr/bin";
    };
    mason = {
      enable = true;
      toolPackages = agentPkgs.masonTools;
    };
    vault = {
      enable = true;
      packages = agentPkgs.vault;
    };
    sync = {
      plugins = true;
      inherit (agentPkgs) pluginPackages;
    };
    neovim = {
      enable = true;
      # The overlay's own build, at the Mac's commit (lib/builders.nix applies the same overlay on darwin): built against
      # the overlay's pinned nixpkgs, not nixos-25.11's older libraries.
      package = inputs.neovim-nightly-overlay.packages.${system}.default;
      inherit (agentPkgs) treeSitter;
      # No gcc or make from Nix: pacman's (base-devel) build the parsers, and Nix's would come first on PATH, where they
      # find none of the system's headers or libraries and break paru/makepkg builds (measured).
      extraPackages = with pkgs; [ripgrep fd unzip];
    };
  };
}
