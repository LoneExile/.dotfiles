{
  description = "Development-focused Nix configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-darwin.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nix-darwin = {
      url = "github:lnl7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };

    nix-config = {
      url = "github:yourusername/nix-config";  # Update this URL
    };
  };

  outputs = { self, nix-config, ... }@inputs:
    let
      lib = nix-config.lib;
    in {
      darwinConfigurations = {
        dev-machine = lib.mkDarwin {
          hostname = "dev-machine";
          username = "developer";
          system = "aarch64-darwin";
          profiles = {
            development = true;
            work = true;
          };
          # Enable additional development modules
          modules = [
            {
              modules.home.development = {
                containers.enable = true;
                languages = {
                  python.enable = true;
                  nodejs.enable = true;
                  rust.enable = true;
                  go.enable = true;
                };
              };
            }
          ];
        };
      };
      
      # Development shell with extra tools
      devShells.aarch64-darwin.default = let
        pkgs = import inputs.nixpkgs { system = "aarch64-darwin"; };
      in pkgs.mkShell {
        buildInputs = with pkgs; [
          # Add development-specific tools here
        ];
      };
    };
}