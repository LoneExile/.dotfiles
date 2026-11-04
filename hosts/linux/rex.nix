# rex: a CachyOS desktop (Hyprland, the Sunshine stream host), reached over SSH and from the Mac's Tern. The home of
# its user is the agent VMs' (home/linux/agent.nix) with Neovim on top; the desktop and the rest of the system stay
# CachyOS's own (pacman/paru), and no secret is written here: `gh auth login`, ~/.omp/.env and the Neovim config's
# .env.lua are the user's own. The one-time root steps and the first switch are in the README.
{
  inputs,
  pkgs,
  ...
}: let
  inherit (pkgs.stdenv.hostPlatform) system;
  agentPkgs = import ../../modules/nixos/agent-dev/packages.nix {
    inherit pkgs;
    unstable = inputs.nixpkgs-unstable.legacyPackages.${system};
  };
in {
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
    };
  };
}
