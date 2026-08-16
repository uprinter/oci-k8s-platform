terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = ">= 3.1.0"
    }
  }
  required_version = ">= 1.5.0"
}

provider "helm" {
  kubernetes = {
    config_path    = "~/.kube/config"
    config_context = var.k8s_context
  }
}

module "metrics_server" {
  source = "../modules/metrics-server"

  namespace                  = var.namespace
  chart_version              = var.chart_version
  replicas                   = var.replicas
  kubelet_insecure_tls       = var.kubelet_insecure_tls
  cpu_request                = var.cpu_request
  memory_request             = var.memory_request
  memory_limit               = var.memory_limit
  preemptible_toleration_key = var.preemptible_toleration_key
}

output "namespace" {
  description = "Namespace the metrics-server release is installed into"
  value       = module.metrics_server.namespace
}

output "chart_version" {
  description = "Installed metrics-server chart version"
  value       = module.metrics_server.chart_version
}
