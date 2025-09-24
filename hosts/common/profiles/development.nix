{ config, lib, ... }:
{
  # Development host profile configuration
  # This profile enables comprehensive development tools and environments
  
  imports = [
    ../../../profiles/development.nix
  ];
  
  # Enable development profile
  config = {
    profiles.development.enable = true;
    
    # Development-specific host overrides can be added here
    # These settings apply to all hosts using the development profile
    
    # Enhanced development environment
    environment.variables = {
      EDITOR = lib.mkDefault "nvim";
      BROWSER = lib.mkDefault "open";
      DEVELOPMENT_MODE = "true";
    };
    
    # Development-specific system settings
    system.defaults = {
      dock = {
        autohide = lib.mkDefault true;  # More screen space for development
        show-recents = lib.mkDefault false;  # Cleaner dock
      };
      
      finder = {
        ShowPathbar = lib.mkDefault true;  # Useful for development
        ShowStatusBar = lib.mkDefault true;
        AppleShowAllExtensions = lib.mkDefault true;  # See all file types
      };
    };
  };
}