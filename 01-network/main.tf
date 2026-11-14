terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 7.25.0"
    }
    http = {
      source  = "hashicorp/http"
      version = ">= 3.4.0"
    }
  }
  required_version = ">= 1.5.0"
}

provider "oci" {
  auth                = "SecurityToken"
  config_file_profile = "DEFAULT"
  region              = var.region
}

# Cloudflare IPv4 ranges, the only sources allowed to reach the Load Balancer.
# Pinned so the plan stays deterministic; the check below warns on every plan
# when Cloudflare publishes a different list.
locals {
  cloudflare_ipv4_cidrs = toset([
    "173.245.48.0/20",
    "103.21.244.0/22",
    "103.22.200.0/22",
    "103.31.4.0/22",
    "141.101.64.0/18",
    "108.162.192.0/18",
    "190.93.240.0/20",
    "188.114.96.0/20",
    "197.234.240.0/22",
    "198.41.128.0/17",
    "162.158.0.0/15",
    "104.16.0.0/13",
    "104.24.0.0/14",
    "172.64.0.0/13",
    "131.0.72.0/22",
  ])
}

check "cloudflare_ipv4_ranges_current" {
  data "http" "cloudflare_ips" {
    url = "https://api.cloudflare.com/client/v4/ips"
  }

  assert {
    condition     = toset(jsondecode(data.http.cloudflare_ips.response_body).result.ipv4_cidrs) == local.cloudflare_ipv4_cidrs
    error_message = "Cloudflare publishes IPv4 ranges that differ from local.cloudflare_ipv4_cidrs. Update the list and apply, or Cloudflare traffic from the new ranges is blocked."
  }
}

module "network" {
  source                  = "../modules/network"
  compartment_id          = var.root_compartment_id
  dns_listener_address    = var.dns_listener_address
  lb_ingress_source_cidrs = local.cloudflare_ipv4_cidrs
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
