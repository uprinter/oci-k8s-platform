terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.38.0"
    }
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

provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = var.k8s_context
}

module "cert-manager" {
  source = "../modules/cert-manager"
}

output "issuer_name" {
  value       = module.cert-manager.issuer_name
  description = "Certificate issuer name"
}

output "issuer_kind" {
  value       = module.cert-manager.issuer_kind
  description = "Certificate issuer kind"
}
