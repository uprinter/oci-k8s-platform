variable "root_compartment_id" {
  description = "The OCID of the root compartment (tenancy)"
  type        = string
}

variable "region" {
  description = "The OCI region to call. Must equal reporting_region"
  type        = string
}

variable "reporting_region" {
  description = "Cloud Guard reporting region"
  type        = string
}

variable "notification_email" {
  description = "Email address for Cloud Guard problem notifications. Set it only in the gitignored terraform.tfvars"
  type        = string
  sensitive   = true
}

variable "min_risk_levels" {
  description = "Cloud Guard risk levels that trigger an email. An empty list sends every detected problem"
  type        = list(string)
  default     = ["CRITICAL", "HIGH"]
}
