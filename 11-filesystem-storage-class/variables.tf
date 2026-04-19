variable "root_compartment_id" {
  description = "The OCID of the root compartment"
  type        = string
}

variable "region" {
  description = "The OCI region to deploy resources in"
  type        = string
}

variable "k8s_context" {
  description = "Kubernetes context to use"
  type        = string
}

variable "storage_class_name" {
  description = "Name of the Kubernetes storage class"
  type        = string
  default     = "oci-fss"
}

variable "availability_domain" {
  description = "Availability domain name for the file system. If omitted, the first AD in the tenancy is used."
  type        = string
  default     = null
}

variable "mount_target_subnet_ocid" {
  description = "Subnet OCID where this stack should create the shared mount target"
  type        = string
}

variable "mount_target_display_name" {
  description = "Display name for the shared OCI File Storage mount target"
  type        = string
  default     = "oke-fss-mount-target"
}

variable "compartment_ocid" {
  description = "Compartment OCID for the dynamically created file system and mount target"
  type        = string
  default     = null
}

variable "kms_key_ocid" {
  description = "Optional KMS key OCID for at-rest encryption"
  type        = string
  default     = null
}

variable "export_path" {
  description = "Optional export path for the file system"
  type        = string
  default     = null
}

variable "export_options_json" {
  description = "Optional raw JSON string for exportOptions"
  type        = string
  default     = null
}

variable "encrypt_in_transit" {
  description = "Whether to enable in-transit encryption"
  type        = bool
  default     = false
}

variable "defined_tags_override_json" {
  description = "Optional raw JSON string for defined tags override"
  type        = string
  default     = null
}

variable "freeform_tags_override_json" {
  description = "Optional raw JSON string for freeform tags override"
  type        = string
  default     = null
}

variable "reclaim_policy" {
  description = "Storage class reclaim policy"
  type        = string
  default     = "Delete"
}

variable "volume_binding_mode" {
  description = "Storage class volume binding mode"
  type        = string
  default     = "Immediate"
}

variable "allow_volume_expansion" {
  description = "Whether PVC expansion is allowed"
  type        = bool
  default     = false
}
