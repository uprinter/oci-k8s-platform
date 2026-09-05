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
  source               = "../modules/network"
  compartment_id       = var.root_compartment_id
  dns_listener_address = var.dns_listener_address
}

output "vcn_id" {
  value       = module.network.vcn_id
  description = "VCN ID for use in other workspaces"
}

output "subnet_ids" {
  value       = module.network.subnet_ids
  description = "Map of subnet IDs (worker, api, lb, pod, vpn, fss_mount_target)"
}

output "nsg_ids" {
  value       = module.network.nsg_ids
  description = "Map of NSG IDs (api, worker, pod, lb, vpn)"
}

output "dns_listener_address" {
  value       = module.network.dns_listener_address
  description = "Private IPv4 address of the VCN DNS listener"
}
