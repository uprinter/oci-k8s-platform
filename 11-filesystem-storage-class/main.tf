terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.38.0"
    }
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

provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = var.k8s_context
}

data "oci_identity_availability_domains" "availability_domains" {
  compartment_id = var.root_compartment_id
}

locals {
  availability_domain = coalesce(
    var.availability_domain,
    data.oci_identity_availability_domains.availability_domains.availability_domains[0].name
  )

  compartment_ocid = coalesce(var.compartment_ocid, var.root_compartment_id)
}

resource "oci_file_storage_mount_target" "filesystem_storage_class" {
  availability_domain = local.availability_domain
  compartment_id      = local.compartment_ocid
  display_name        = var.mount_target_display_name
  subnet_id           = var.mount_target_subnet_ocid
}

module "filesystem_storage_class" {
  source = "../modules/filesystem-storage-class"

  name                        = var.storage_class_name
  availability_domain         = local.availability_domain
  mount_target_ocid           = oci_file_storage_mount_target.filesystem_storage_class.id
  compartment_ocid            = local.compartment_ocid
  kms_key_ocid                = var.kms_key_ocid
  export_path                 = var.export_path
  export_options_json         = var.export_options_json
  encrypt_in_transit          = var.encrypt_in_transit
  defined_tags_override_json  = var.defined_tags_override_json
  freeform_tags_override_json = var.freeform_tags_override_json
  reclaim_policy              = var.reclaim_policy
  volume_binding_mode         = var.volume_binding_mode
  allow_volume_expansion      = var.allow_volume_expansion
}

output "storage_class_name" {
  description = "Name of the OCI File Storage storage class"
  value       = module.filesystem_storage_class.name
}

output "availability_domain" {
  description = "Availability domain configured for the storage class"
  value       = local.availability_domain
}

output "mount_target_ocid" {
  description = "OCID of the statically provisioned OCI File Storage mount target"
  value       = oci_file_storage_mount_target.filesystem_storage_class.id
}
