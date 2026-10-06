# Generic NixOS guest role for Proxmox VMs.
# Identity (hostname, network, SSH keys) comes from the cloud-init drive at
# boot; this file holds no server values.
{
  modulesPath,
  pkgs,
  stateVersion,
  ...
}: {
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    ./disko.nix
  ];

  nixpkgs.hostPlatform = "x86_64-linux";

  boot = {
    loader.grub = {
      # disko fills boot.loader.grub.devices
      enable = true;
      extraConfig = ''
        serial --unit=0 --speed=115200
        terminal_input serial console
        terminal_output serial console
      '';
    };
    # ttyS0 is last, so it is the primary console for `qm terminal`
    kernelParams = ["console=tty0" "console=ttyS0,115200"];
  };

  networking = {
    hostName = "";
    useDHCP = false;
    useNetworkd = true;
    firewall.enable = true;
  };

  services = {
    cloud-init = {
      enable = true;
      network.enable = true;
    };
    openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        PermitRootLogin = "prohibit-password";
      };
    };
    qemuGuest.enable = true;
  };

  nix.settings.experimental-features = ["nix-command" "flakes"];
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  environment.systemPackages = with pkgs; [git vim];

  system.stateVersion = stateVersion;
}
