variable "name" {
  description = "Name of the Kubernetes storage class"
  type        = string
}

variable "parameters" {
  description = "Provisioner parameters for the storage class"
  type        = map(string)
  default     = {}
}

variable "storage_provisioner" {
  description = "CSI provisioner backing the storage class"
  type        = string
  default     = "blockvolume.csi.oraclecloud.com"
}

variable "reclaim_policy" {
  description = "Reclaim policy for the storage class"
  type        = string
  default     = "Delete"
}

variable "volume_binding_mode" {
  description = "Volume binding mode for the storage class"
  type        = string
  default     = "WaitForFirstConsumer"
}

variable "allow_volume_expansion" {
  description = "Whether PVC expansion is allowed for the storage class"
  type        = bool
  default     = true
}

variable "is_default_class" {
  description = "Whether this storage class is annotated as the cluster default"
  type        = bool
  default     = false
}

variable "demote_storage_class_name" {
  description = "Name of an existing, externally managed storage class whose default-class annotation should be set to false. Null disables the demotion."
  type        = string
  default     = null
}

variable "kubectl_context" {
  description = "kubectl context used by the destroy-time restore of the demoted class's default-class annotation. Required when demote_storage_class_name is set."
  type        = string
  default     = null
}

locals {
  default_class_annotation = "storageclass.kubernetes.io/is-default-class"
}

## Destroying kubernetes_annotations below removes the annotation key it manages
## rather than restoring the value it overwrote, which would leave the cluster
## with no default storage class at all. This resource is destroyed after it
## (the dependency is inverted on purpose) and puts the value back.
resource "terraform_data" "restored_default_storage_class" {
  count = var.demote_storage_class_name == null ? 0 : 1

  # Destroy-time provisioners may only reference self, so the values they need
  # have to be carried in state rather than read from variables.
  input = {
    annotation         = local.default_class_annotation
    kubectl_context    = var.kubectl_context
    storage_class_name = var.demote_storage_class_name
  }

  lifecycle {
    precondition {
      condition     = var.kubectl_context != null
      error_message = "kubectl_context must be set when demote_storage_class_name is set, otherwise the demotion cannot be undone on destroy."
    }
  }

  provisioner "local-exec" {
    when    = destroy
    command = "kubectl --context ${self.output.kubectl_context} annotate --overwrite storageclass ${self.output.storage_class_name} ${self.output.annotation}=true"
  }
}

resource "kubernetes_annotations" "demoted_default_storage_class" {
  count = var.demote_storage_class_name == null ? 0 : 1

  api_version = "storage.k8s.io/v1"
  kind        = "StorageClass"

  metadata {
    name = var.demote_storage_class_name
  }

  annotations = {
    (local.default_class_annotation) = "false"
  }

  # Takes ownership of this single annotation from the field manager that set it.
  force = true

  depends_on = [terraform_data.restored_default_storage_class]
}

# The API server rejects updates to a StorageClass's provisioner, parameters,
# reclaimPolicy and volumeBindingMode. The provider plans them as in-place
# updates, which fail at apply time, so changing one must force a replacement.
resource "terraform_data" "immutable_fields" {
  input = {
    parameters          = var.parameters
    reclaim_policy      = var.reclaim_policy
    storage_provisioner = var.storage_provisioner
    volume_binding_mode = var.volume_binding_mode
  }
}

resource "kubernetes_storage_class_v1" "block_storage_class" {
  metadata {
    name = var.name

    annotations = var.is_default_class ? {
      (local.default_class_annotation) = "true"
    } : {}
  }

  storage_provisioner    = var.storage_provisioner
  parameters             = var.parameters
  reclaim_policy         = var.reclaim_policy
  volume_binding_mode    = var.volume_binding_mode
  allow_volume_expansion = var.allow_volume_expansion

  # Demote first so the cluster never transiently has two default classes.
  depends_on = [kubernetes_annotations.demoted_default_storage_class]

  lifecycle {
    replace_triggered_by = [terraform_data.immutable_fields]
  }
}

output "name" {
  description = "Name of the created Kubernetes storage class"
  value       = kubernetes_storage_class_v1.block_storage_class.metadata[0].name
}
