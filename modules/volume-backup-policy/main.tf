terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 7.25.0"
    }
  }
}

variable "compartment_id" {
  description = "OCID of the compartment that holds the backup policy."
  type        = string
}

variable "display_name" {
  description = "Display name of the backup policy."
  type        = string
  default     = "weekly-incremental"
}

variable "volume_ids" {
  description = "Block volume OCIDs to assign the policy to, keyed by a stable label. Supply them only through the stack's gitignored terraform.tfvars."
  type        = map(string)
}

variable "day_of_week" {
  description = "Day of the weekly backup."
  type        = string
  default     = "SUNDAY"
}

variable "hour_of_day" {
  description = "Hour (UTC) of the weekly backup."
  type        = number
  default     = 3
}

variable "retention_days" {
  description = "Days a scheduled backup is kept. With a weekly schedule, 13 keeps at most two backups per volume."
  type        = number
  default     = 13

  validation {
    condition     = var.retention_days >= 1 && var.retention_days < 14
    error_message = "retention_days must be between 1 and 13. With a weekly schedule, 14 or more keeps three backups per volume."
  }
}

resource "oci_core_volume_backup_policy" "this" {
  compartment_id = var.compartment_id
  display_name   = var.display_name

  schedules {
    backup_type       = "INCREMENTAL"
    period            = "ONE_WEEK"
    day_of_week       = var.day_of_week
    hour_of_day       = var.hour_of_day
    offset_type       = "STRUCTURED"
    time_zone         = "UTC"
    retention_seconds = var.retention_days * 86400
  }
}

resource "oci_core_volume_backup_policy_assignment" "this" {
  for_each = var.volume_ids

  asset_id  = each.value
  policy_id = oci_core_volume_backup_policy.this.id
}

output "policy_id" {
  description = "OCID of the backup policy"
  value       = oci_core_volume_backup_policy.this.id
}

output "assignment_ids" {
  description = "Backup policy assignment OCIDs, keyed by volume label"
  value       = { for k, a in oci_core_volume_backup_policy_assignment.this : k => a.id }
}
