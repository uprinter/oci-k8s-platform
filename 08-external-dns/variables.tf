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

variable "oci_api_private_key" {
  description = "Private key for OCI API"
  type        = string
  sensitive   = true
}

variable "oci_api_private_key_fingerprint" {
  description = "Fingerprint of the private key for OCI API"
  type        = string
}

variable "external_dns_user_ocid" {
  description = "External DNS user OCID"
  type        = string
  sensitive   = true
}
