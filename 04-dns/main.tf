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
  internal_dns_zone           = var.internal_hosted_zone_name
  external_dns_zone           = var.external_hosted_zone_name
  scope                       = var.scope
  external_dns_public_key     = var.external_dns_public_key
  technical_users_domain_url  = var.technical_users_domain_url
  technical_users_domain_name = var.technical_users_domain_name
}

output "external_dns_user_ocid" {
  value       = module.dns.external_dns_user_ocid
  description = "OCID of the external DNS user"
  sensitive   = true
}
