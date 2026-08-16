variable "namespace" {
  description = "Namespace for the metrics-server release."
  type        = string
  default     = "kube-system"
}

variable "chart_version" {
  description = "metrics-server Helm chart version (https://kubernetes-sigs.github.io/metrics-server/)."
  type        = string
  default     = "3.13.1"
}

variable "replicas" {
  description = "Number of metrics-server replicas. Keep at 1 on a single-node cluster; the pod anti-affinity in the chart cannot be satisfied by more."
  type        = number
  default     = 1
}

variable "kubelet_insecure_tls" {
  description = "Skip verification of the kubelet serving certificate. Required on OKE, whose kubelets serve a node-local self-signed cert that is not issued by the cluster CA."
  type        = bool
  default     = true
}

variable "cpu_request" {
  description = "CPU request for the metrics-server container."
  type        = string
  default     = "50m"
}

variable "memory_request" {
  description = "Memory request for the metrics-server container."
  type        = string
  default     = "100Mi"
}

variable "memory_limit" {
  description = "Memory limit for the metrics-server container."
  type        = string
  default     = "200Mi"
}

resource "helm_release" "metrics_server" {
  name             = "metrics-server"
  repository       = "https://kubernetes-sigs.github.io/metrics-server/"
  chart            = "metrics-server"
  version          = var.chart_version
  namespace        = var.namespace
  create_namespace = false

  values = [yamlencode({
    replicas = var.replicas

    # Appended to the chart's defaultArgs, which already prefer InternalIP.
    args = var.kubelet_insecure_tls ? ["--kubelet-insecure-tls"] : []

    resources = {
      requests = {
        cpu    = var.cpu_request
        memory = var.memory_request
      }
      limits = {
        # No CPU limit on purpose: CFS throttling would stall the scrape loop
        # and produce gaps in the metrics the HPA/kubectl top read.
        memory = var.memory_limit
      }
    }
  })]
}

output "namespace" {
  description = "Namespace the metrics-server release is installed into"
  value       = helm_release.metrics_server.metadata.namespace
}

output "chart_version" {
  description = "Installed metrics-server chart version"
  value       = helm_release.metrics_server.metadata.version
}
