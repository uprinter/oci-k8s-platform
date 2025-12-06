variable "root_compartment_id" {
  description = "The OCID of the root compartment"
  type        = string
}

variable "region" {
  description = "The OCI region to deploy resources in"
  type        = string
}

variable "internal_zone_name" {
  description = "Internal DNS zone name"
  type        = string
}     

variable "external_zone_name" {
  description = "External DNS zone name"
  type        = string
}

variable "public_zone_names" {
  description = "Public DNS zone names"
  type        = list(string)
  default     = []
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
