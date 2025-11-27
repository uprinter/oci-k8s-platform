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
