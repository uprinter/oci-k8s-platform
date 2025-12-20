variable "compartment_id" { type = string }

variable "namespace" {
  type    = string
  default = "external-secrets"
}

variable "region" {
  type = string
}

variable "tenancy_ocid" {
  type = string
}

variable "user_ocid" {
  type = string
}

variable "private_key_pem" {
  type      = string
  sensitive = true
}

variable "fingerprint" {
  type = string
}

variable "oke_external_secrets_vault_ocid" {
  type = string
}

resource "kubernetes_namespace_v1" "external_secrets" {
  metadata {
    name = var.namespace
  }
}

resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  namespace        = var.namespace
  create_namespace = true
}

resource "kubernetes_secret_v1" "external_secrets_config" {
  metadata {
    name      = "external-secrets-config"
    namespace = var.namespace
  }

  type = "Opaque"

  data = {
    "privateKey"  = var.private_key_pem
    "fingerprint" = var.fingerprint
  }
}

resource "kubernetes_manifest" "oci_secret_store" {
  manifest = {
    apiVersion = "external-secrets.io/v1"
    kind       = "ClusterSecretStore"
    metadata = {
      name = "oci-secret-store"
    }
    spec = {
      provider = {
        oracle = {
          region        = var.region
          compartment   = var.compartment_id
          vault         = var.oke_external_secrets_vault_ocid
          principalType = "UserPrincipal"
          auth = {
            user    = var.user_ocid
            tenancy = var.tenancy_ocid
            secretRef = {
              privatekey = {
                name      = kubernetes_secret_v1.external_secrets_config.metadata[0].name
                key       = "privateKey"
                namespace = var.namespace
              }
              fingerprint = {
                name      = kubernetes_secret_v1.external_secrets_config.metadata[0].name
                key       = "fingerprint"
                namespace = var.namespace
              }
            }
          }
        }
      }
    }
  }
}
