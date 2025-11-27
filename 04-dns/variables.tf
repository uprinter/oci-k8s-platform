variable "root_compartment_id" {
  description = "The OCID of the root compartment"
  type        = string
}

variable "region" {
  description = "The OCI region to deploy resources in"
  type        = string
}

variable "internal_hosted_zone_name" {
  description = "Internal DNS zone name"
  type        = string
}

variable "external_hosted_zone_name" {
  description = "External DNS zone name"
  type        = string
}

variable "scope" {
  description = "DNS zone scope (PRIVATE or GLOBAL)"
  type        = string
  default     = "PRIVATE"
}

variable "external_dns_public_key" {
  description = "Public key for external DNS user"
  type        = string
}

variable "vcn_id" {
  description = "VCN ID"
  type        = string
}

variable "technical_users_domain_url" {
  description = "Technical users domain URL"
  type        = string
}

variable "technical_users_domain_name" {
  description = "Technical users domain name"
  type        = string
}
