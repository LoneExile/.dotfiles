#!/usr/bin/env bash

name="win11-with-package"

[ -q "$(sudo virsh net-list --all | grep "active")" ] || sudo virsh net-start default 
sudo virsh start $name
virt-viewer --connect=qemu:///system --domain-name $name 
