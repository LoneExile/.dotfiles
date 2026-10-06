output "vms" {
  description = "VM name to address, node and vmid."
  value = {
    for k, v in var.vms : k => {
      ip   = split("/", v.ipv4_cidr)[0]
      node = v.node
      vmid = v.vmid
    }
  }
}
