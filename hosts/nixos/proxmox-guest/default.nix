# Generic NixOS guest role for Proxmox VMs.
# Identity (hostname, network) comes from the cloud-init drive at boot; root's
# SSH keys are placed once by `just vm-install`. This file holds no server values.
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
      # Identity only. Every module that runs commands, writes files or sets users, passwords
      # or SSH keys is out, so cloud-config keys cannot grant access or run code through a
      # module (the nixpkgs defaults carry bootcmd, runcmd, write-files, users-groups, ssh,
      # set-passwords, scripts-* and phone-home). Network is not a module: it is applied from
      # the drive at init. What stays: hostname (update_hostname), DNS (resolv_conf), growpart,
      # resizefs and migrator (moves cloud-init's own state, runs nothing from the drive).
      # seed_random is out because its `command` key runs a program.
      settings = {
        cloud_init_modules = ["migrator" "growpart" "resizefs" "update_hostname" "resolv_conf"];
        cloud_config_modules = [];
        cloud_final_modules = [];
      };
    };
    openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        PermitRootLogin = "prohibit-password";
      };
    };
    # No guest agent: it is a root-level command channel from the hypervisor into the guest.
    qemuGuest.enable = false;
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
