variable "k8s_context" {
  description = "Kubernetes context to use"
  type        = string
}

variable "namespace" {
  description = "Namespace for the metrics-server release"
  type        = string
  default     = "kube-system"
}

variable "chart_version" {
  description = "metrics-server Helm chart version"
  type        = string
  default     = "3.13.1"
}

variable "replicas" {
  description = "Number of metrics-server replicas"
  type        = number
  default     = 1
}

variable "kubelet_insecure_tls" {
  description = "Skip verification of the kubelet serving certificate (required on OKE)"
  type        = bool
  default     = true
}

variable "cpu_request" {
  description = "CPU request for the metrics-server container"
  type        = string
  default     = "50m"
}

variable "memory_request" {
  description = "Memory request for the metrics-server container"
  type        = string
  default     = "100Mi"
}

variable "memory_limit" {
  description = "Memory limit for the metrics-server container"
  type        = string
  default     = "200Mi"
}
