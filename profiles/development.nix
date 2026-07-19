{
  config,
  lib,
  pkgs,
  unstablePkgs,
  ...
}: {
  # Development loadout: language tools, container/k8s tooling, terminal
  # utilities, and nerd-fonts for terminal use.

  environment.variables = {
    EDITOR = lib.mkForce "nvim";
    BROWSER = lib.mkForce "open";
  };

  environment.systemPackages = with pkgs; [
    # Media / personal-but-CLI
    unstablePkgs.yt-dlp
    unstablePkgs.get_iplayer

    # Cloud / k8s / containers
    unstablePkgs.colmena
    unstablePkgs.colima
    unstablePkgs.docker
    unstablePkgs.lazydocker
    unstablePkgs.lima
    unstablePkgs.k9s
    unstablePkgs.kubectl
    unstablePkgs.kubernetes-helm
    unstablePkgs.kubevirt
    unstablePkgs.fluxcd
    unstablePkgs.talosctl
    unstablePkgs.skopeo
    unstablePkgs.harbor-cli
    unstablePkgs.aws-vault
    unstablePkgs.awscli2
    unstablePkgs.hcloud

    # Editors / terminal
    unstablePkgs.wezterm
    unstablePkgs.yazi

    # CLI utilities
    unstablePkgs.btop
    unstablePkgs.dust
    unstablePkgs.bandwhich
    unstablePkgs.lsof
    unstablePkgs.gh
    unstablePkgs.just
    unstablePkgs.comma
    unstablePkgs.parallel
    unstablePkgs.gettext
    unstablePkgs.yq-go
    unstablePkgs.poetry
    # Syncthing pinned to 2.1.2-1 ahead of nixpkgs (still on 2.0.14-1).
    # Remove this override once nixpkgs-unstable ships >= 2.1.2-1.
    (unstablePkgs.syncthing-macos.overrideAttrs (_: rec {
      version = "2.1.2-1";
      src = unstablePkgs.fetchurl {
        url = "https://github.com/syncthing/syncthing-macos/releases/download/v${version}/Syncthing-${version}.dmg";
        hash = "sha256-vlb8mAe8XjczIje6R5t3vehSxfDYYclQZ0JVmZu7oPY=";
      };
    }))

    # Remote access / DB
    unstablePkgs.freerdp
    unstablePkgs.sqlcmd
    unstablePkgs.sshpass

    # Media tooling
    unstablePkgs.qbittorrent-enhanced
    unstablePkgs.jellyfin-ffmpeg

    # Nix tooling
    unstablePkgs.statix
    unstablePkgs.deadnix
    unstablePkgs.alejandra
    unstablePkgs.jujutsu

    unstablePkgs.qpdf
    # unstablePkgs.samply  # samply is a command line CPU profiler
    unstablePkgs.aria2
    unstablePkgs.shaka-packager

    # Stable
    packer
    obsidian
  ];

  fonts.packages = [
    pkgs.nerd-fonts.fira-code
    pkgs.nerd-fonts.fira-mono
    pkgs.nerd-fonts.hack
    pkgs.nerd-fonts.jetbrains-mono
  ];
}
