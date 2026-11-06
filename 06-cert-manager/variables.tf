variable "k8s_context" {
  description = "Kubernetes context to use"
  type        = string
}

variable "pod_security_labels" {
  description = "Pod Security Admission labels for the namespace. Empty map sets no labels."
  type        = map(string)
  default     = {}
}
