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

module "identity" {
  source                      = "../modules/identity"
  compartment_id              = var.root_compartment_id
  region                      = var.region
  oci_api_public_key          = var.oci_api_public_key
  technical_users_domain_url  = var.technical_users_domain_url
  technical_users_domain_name = var.technical_users_domain_name
}

output "technical_users_domain_url" {
  value       = module.identity.technical_users_domain_url
  description = "Technical users domain URL"
}

output "technical_users_domain_name" {
  value       = module.identity.technical_users_domain_name
  description = "Technical users domain name"
}

output "external_dns_user_ocid" {
  value       = module.identity.external_dns_user_ocid
  description = "OCID of the external DNS user"
}

output "external_secrets_user_ocid" {
  value       = module.identity.external_secrets_user_ocid
  description = "OCID of the external secrets user"
}
