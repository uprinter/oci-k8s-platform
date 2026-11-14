variable "root_compartment_id" {
  description = "The OCID of the root compartment"
  type        = string
}

variable "region" {
  description = "The OCI region to deploy resources in"
  type        = string
}

variable "ci_terraform_public_key" {
  description = "PEM public key registered as the CI technical user's API key"
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

variable "external_dns_next_public_key" {
  description = "PEM public key for the API key of the external-dns user. Null creates no key."
  type        = string
  default     = null
}

variable "external_secrets_next_public_key" {
  description = "PEM public key for the API key of the external-secrets user. Null creates no key."
  type        = string
  default     = null
}
