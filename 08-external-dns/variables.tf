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
    controller = { requests = { cpu = "5m", memory = "128Mi" }, limits = { memory = "512Mi" } }
  }
}
