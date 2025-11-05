{
  description = "Minimal Nix configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nix-darwin = {
      url = "github:lnl7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
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
      my-machine = lib.mkDarwin {
        hostname = "my-machine";
        username = "myuser";
        system = "aarch64-darwin";
        profiles = {
          minimal = true;
        };
      };
    };
  };
}
