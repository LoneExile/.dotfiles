variable "image_datastore" {
  description = "Directory datastore that accepts import content."
  type        = string
}

variable "vm_datastore" {
  description = "Block datastore for VM disks."
  type        = string
}

variable "network_bridge" {
  description = "Bridge for the first network device."
  type        = string
}

variable "ssh_authorized_keys" {
  description = "Newline-separated SSH public keys."
  type        = string
}

variable "vms" {
  description = "VMs to create, keyed by name (the name becomes the hostname)."
  type = map(object({
    node      = string
    vmid      = number
    mac       = string
    ipv4_cidr = string
    gateway   = string
    dns       = list(string)
    cores     = number
    memory_mb = number
    disk_gb   = number
  }))

  validation {
    condition     = alltrue([for k, v in var.vms : can(regex("^[a-z0-9][a-z0-9-]{2,61}[a-z0-9]$", k))])
    error_message = "Every VM name must be a DNS label: lowercase letters, digits and hyphens, 4 to 63 characters, no leading or trailing hyphen."
  }

  validation {
    condition     = length(distinct([for v in var.vms : v.vmid])) == length(var.vms)
    error_message = "Every VM must have a distinct vmid."
  }

  validation {
    condition     = length(distinct([for v in var.vms : lower(v.mac)])) == length(var.vms)
    error_message = "Every VM must have a distinct mac (compared case-insensitively)."
  }

  validation {
    condition     = length(distinct([for v in var.vms : split("/", v.ipv4_cidr)[0]])) == length(var.vms)
    error_message = "Every VM must have a distinct IPv4 address."
  }

  validation {
    condition     = alltrue([for v in var.vms : can(cidrnetmask(v.ipv4_cidr))])
    error_message = "Every ipv4_cidr must be a valid IPv4 address with prefix length, such as <ipv4>/<prefix>."
  }
}
