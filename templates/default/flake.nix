{
  description = "Modular Nix configuration based on the template";

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

    # Reference to the main configuration for library functions
    nix-config = {
      url = "github:loneexile/.dotfiles"; # Update this URL
    };
  };

  outputs = {
    self,
    nix-config,
    ...
  } @ inputs: let
    lib = nix-config.lib;
  in {
    darwinConfigurations = {
      # Replace with your hostname
      my-machine = lib.mkDarwin {
        hostname = "my-machine";
        username = "myuser"; # Replace with your username
        system = "aarch64-darwin"; # or "x86_64-darwin"
        profiles = {
          development = true;
          personal = true;
        };
      };
    };
  };
}
