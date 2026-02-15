variable "compartment_id" { type = string }
variable "cluster_name" { type = string }
variable "vcn_id" { type = string }
variable "kubernetes_version" { type = string }
variable "is_basic_cluster" { type = bool }
variable "node_pool_name" { type = string }
variable "node_shape" { type = string }
variable "node_ocpus" { type = number }
variable "node_memory_in_gbs" { type = number }
variable "node_count" { type = number }
variable "node_image_id" { type = string }
variable "node_pool_subnet_id" { type = string }
variable "endpoint_subnet_id" { type = string }
variable "pod_subnet_ids" { type = list(string) }
variable "service_lb_subnet_ids" { type = list(string) }
variable "availability_domain" { type = string }
variable "cni_type" { type = string }
variable "api_sg_id" { type = string }
variable "worker_sg_id" { type = string }
variable "pod_sg_id" { type = string }

resource "oci_containerengine_cluster" "oke_cluster" {
  compartment_id     = var.compartment_id
  name               = var.cluster_name
  kubernetes_version = var.kubernetes_version

  vcn_id = var.vcn_id
  type   = var.is_basic_cluster ? "BASIC_CLUSTER" : "ENHANCED_CLUSTER"

  options {
    service_lb_subnet_ids = var.service_lb_subnet_ids
  }

  endpoint_config {
    subnet_id = var.endpoint_subnet_id
    nsg_ids   = [var.api_sg_id]
  }

  cluster_pod_network_options {
    cni_type = var.cni_type
  }
}

resource "oci_containerengine_node_pool" "node_pool" {
  compartment_id     = var.compartment_id
  cluster_id         = oci_containerengine_cluster.oke_cluster.id
  name               = var.node_pool_name
  kubernetes_version = var.kubernetes_version

  node_shape = var.node_shape

  node_shape_config {
    ocpus         = var.node_ocpus
    memory_in_gbs = var.node_memory_in_gbs
  }

  node_config_details {
    size    = var.node_count
    nsg_ids = [var.worker_sg_id]

    placement_configs {
      subnet_id           = var.node_pool_subnet_id
      availability_domain = var.availability_domain
    }

    node_pool_pod_network_option_details {
      cni_type          = var.cni_type
      pod_subnet_ids    = var.pod_subnet_ids
      pod_nsg_ids       = [var.pod_sg_id]
      max_pods_per_node = 62
    }
  }

  node_source_details {
    image_id    = var.node_image_id
    source_type = "IMAGE"
  }
}

resource "oci_kms_vault" "oke_secrets_vault" {
  compartment_id = var.compartment_id
  display_name   = "oke-secrets-vault"
  vault_type     = "DEFAULT"
}

resource "oci_kms_key" "default_oke_secrets_vault_encryption_key" {
  compartment_id      = var.compartment_id
  display_name        = "default-oke-secrets-vault-encryption-key"
  management_endpoint = oci_kms_vault.oke_secrets_vault.management_endpoint
  protection_mode     = "SOFTWARE"

  key_shape {
    algorithm = "AES"
    length    = 16
  }
}

output "oke_external_secrets_vault_ocid" {
  value = oci_kms_vault.oke_secrets_vault.id
}
