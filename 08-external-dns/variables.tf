variable "root_compartment_id" {
  description = "The OCID of the root compartment"
  type        = string
}

variable "region" {
  description = "The OCI region to deploy resources in"
  type        = string
}

variable "k8s_context" {
  description = "Kubernetes context to use"
  type        = string
}

variable "external_dns_private_key" {
  description = "Private key for external DNS user"
  type        = string
  sensitive   = true
}

variable "external_dns_private_key_fingerprint" {
  description = "Fingerprint of the external DNS private key"
  type        = string
}

variable "external_dns_user_ocid" {
  description = "External DNS user OCID"
  type        = string
  sensitive   = true
}
