{ config, lib, pkgs, inputs, outputs, hostname, system, username, unstablePkgs, ... }:
{
  # Host-specific configuration template
  # Copy this file to hosts/{hostname}/default.nix and customize as needed
  
  imports = [
    ../common/default.nix
    # Select one of the available profiles:
    # ../common/profiles/minimal.nix     # For minimal setups
    # ../common/profiles/development.nix # For development environments
    # ../common/profiles/work.nix        # For work environments
    # ../common/profiles/personal.nix    # For personal use
  ];
  
  # Host identification
  networking.hostName = "HOSTNAME";  # Replace with actual hostname
  networking.computerName = "HOSTNAME";
  
  # User configuration
  users.users.USERNAME = {  # Replace USERNAME with actual username
    home = "/Users/USERNAME";
    description = "Full Name";  # Replace with actual name
  };
  
  # Set primary user for system-wide activation
  system.primaryUser = "USERNAME";  # Replace with actual username
  
  # Host-specific configuration
  config = {
    # Enable the selected profile
    profiles = {
      minimal.enable = false;
      development.enable = false;
      work.enable = false;
      personal.enable = false;  # Set one of these to true
    };
    
    # Host-specific system packages
    environment.systemPackages = with pkgs; [
      # Add host-specific packages here
    ];
    
    # Host-specific fonts (optional)
    fonts.packages = with pkgs; [
      # Add host-specific fonts here
    ];
    
    # Host-specific Homebrew configuration (optional)
    homebrew = {
      enable = false;  # Set to true if using Homebrew
      
      brews = [
        # Add host-specific brews here
      ];
      
      casks = [
        # Add host-specific casks here
      ];
      
      masApps = {
        # Add host-specific Mac App Store apps here
      };
    };
    
    # Host-specific system defaults (optional overrides)
    system.defaults = {
      # Add host-specific system defaults here
      # These will override profile defaults
    };
    
    # Host-specific activation scripts (optional)
    system.activationScripts.extraActivation.text = ''
      # Add host-specific activation scripts here
      echo "Host-specific activation for HOSTNAME"
    '';
  };
}