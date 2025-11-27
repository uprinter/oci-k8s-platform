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

module "nginx-gateway" {
  source            = "../modules/nginx-gateway"
  lb_sg_id          = var.lb_nsg_id
  issuer_name       = var.issuer_name
  issuer_kind       = var.issuer_kind
  internal_dns_zone = var.internal_hosted_zone_name
  external_dns_zone = var.external_hosted_zone_name
}
