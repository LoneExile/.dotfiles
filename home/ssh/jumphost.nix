# The jumphost's ssh entry, one source for the Mac (home/default.nix, programs.ssh) and for the agent VMs
# (home/linux/agent.nix, option dotfiles.agent.jumphost.enable). The Mac adds its own key; a VM has its own key, made on the VM.
# hostKey is the host's ed25519 PUBLIC key (public by design), checked from two machines by its fingerprint:
#   SHA256:nDu2tHrlU9gN+jzGtv3iXaKO774AkdCBvmcG7ehUuJg
# The VM pins it in a known_hosts file of its own and checks it strictly.
{
  # the Host name of the ssh entry (the Mac) and of the VM's ssh entry and Docker context: ssh://<alias>
  alias = "jumphost_server";
  hostname = "192.168.50.29";
  user = "jumphost";
  hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGtFT3RyGLTSTNau0QOUUMviCz+tv/kRSr3makKwyq6e";
}
