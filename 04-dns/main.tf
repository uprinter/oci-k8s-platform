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

module "dns" {
  source                      = "../modules/dns"
  vcn_id                      = var.vcn_id
  compartment_id              = var.root_compartment_id
  internal_dns_zone           = var.internal_zone_name
  external_dns_zone           = var.external_zone_name
  public_dns_zones            = var.public_zone_names
}
