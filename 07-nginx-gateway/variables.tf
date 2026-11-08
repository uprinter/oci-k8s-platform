variable "k8s_context" {
  description = "Kubernetes context to use"
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

variable "public_hosted_zone_records" {
  description = "Public DNS zone records"
  type        = list(string)
  default     = []
}

variable "lb_nsg_id" {
  description = "Load balancer NSG ID"
  type        = string
}

variable "issuer_name" {
  description = "Certificate issuer name"
  type        = string
}

variable "issuer_kind" {
  description = "Certificate issuer kind"
  type        = string
}

variable "acme_registration_email" {
  description = "Email address used for ACME registration"
  type        = string
}

variable "disable_lb_security_rule_management" {
  description = "Stop the cloud controller manager from writing Load Balancer security rules. Set it to true when 01-network restricts lb_ingress_source_cidrs"
  type        = bool
  default     = false
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
    controller = { requests = { cpu = "10m", memory = "200Mi" }, limits = { memory = "512Mi" } }
    proxy      = { requests = { cpu = "10m", memory = "128Mi" }, limits = { memory = "256Mi" } }
  }
}
