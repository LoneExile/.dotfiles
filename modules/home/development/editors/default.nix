{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.modules.home.development.editors;
in {
  imports = [
    ./neovim.nix
    ./vscode.nix
    ./helix.nix
  ];

  options.modules.home.development.editors = {
    enable = lib.mkEnableOption "Development editors configuration";
  };

  config = lib.mkIf cfg.enable {
    # The main enable flag is handled by individual editor modules
    # Each editor module checks both cfg.enable and cfg.{editor}.enable
    # This ensures the main enable flag controls all editor functionality
    
    # Add editor packages to home.packages when their respective editors are enabled
    # This mirrors the behavior from the original monolithic editors.nix file
    home.packages = lib.mkMerge [
      (lib.mkIf cfg.neovim.enable [cfg.neovim.package])
      (lib.mkIf cfg.vscode.enable [cfg.vscode.package])
      (lib.mkIf cfg.helix.enable [cfg.helix.package])
    ];
  };
}