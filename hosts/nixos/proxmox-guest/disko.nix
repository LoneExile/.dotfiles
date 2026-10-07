{
  disko.devices.disk.main = {
    device = "/dev/sda";
    type = "disk";
    content = {
      type = "gpt";
      partitions = {
        # GRUB (SeaBIOS) core image. It never touches LUKS: it reads the unencrypted /boot below.
        bios = {
          size = "1M";
          type = "EF02";
        };
        # Kernel, initrd and the initrd secrets (one set per generation). Not encrypted.
        boot = {
          size = "1G";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/boot";
          };
        };
        root = {
          size = "100%";
          content = {
            type = "luks";
            name = "cryptroot";
            # Read by disko when it formats the disk, from a file that `just vm-install` uploads
            # to the installer (nixos-anywhere --disk-encryption-keys). The booted system
            # does not use it: the initrd asks for the passphrase.
            passwordFile = "/tmp/luks-passphrase";
            # allowDiscards stays off: TRIM through LUKS shows which blocks are free.
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
            };
          };
        };
      };
    };
  };
}
