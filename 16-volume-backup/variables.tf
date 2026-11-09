variable "region" {
  description = "The OCI region to call"
  type        = string
}

variable "compartment_id" {
  description = "The OCID of the compartment that holds the backup policy"
  type        = string
}

variable "volume_ids" {
  description = "Block volume OCIDs to back up, keyed by a stable label. Set them only in the gitignored terraform.tfvars"
  type        = map(string)
}

variable "day_of_week" {
  description = "Day of the weekly backup"
  type        = string
  default     = "SUNDAY"
}

variable "hour_of_day" {
  description = "Hour (UTC) of the weekly backup"
  type        = number
  default     = 3
}

variable "retention_days" {
  description = "Days a scheduled backup is kept"
  type        = number
  default     = 13
}
