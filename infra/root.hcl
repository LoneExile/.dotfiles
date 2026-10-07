terraform_binary = "tofu"

locals {
  # Fail early, naming the variable (never a value), when the state store is not configured.
  # Terragrunt has no error(); a run_cmd that exits non-zero aborts evaluation with its stderr.
  s3_endpoint = get_env("TF_STATE_S3_ENDPOINT", "") != "" ? get_env("TF_STATE_S3_ENDPOINT", "") : run_cmd("--terragrunt-quiet", "sh", "-c", "echo 'error: TF_STATE_S3_ENDPOINT is empty (run under secretspec with infra/secretspec.toml: just infra-plan)' >&2; exit 1")
  s3_bucket   = get_env("TF_STATE_S3_BUCKET", "") != "" ? get_env("TF_STATE_S3_BUCKET", "") : run_cmd("--terragrunt-quiet", "sh", "-c", "echo 'error: TF_STATE_S3_BUCKET is empty (run under secretspec with infra/secretspec.toml: just infra-plan)' >&2; exit 1")
}

# The state lives in an S3 bucket on the user's RustFS. RustFS is not AWS: skip the
# AWS-only API checks and use path-style addressing. Credentials come natively from
# AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY. The native lock (use_lockfile) was
# verified on this RustFS: it honours the conditional write, so a second run fails
# with a state-lock error. The key sits under the prefix the dedicated S3 user is
# limited to.
generate "backend" {
  path      = "backend_generated.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOT
    terraform {
      backend "s3" {
        bucket = "${local.s3_bucket}"
        key    = "dotfiles-infra/proxmox-vms/terraform.tfstate"
        region = "us-east-1"
        endpoints = {
          s3 = "${local.s3_endpoint}"
        }
        skip_credentials_validation = true
        skip_metadata_api_check     = true
        skip_region_validation      = true
        skip_requesting_account_id  = true
        skip_s3_checksum            = true
        use_path_style              = true
        use_lockfile                = true
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
