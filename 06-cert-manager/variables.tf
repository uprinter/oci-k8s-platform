variable "k8s_context" {
  description = "Kubernetes context to use"
  type        = string
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
    controller = { requests = { cpu = "10m", memory = "128Mi" }, limits = { memory = "512Mi" } }
    cainjector = { requests = { cpu = "10m", memory = "160Mi" }, limits = { memory = "512Mi" } }
    webhook    = { requests = { cpu = "5m", memory = "96Mi" }, limits = { memory = "512Mi" } }
  }
}
