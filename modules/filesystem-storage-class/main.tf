variable "name" {
  description = "Name of the Kubernetes storage class"
  type        = string
}

variable "availability_domain" {
  description = "OCI availability domain where the file system should be created"
  type        = string
}

variable "mount_target_ocid" {
  description = "Existing OCI File Storage mount target OCID"
  type        = string
}

variable "compartment_ocid" {
  description = "Compartment OCID for the file system and mount target"
  type        = string
  default     = null
}

variable "kms_key_ocid" {
  description = "KMS key OCID for at-rest encryption"
  type        = string
  default     = null
}

variable "export_path" {
  description = "Optional export path for the file system"
  type        = string
  default     = null
}

variable "export_options_json" {
  description = "Optional export options JSON string expected by the OCI FSS CSI driver"
  type        = string
  default     = null
}

variable "encrypt_in_transit" {
  description = "Whether to enable in-transit encryption for the file system"
  type        = bool
  default     = false
}

variable "defined_tags_override_json" {
  description = "Optional defined tags override JSON string for dynamically created file systems"
  type        = string
  default     = null
}

variable "freeform_tags_override_json" {
  description = "Optional freeform tags override JSON string for dynamically created file systems"
  type        = string
  default     = null
}

variable "reclaim_policy" {
  description = "Reclaim policy for the storage class"
  type        = string
  default     = "Delete"
}

variable "volume_binding_mode" {
  description = "Volume binding mode for the storage class"
  type        = string
  default     = "Immediate"
}

variable "allow_volume_expansion" {
  description = "Whether PVC expansion is allowed for the storage class"
  type        = bool
  default     = false
}

locals {
  optional_parameters = {
    compartmentOcid                                      = var.compartment_ocid
    kmsKeyOcid                                           = var.kms_key_ocid
    exportPath                                           = var.export_path
    exportOptions                                        = var.export_options_json
    "oci.oraclecloud.com/initial-defined-tags-override"  = var.defined_tags_override_json
    "oci.oraclecloud.com/initial-freeform-tags-override" = var.freeform_tags_override_json
  }

  parameters = merge(
    {
      availabilityDomain = var.availability_domain
      encryptInTransit   = tostring(var.encrypt_in_transit)
      mountTargetOcid    = var.mount_target_ocid
    },
    {
      for key, value in local.optional_parameters : key => value
      if value != null
    }
  )
}

resource "kubernetes_storage_class_v1" "filesystem_storage_class" {
  metadata {
    name = var.name
  }

  storage_provisioner    = "fss.csi.oraclecloud.com"
  parameters             = local.parameters
  reclaim_policy         = var.reclaim_policy
  volume_binding_mode    = var.volume_binding_mode
  allow_volume_expansion = var.allow_volume_expansion
}

output "name" {
  description = "Name of the created Kubernetes storage class"
  value       = kubernetes_storage_class_v1.filesystem_storage_class.metadata[0].name
}
