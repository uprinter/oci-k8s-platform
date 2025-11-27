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

module "network" {
  source         = "../modules/network"
  compartment_id = var.root_compartment_id
}

output "vcn_id" {
  value       = module.network.vcn_id
  description = "VCN ID for use in other workspaces"
}

output "subnet_ids" {
  value       = module.network.subnet_ids
  description = "Map of subnet IDs (worker, api, lb, pod, vpn)"
}

output "nsg_ids" {
  value       = module.network.nsg_ids
  description = "Map of NSG IDs (api, worker, pod, lb, vpn)"
}
