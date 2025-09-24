{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.modules.home.development.editors;
in {
  options.modules.home.development.editors.vscode = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Visual Studio Code";
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.vscode;
      description = "VS Code package to use";
    };

    extensions = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [];
      description = "VS Code extensions to install";
    };
  };

  config = lib.mkIf (cfg.enable && cfg.vscode.enable) {
    # VS Code configuration
    programs.vscode = {
      enable = true;
      package = cfg.vscode.package;
      extensions = cfg.vscode.extensions;

      userSettings = {
        "editor.fontSize" = 14;
        "editor.fontFamily" = "'JetBrains Mono', 'Fira Code', monospace";
        "editor.fontLigatures" = true;
        "editor.tabSize" = 2;
        "editor.insertSpaces" = true;
        "editor.wordWrap" = "on";
        "editor.minimap.enabled" = false;
        "editor.rulers" = [80 120];
        "workbench.colorTheme" = "Catppuccin Mocha";
        "terminal.integrated.fontSize" = 14;
        "terminal.integrated.fontFamily" = "'JetBrains Mono'";
      };
    };


  };
}