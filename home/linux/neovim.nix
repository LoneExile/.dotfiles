# The Neovim piece (home/linux/agent.nix imports it; off unless a host turns it on): Neovim on the user's PATH, the programs
# its config calls, and the config itself, a clone of configRepo made once into configDir by clone-once.sh. The clone is the
# user's from then on, as on the Mac: a later switch never pulls, resets or replaces it, and a switch without network only
# warns. The config's .env.lua (gitignored there) is the user's own file.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.dotfiles.agent.neovim;
in {
  options.dotfiles.agent.neovim = {
    enable = lib.mkEnableOption "Neovim, the programs its config calls, and a clone of the config made once";
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.neovim;
      defaultText = lib.literalExpression "pkgs.neovim";
      description = "The Neovim package (a host names the nightly build the Mac runs).";
    };
    configRepo = lib.mkOption {
      type = lib.types.str;
      default = "https://github.com/LoneExile/nvim";
      description = "The repo of the config, cloned once (it is public: HTTPS needs no key).";
    };
    configDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.xdg.configHome}/nvim";
      defaultText = lib.literalExpression ''"''${config.xdg.configHome}/nvim"'';
      description = "Where the config is cloned. Anything already there is left as it is.";
    };
    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = with pkgs; [ripgrep fd gcc gnumake unzip tree-sitter];
      defaultText = lib.literalExpression "with pkgs; [ripgrep fd gcc gnumake unzip tree-sitter]";
      description = "The programs the config calls (search, parser builds, Mason's unpacking), as packages of the user.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [cfg.package] ++ cfg.extraPackages;

    home.activation.neovimConfig = lib.hm.dag.entryAfter ["writeBoundary"] ''
      ${builtins.readFile ./clone-once.sh}
      clone_once ${pkgs.git}/bin/git ${lib.escapeShellArg cfg.configRepo} ${lib.escapeShellArg cfg.configDir}
    '';
  };
}
