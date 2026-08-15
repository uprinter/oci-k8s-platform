variable "k8s_context" {
  description = "Kubernetes context to use"
  type        = string
}

variable "storage_class_name" {
  description = "Name of the Kubernetes storage class created by this stack"
  type        = string
  default     = "oci-bv-retain"
}

variable "storage_provisioner" {
  description = "CSI provisioner backing the storage class"
  type        = string
  default     = "blockvolume.csi.oraclecloud.com"
}

variable "storage_class_parameters" {
  description = "Provisioner parameters for the storage class"
  type        = map(string)
  default     = {}
}

variable "reclaim_policy" {
  description = "Storage class reclaim policy"
  type        = string
  default     = "Retain"
}

variable "volume_binding_mode" {
  description = "Storage class volume binding mode"
  type        = string
  default     = "WaitForFirstConsumer"
}

variable "allow_volume_expansion" {
  description = "Whether PVC expansion is allowed"
  type        = bool
  default     = true
}

variable "is_default_class" {
  description = "Whether this storage class is annotated as the cluster default"
  type        = bool
  default     = true
}

variable "demote_storage_class_name" {
  description = "Name of an existing, externally managed storage class whose default-class annotation should be set to false. Null disables the demotion."
  type        = string
  default     = null
}
