terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 7.25.0"
    }
  }
  required_version = ">= 1.5.0"
}

provider "oci" {
  auth                = "SecurityToken"
  config_file_profile = "DEFAULT"
  region              = var.region
}

module "volume_backup_policy" {
  source         = "../modules/volume-backup-policy"
  compartment_id = var.compartment_id
  volume_ids     = var.volume_ids
  day_of_week    = var.day_of_week
  hour_of_day    = var.hour_of_day
  retention_days = var.retention_days
}

output "policy_id" {
  description = "OCID of the backup policy"
  value       = module.volume_backup_policy.policy_id
}

output "assignment_ids" {
  description = "Backup policy assignment OCIDs, keyed by volume label"
  value       = module.volume_backup_policy.assignment_ids
}
