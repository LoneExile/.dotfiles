terraform_binary = "tofu"

locals {
  # State lives outside the worktree and outside .terragrunt-cache.
  state_dir = "${get_env("XDG_STATE_HOME", "${get_env("HOME")}/.local/state")}/dotfiles-infra/proxmox-vms"
}

terraform {
  before_hook "state_dir" {
    commands = ["init", "validate", "plan", "apply", "destroy", "output", "state", "import", "refresh", "providers", "show", "taint", "untaint", "force-unlock", "console", "graph", "test", "workspace"]
    execute  = ["mkdir", "-p", local.state_dir]
  }
}

generate "backend" {
  path      = "backend_generated.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOT
    terraform {
      backend "local" {
        path = "${local.state_dir}/terraform.tfstate"
      }
    }
  EOT
}

generate "encryption" {
  path      = "encryption_generated.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOT
    variable "tofu_state_passphrase" {
      description = "Passphrase for OpenTofu state encryption."
      type        = string
      sensitive   = true
    }

    terraform {
      encryption {
        key_provider "pbkdf2" "state" {
          passphrase = var.tofu_state_passphrase
        }
        method "aes_gcm" "state" {
          keys = key_provider.pbkdf2.state
        }
        state {
          method   = method.aes_gcm.state
          enforced = true
        }
        plan {
          method   = method.aes_gcm.state
          enforced = true
        }
      }
    }
  EOT
}

generate "provider" {
  path      = "provider_generated.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOT
    variable "proxmox_endpoint" {
      type = string
    }

    variable "proxmox_api_token" {
      type      = string
      sensitive = true
    }

    variable "proxmox_insecure" {
      type = bool
    }

    provider "proxmox" {
      endpoint  = var.proxmox_endpoint
      api_token = var.proxmox_api_token
      insecure  = var.proxmox_insecure
    }
  EOT
}
