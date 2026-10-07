output "vms" {
  description = "VM name to address, node, vmid and role."
  value = {
    for k, v in var.vms : k => {
      ip   = split("/", v.ipv4_cidr)[0]
      node = v.node
      vmid = v.vmid
      role = v.role
    }
  }
}
