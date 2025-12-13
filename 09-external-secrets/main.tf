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

module "external-secrets" {
  source                          = "../modules/external-secrets"
  compartment_id                  = var.root_compartment_id
  region                          = var.region
  tenancy_ocid                    = var.root_compartment_id
  user_ocid                       = var.user_ocid
  private_key_pem                 = var.oci_api_private_key
  fingerprint                     = var.oci_api_private_key_fingerprint
  oke_external_secrets_vault_ocid = var.oke_external_secrets_vault_ocid
}
