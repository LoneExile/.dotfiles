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
    unstablePkgs.syncthing-macos

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
