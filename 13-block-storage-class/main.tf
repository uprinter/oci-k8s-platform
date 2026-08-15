terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.38.0"
    }
  }
  required_version = ">= 1.5.0"
}

provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = var.k8s_context
}

module "block_storage_class" {
  source = "../modules/block-storage-class"

  name                      = var.storage_class_name
  storage_provisioner       = var.storage_provisioner
  parameters                = var.storage_class_parameters
  reclaim_policy            = var.reclaim_policy
  volume_binding_mode       = var.volume_binding_mode
  allow_volume_expansion    = var.allow_volume_expansion
  is_default_class          = var.is_default_class
  demote_storage_class_name = var.demote_storage_class_name
  kubectl_context           = var.k8s_context
}

output "storage_class_name" {
  description = "Name of the block volume storage class"
  value       = module.block_storage_class.name
}
