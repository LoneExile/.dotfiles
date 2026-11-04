# The packages of the agent pieces (home/linux/agent.nix), in one place: the NixOS module
# (../agent-dev.nix) and the standalone Linux hosts (hosts/linux/<host>.nix) both read this file,
# so a pin cannot differ between a VM and a host.
#
# `unstable` is nixpkgs-unstable for the same system. It supplies what nixos-25.11 lacks or has too
# old: mise (below), bun and node (the plugin install service reads a lockfile that a current bun
# wrote) and secretspec (25.11's is 0.3.3; the UnitLLM repo's vault:// manifests need a current one).
{
  pkgs,
  unstable,
}: {
  # The one pin of omp (omp.nix: version and hash). The system PATH of a VM gets it as the fallback, and Home Manager copies it to
  # ~/.local/bin/omp as the seed of the user's own copy, which `omp update` can replace (home/linux/agent.nix, home/linux/seed-user-binary.sh).
  # Both read this one value, so there is no second pin.
  omp = pkgs.callPackage ./omp.nix {};

  # nixos-25.11's default pkgs.docker (28.5.2) is marked insecure (unmaintained since November 2025) and refuses to evaluate;
  # docker_29 is in the same nixpkgs. The one package of the rootless daemon and of the CLI that Home Manager runs.
  docker = pkgs.docker_29;

  # nixos-25.11's mise (2025.11.7) takes the free-threaded CPython build of
  # python-build-standalone for 3.13 and later and fails with "Python installation is
  # missing a `lib` directory" (measured on the VM). nixpkgs-unstable's mise (2026.8.6)
  # installs python 3.14 from the same release.
  inherit (unstable) mise;

  # bao from nixos-25.11 (openbao 2.5.5: its bin holds `bao` and no `vault` alias); secretspec from nixpkgs-unstable (0.21.1).
  vault = [pkgs.openbao unstable.secretspec];

  # bun and node on the PATH of the plugin install service.
  pluginPackages = [unstable.bun unstable.nodejs_24];

  # harper-cli for the captured pi-harper-grammar plugin (`harper-cli lint`): only the unstable package builds harper-cli,
  # 25.11's has harper-ls alone. A VM gets it on the system PATH, a Linux host as a package of the user.
  inherit (unstable) harper;

  # The tree-sitter CLI of the neovim piece: nvim-treesitter's main branch refuses one older than 0.26.1 (checkhealth),
  # nixos-25.11 has 0.25.10, and the Mac runs unstable's (0.26.11).
  treeSitter = unstable.tree-sitter;

  # What the install of the listed servers runs, measured with every one of them (README): curl for
  # the registry and the release assets, gzip and tar to unpack them, getconf for Mason's glibc
  # check (without it Mason takes NixOS for an unsupported platform), node with npm for the npm
  # packages, go for gopls, and for nil, which is built from a git tag, cargo with rustc (1.6 GiB
  # of closure), a C compiler, git and nix (its build script runs nix). Node is the one of the
  # plugin install, so that the closure holds one; gcc, git and nix are in the closure anyway.
  masonTools = [unstable.nodejs_24 pkgs.go pkgs.getconf pkgs.curl pkgs.gzip pkgs.gnutar pkgs.cargo pkgs.rustc pkgs.gcc pkgs.git pkgs.nix];
}
