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
    http = {
      source  = "hashicorp/http"
      version = ">= 3.4.0"
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

module "origin-ca-issuer" {
  source = "../modules/origin-ca-issuer"

  token_vault_secret_name = var.origin_ca_token_vault_secret_name
  request_type            = var.origin_ca_request_type
  certificate_namespace   = var.nginx_gateway_namespace
  certificate_name        = var.origin_certificate_secret_name
  certificate_dns_names   = var.origin_certificate_dns_names
}
