# Generic NixOS guest role for Proxmox VMs.
# Identity (hostname, network) comes from the cloud-init drive at boot; root's
# SSH keys are placed once by `just vm-install`. This file holds no server values.
#
# The root disk is LUKS2. Every boot stops in the initrd until the passphrase arrives, over
# SSH (`just vm-unlock <name>`, port 2222) or typed on the serial console (`qm terminal`).
# The initrd's static address, SSH host key and authorized key are not in this repo or the Nix
# store: `just vm-install` writes them to /etc/secrets/initrd and /root/.ssh on the new system,
# and the bootloader step copies them into the initrd (boot.initrd.secrets) on the unencrypted
# /boot.
{
  config,
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
      # GRUB copies kernel, initrd and secrets of every generation to the 1 GiB /boot.
      configurationLimit = 5;
      extraConfig = ''
        serial --unit=0 --speed=115200
        terminal_input serial console
        terminal_output serial console
      '';
    };
    # ttyS0 is last, so it is the primary console for `qm terminal`, and the LUKS prompt shows there
    kernelParams = ["console=tty0" "console=ttyS0,115200"];

    initrd = {
      # systemd stage 1: it asks for the LUKS passphrase through the ask-password agents
      # (console, or a socket reply from `just vm-unlock`).
      systemd = {
        enable = true;
        extraBin = {
          # `just vm-unlock` answers the passphrase query with this helper: the passphrase is its
          # stdin, so no tty is needed and nothing is echoed.
          systemd-reply-password = "${config.boot.initrd.systemd.package}/lib/systemd/systemd-reply-password";
          ip = "${pkgs.iproute2}/bin/ip";
        };
        # networkd reads its .network files once, so they must be in place before it starts.
        services.systemd-networkd = {
          wants = ["initrd-nixos-copy-secrets.service"];
          after = ["initrd-nixos-copy-secrets.service"];
        };
        # Stopping networkd leaves the address and the UP link behind (measured). Stage 2 would
        # then inherit them: cloud-init could not rename the busy NIC, its network file would
        # not match, and the VM would run on the initrd's address (and wait two minutes for
        # network-online). So stop networkd and clear the NIC before the switch.
        services.initrd-network-teardown = {
          description = "Take the initrd network down before switch-root";
          wantedBy = ["initrd-switch-root.target"];
          before = ["initrd-switch-root.service"];
          after = ["systemd-networkd.service" "systemd-networkd.socket"];
          conflicts = ["systemd-networkd.service" "systemd-networkd.socket"];
          unitConfig.DefaultDependencies = false;
          serviceConfig.Type = "oneshot";
          script = ''
            for d in /sys/class/net/*; do
              n=''${d##*/}
              [ "$n" = lo ] && continue
              ip addr flush dev "$n"
              ip link set dev "$n" down
            done
          '';
        };
      };
      network = {
        enable = true;
        ssh = {
          enable = true;
          port = 2222;
          hostKeys = ["/etc/secrets/initrd/ssh_host_ed25519_key"];
          # The module needs one entry. The real keys arrive as the secret below.
          authorizedKeys = ["# real keys: /var/empty/.ssh/authorized_keys, a boot.initrd.secrets entry"];
        };
      };
      secrets = {
        # The address and gateway of the initrd, written by vm-install. The initrd's /etc ends at
        # switch-root, so unlike /run it cannot shadow cloud-init's network in stage 2.
        "/etc/systemd/network/10-initrd.network" = "/etc/secrets/initrd/10-initrd.network";
        # root's home in the initrd is /var/empty and sshd reads %h/.ssh/authorized_keys there.
        # The source is the file stage 2 uses, so there is one list of keys.
        "/var/empty/.ssh/authorized_keys" = "/root/.ssh/authorized_keys";
      };
    };
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
