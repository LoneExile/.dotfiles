# Home Manager module tests
{
  inputs,
  outputs,
  system,
  lib,
  pkgs,
  testLib,
  ...
}: let
  # Import Home Manager modules for testing
  homeModules = {
    shell = {
      zsh = ../../modules/home/shell/zsh.nix;
      starship = ../../modules/home/shell/starship.nix;
      aliases = ../../modules/home/shell/aliases.nix;
    };
    development = {
      git = ../../modules/home/development/git.nix;
      editors = ../../modules/home/development/editors.nix;
      languages = ../../modules/home/development/languages.nix;
      containers = ../../modules/home/development/containers.nix;
    };
    desktop = {
      terminal = ../../modules/home/desktop/terminal.nix;
      windowManager = ../../modules/home/desktop/window-manager.nix;
      productivity = ../../modules/home/desktop/productivity.nix;
    };
    security = {
      gpg = ../../modules/home/security/gpg.nix;
      ssh = ../../modules/home/security/ssh.nix;
    };
  };

  # Shell module tests
  shellTests = [
    # Zsh module tests
    (testLib.mkTest {
      name = "home-shell-zsh-module";
      assertions =
        # Test module structure
        testLib.moduleUtils.testModuleStructure "modules.home.shell.zsh" {
          enable = true;
          enableAutosuggestions = true;
          enableSyntaxHighlighting = true;
          historySize = 10000;
        }
        ++
        # Test module evaluation
        testLib.moduleUtils.testModuleEvaluation "modules.home.shell.zsh" homeModules.shell.zsh
        ++
        # Test different configurations
        testLib.moduleUtils.testModuleConfigurations "modules.home.shell.zsh" homeModules.shell.zsh {
          minimal = {
            enableAutosuggestions = false;
            enableSyntaxHighlighting = false;
          };

          customHistory = {
            historySize = 50000;
          };

          withZap = {
            enableZap = true;
          };

          withoutZap = {
            enableZap = false;
          };
        };
    })

    # Starship module tests
    (testLib.mkTest {
      name = "home-shell-starship-module";
      assertions =
        testLib.moduleUtils.testModuleStructure "modules.home.shell.starship" {
          enable = true;
        }
        ++ testLib.moduleUtils.testModuleEvaluation "modules.home.shell.starship" homeModules.shell.starship;
    })

    # Aliases module tests
    (testLib.mkTest {
      name = "home-shell-aliases-module";
      assertions =
        testLib.moduleUtils.testModuleStructure "modules.home.shell.aliases" {
          enable = true;
        }
        ++ testLib.moduleUtils.testModuleEvaluation "modules.home.shell.aliases" homeModules.shell.aliases;
    })
  ];

  # Development module tests
  developmentTests = [
    # Git module tests
    (testLib.mkTest {
      name = "home-development-git-module";
      assertions =
        testLib.moduleUtils.testModuleStructure "modules.home.development.git" {
          enable = true;
          userName = "Test User";
          userEmail = "test@example.com";
        }
        ++ testLib.moduleUtils.testModuleEvaluation "modules.home.development.git" homeModules.development.git
        ++ testLib.moduleUtils.testModuleConfigurations "modules.home.development.git" homeModules.development.git {
          basic = {
            userName = "Test User";
            userEmail = "test@example.com";
          };

          withSigning = {
            userName = "Test User";
            userEmail = "test@example.com";
            signing.enable = true;
            signing.key = "test-key";
          };
        };
    })

    # Editors module tests
    (testLib.mkTest {
      name = "home-development-editors-module";
      assertions =
        testLib.moduleUtils.testModuleStructure "modules.home.development.editors" {
          enable = true;
        }
        ++ testLib.moduleUtils.testModuleEvaluation "modules.home.development.editors" homeModules.development.editors;
    })

    # Languages module tests
    (testLib.mkTest {
      name = "home-development-languages-module";
      assertions =
        testLib.moduleUtils.testModuleStructure "modules.home.development.languages" {
          enable = true;
        }
        ++ testLib.moduleUtils.testModuleEvaluation "modules.home.development.languages" homeModules.development.languages;
    })

    # Containers module tests
    (testLib.mkTest {
      name = "home-development-containers-module";
      assertions =
        testLib.moduleUtils.testModuleStructure "modules.home.development.containers" {
          enable = true;
        }
        ++ testLib.moduleUtils.testModuleEvaluation "modules.home.development.containers" homeModules.development.containers;
    })
  ];

  # Desktop module tests
  desktopTests = [
    # Terminal module tests
    (testLib.mkTest {
      name = "home-desktop-terminal-module";
      assertions =
        testLib.moduleUtils.testModuleStructure "modules.home.desktop.terminal" {
          enable = true;
        }
        ++ testLib.moduleUtils.testModuleEvaluation "modules.home.desktop.terminal" homeModules.desktop.terminal;
    })

    # Window manager module tests
    (testLib.mkTest {
      name = "home-desktop-window-manager-module";
      assertions =
        testLib.moduleUtils.testModuleStructure "modules.home.desktop.window-manager" {
          enable = true;
        }
        ++ testLib.moduleUtils.testModuleEvaluation "modules.home.desktop.window-manager" homeModules.desktop.windowManager;
    })

    # Productivity module tests
    (testLib.mkTest {
      name = "home-desktop-productivity-module";
      assertions =
        testLib.moduleUtils.testModuleStructure "modules.home.desktop.productivity" {
          enable = true;
        }
        ++ testLib.moduleUtils.testModuleEvaluation "modules.home.desktop.productivity" homeModules.desktop.productivity;
    })
  ];

  # Security module tests
  securityTests = [
    # GPG module tests
    (testLib.mkTest {
      name = "home-security-gpg-module";
      assertions =
        testLib.moduleUtils.testModuleStructure "modules.home.security.gpg" {
          enable = true;
        }
        ++ testLib.moduleUtils.testModuleEvaluation "modules.home.security.gpg" homeModules.security.gpg;
    })

    # SSH module tests
    (testLib.mkTest {
      name = "home-security-ssh-module";
      assertions =
        testLib.moduleUtils.testModuleStructure "modules.home.security.ssh" {
          enable = true;
        }
        ++ testLib.moduleUtils.testModuleEvaluation "modules.home.security.ssh" homeModules.security.ssh;
    })
  ];
in
  shellTests ++ developmentTests ++ desktopTests ++ securityTests
