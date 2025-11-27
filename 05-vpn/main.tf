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

module "vpn" {
  source              = "../modules/vpn"
  ssh_public_key      = var.ssh_public_key
  vpn_image_id        = var.vpn_image_id
  vpn_instance_shape  = var.vpn_instance_shape
  vpn_instance_name   = var.vpn_instance_name
  compartment_id      = var.root_compartment_id
  availability_domain = data.oci_identity_availability_domains.availability_domains.availability_domains[0].name
  vpn_subnet_id       = var.vpn_subnet_id
  vpn_sg_id           = var.vpn_nsg_id
}
