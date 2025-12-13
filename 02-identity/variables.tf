variable "root_compartment_id" {
  description = "The OCID of the root compartment"
  type        = string
}

variable "region" {
  description = "The OCI region to deploy resources in"
  type        = string
}

variable "oci_api_public_key" {
  description = "Public key for OCI API"
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
