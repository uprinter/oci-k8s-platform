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
  source         = "../modules/identity"
  compartment_id = var.root_compartment_id
  region         = var.region
}

output "technical_users_domain_url" {
  value       = module.identity.technical_users_domain_url
  description = "Technical users domain URL"
}

output "technical_users_domain_name" {
  value       = module.identity.technical_users_domain_name
  description = "Technical users domain name"
}
