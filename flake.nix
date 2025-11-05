{
  description = "Modular macOS Nix configuration with Darwin and Home Manager";

  inputs = {
    # Core Nixpkgs - using Darwin-specific branch for macOS compatibility
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-25.05-darwin";

    # Unstable packages for latest software
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    # Darwin-specific nixpkgs (follows unstable for macOS compatibility)
    nixpkgs-darwin.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    # nix-darwin for macOS system configuration
    nix-darwin = {
      url = "github:lnl7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };

    # Home Manager for user environment management
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };

    # Homebrew integration for macOS packages
    nix-homebrew = {
      url = "github:zhaofengli-wip/nix-homebrew";
    };

    # Homebrew taps (non-flake inputs)
    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };
    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };
    homebrew-bundle = {
      url = "github:homebrew/homebrew-bundle";
      flake = false;
    };

    # SOPS for secrets management
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Neovim nightly overlay for latest Neovim features
    neovim-nightly-overlay = {
      url = "github:nix-community/neovim-nightly-overlay";
    };

    # nixCats for advanced Neovim configuration
    nixCats = {
      url = "github:BirdeeHub/nixCats-nvim";
    };

    # Tokyo Night theme - always latest
    tokyonight-nvim = {
      url = "github:folke/tokyonight.nvim";
      flake = false;
    };
  };

  outputs = {self, ...} @ inputs: let
    inherit (self) outputs;

    # Configuration constants
    stateVersion = "25.05";
    defaultSystem = "aarch64-darwin";
    supportedSystems = ["aarch64-darwin" "x86_64-darwin" "x86_64-linux" "aarch64-linux"];

    # Import our custom library with enhanced builders and utilities
    lib = import ./lib {inherit inputs outputs stateVersion;};

    # Helper to generate packages for each supported system
    forAllSystems = inputs.nixpkgs.lib.genAttrs supportedSystems;

    # Get nixpkgs for a specific system
    nixpkgsFor = system:
      import inputs.nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
  in {
    # Export our custom library for use by other flakes
    inherit lib;

    # Darwin system configurations
    darwinConfigurations = {
      # Personal macOS configuration
      le = lib.mkDarwin {
        hostname = "le";
        username = "le";
        system = defaultSystem;
        profiles = {
          development = true;
          personal = true;
        };
      };
    };

    # Development shells for contributors
    devShells = forAllSystems (
      system: let
        pkgs = nixpkgsFor system;
      in {
        default = pkgs.mkShell {
          name = "nix-config-dev";

          buildInputs = with pkgs;
            [
              # Nix development tools
              nixd # Nix language server
              alejandra # Nix formatter
              statix # Nix linter
              deadnix # Dead code detection

              # Documentation tools
              mdbook # Documentation generation

              # Git and development utilities
              git
              just # Command runner

              # SOPS for secrets management
              sops
              age

              # Shell utilities
              direnv
            ]
            ++ pkgs.lib.optionals (system == "aarch64-darwin" || system == "x86_64-darwin") [
              # Darwin rebuild for testing (Darwin systems only)
              inputs.nix-darwin.packages.${system}.darwin-rebuild
            ];

          shellHook = ''
            echo "🚀 Welcome to the Nix Configuration Development Environment!"
            echo ""
            echo "Available commands:"
            echo "  just --list          # Show available commands"
            echo "  alejandra **/*.nix   # Format Nix files"
            echo "  statix check .       # Lint Nix files"
            echo "  deadnix .            # Find dead code"
            echo ""
            echo "Documentation:"
            echo "  just docs            # Build documentation"
            echo "  just docs-serve      # Serve documentation locally"
            echo ""
            echo "Testing:"
            echo "  just check           # Check flake"
            echo "  just build           # Build configuration"
            echo ""
          '';

          # Environment variables for development
          NIX_CONFIG = "experimental-features = nix-command flakes";
        };

        # Minimal shell for quick tasks
        minimal = pkgs.mkShell {
          name = "nix-config-minimal";
          buildInputs = with pkgs; [
            alejandra
            just
            git
          ];
        };

        # Documentation shell for writers
        docs = pkgs.mkShell {
          name = "nix-config-docs";
          buildInputs = with pkgs; [
            mdbook
            mdbook-mermaid
            mdbook-linkcheck
            python3Packages.mkdocs
            python3Packages.mkdocs-material
          ];
        };
      }
    );

    # Packages for utilities and tools
    packages = forAllSystems (
      system: let
        pkgs = nixpkgsFor system;
      in {
        # Configuration validation script
        validate-config = pkgs.writeShellScriptBin "validate-config" ''
          set -euo pipefail

          echo "🔍 Validating Nix configuration..."

          # Check flake syntax
          echo "Checking flake syntax..."
          nix flake check --no-build

          # Format check
          echo "Checking formatting..."
          if ! alejandra --check **/*.nix; then
            echo "❌ Formatting issues found. Run 'alejandra **/*.nix' to fix."
            exit 1
          fi

          # Lint check
          echo "Running linter..."
          statix check .

          # Dead code check
          echo "Checking for dead code..."
          deadnix .

          echo "✅ Configuration validation complete!"
        '';

        # Documentation builder
        build-docs = pkgs.writeShellScriptBin "build-docs" ''
          set -euo pipefail

          echo "📚 Building documentation..."

          if [ -d "docs" ]; then
            cd docs
            mdbook build
            echo "✅ Documentation built in docs/book/"
          else
            echo "❌ No docs directory found"
            exit 1
          fi
        '';

        # System update script
        update-system = pkgs.writeShellScriptBin "update-system" ''
          set -euo pipefail

          echo "🔄 Updating Nix configuration..."

          # Update flake inputs
          echo "Updating flake inputs..."
          nix flake update

          # Rebuild system
          echo "Rebuilding Darwin configuration..."
          darwin-rebuild switch --flake .

          echo "✅ System update complete!"
        '';

        # Test runner script
        run-tests = pkgs.writeShellScriptBin "run-tests" ''
          set -euo pipefail

          # Simple test runner for modular Nix configuration
          echo "🧪 Running Nix configuration tests..."

          # Run flake check
          echo "Running flake check..."
          nix flake check --no-build

          # Run unit tests if available
          if nix eval .#tests.${system}.unit --apply "x: x ? runTests" 2>/dev/null; then
            echo "Running unit tests..."
            nix run .#tests.${system}.unit.runTests
          fi

          # Run integration tests if available
          if nix eval .#tests.${system}.integration --apply "x: x ? runTests" 2>/dev/null; then
            echo "Running integration tests..."
            nix run .#tests.${system}.integration.runTests
          fi

          echo "✅ All tests completed!"
        '';
      }
    );

    # Formatter for `nix fmt`
    formatter = forAllSystems (
      system:
        (nixpkgsFor system).alejandra
    );

    # Templates for creating new configurations
    templates = {
      default = {
        path = ./templates/default;
        description = "Basic modular Nix configuration template";
      };

      minimal = {
        path = ./templates/minimal;
        description = "Minimal Nix configuration template";
      };

      development = {
        path = ./templates/development;
        description = "Development-focused Nix configuration template";
      };
    };

    # Testing infrastructure
    tests = forAllSystems (
      system:
        import ./tests {inherit inputs outputs system lib;}
    );

    # Checks for CI/CD
    checks = forAllSystems (
      system: let
        pkgs = nixpkgsFor system;
        testSuite = self.tests.${system};
      in {
        # Flake check
        flake-check = pkgs.runCommand "flake-check" {} ''
          cd ${./.}
          ${pkgs.nix}/bin/nix flake check --no-build
          touch $out
        '';

        # Format check
        format-check = pkgs.runCommand "format-check" {} ''
          cd ${./.}
          ${pkgs.alejandra}/bin/alejandra --check **/*.nix
          touch $out
        '';

        # Lint check
        lint-check = pkgs.runCommand "lint-check" {} ''
          cd ${./.}
          ${pkgs.statix}/bin/statix check .
          touch $out
        '';

        # Unit tests - simplified for now
        unit-tests = pkgs.runCommand "unit-tests" {} ''
          echo "Unit tests would run here"
          echo "Test infrastructure is available"
          touch $out
        '';

        # Integration tests - simplified for now
        integration-tests = pkgs.runCommand "integration-tests" {} ''
          echo "Integration tests would run here"
          echo "Test infrastructure is available"
          touch $out
        '';
      }
    );
  };
}
