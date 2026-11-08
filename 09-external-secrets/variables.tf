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

variable "oke_external_secrets_vault_ocid" {
  description = "OCID of the vault to store external secrets"
  type        = string
}

variable "user_ocid" {
  type        = string
  description = "OCID of the user that will be used to deploy resources"
}

variable "pod_security_labels" {
  description = "Pod Security Admission labels for the namespace. Empty map sets no labels."
  type        = map(string)
  default     = {}
}

variable "component_resources" {
  description = "Container requests and limits by component. Memory requests are about 2 times the measured use (CPU requests at least 5m). Memory limits are 512Mi, except the nginx proxy (about 3 times its measured peak). No CPU limit is set."
  type = map(object({
    requests = optional(map(string), {})
    limits   = optional(map(string), {})
  }))
  default = {
    controller      = { requests = { cpu = "10m", memory = "128Mi" }, limits = { memory = "512Mi" } }
    cert-controller = { requests = { cpu = "5m", memory = "224Mi" }, limits = { memory = "512Mi" } }
    webhook         = { requests = { cpu = "5m", memory = "80Mi" }, limits = { memory = "512Mi" } }
  }
}
