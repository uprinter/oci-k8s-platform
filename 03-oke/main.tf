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

data "oci_identity_availability_domains" "availability_domains" {
  compartment_id = var.root_compartment_id
}

module "oke" {
  source                             = "../modules/oke"
  cluster_name                       = var.cluster_name
  compartment_id                     = var.root_compartment_id
  kubernetes_version                 = var.kubernetes_version
  cni_type                           = var.cni_type
  vcn_id                             = var.vcn_id
  node_pool_subnet_id                = var.worker_subnet_id
  endpoint_subnet_id                 = var.api_subnet_id
  service_lb_subnet_ids              = [var.lb_subnet_id]
  pod_subnet_ids                     = [var.pod_subnet_id]
  api_sg_id                          = var.api_nsg_id
  worker_sg_id                       = var.worker_nsg_id
  pod_sg_id                          = var.pod_nsg_id
  is_basic_cluster                   = var.is_basic_cluster
  node_pool_name                     = var.node_pool_name
  node_shape                         = var.node_shape
  node_ocpus                         = var.node_ocpus
  node_memory_in_gbs                 = var.node_memory_in_gbs
  node_count                         = var.node_count
  node_image_id                      = var.node_image_id
  availability_domain                = data.oci_identity_availability_domains.availability_domains.availability_domains[0].name
  use_preemptible_nodes              = var.use_preemptible_nodes
  preserve_boot_volume_on_preemption = var.preserve_boot_volume_on_preemption
  capacity_reservation_id            = var.capacity_reservation_id
}

output "oke_external_secrets_vault_ocid" {
  value       = module.oke.oke_external_secrets_vault_ocid
  description = "OCID of the OCI KMS Vault for external secrets"
}
