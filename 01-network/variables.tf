variable "root_compartment_id" {
  description = "The OCID of the root compartment"
  type        = string
}

variable "region" {
  description = "The OCI region to deploy resources in"
  type        = string
}

variable "dns_listener_address" {
  description = "Private IPv4 address assigned to the VCN DNS listener"
  type        = string
}

variable "lb_ingress_source_cidrs" {
  description = "IPv4 CIDRs allowed to reach the shared Load Balancer on TCP 443. The default keeps it open to the internet; see README for a Cloudflare-only list"
  type        = set(string)
  default     = ["0.0.0.0/0"]
}
