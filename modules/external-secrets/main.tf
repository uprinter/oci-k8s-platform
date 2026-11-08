variable "component_resources" {
  description = "Container requests and limits by component (keys: controller, cert-controller, webhook). Example: { requests = { cpu = \"10m\", memory = \"128Mi\" }, limits = { memory = \"512Mi\" } }. An empty map sets nothing."
  type = map(object({
    requests = optional(map(string), {})
    limits   = optional(map(string), {})
  }))
  default = {}
}

locals {
  resource_prefixes = {
    controller      = "resources"
    cert-controller = "certController.resources"
    webhook         = "webhook.resources"
  }
  resource_set = flatten([
    for comp, r in var.component_resources : concat(
      [for k, v in r.requests : { name = "${local.resource_prefixes[comp]}.requests.${k}", value = v }],
      [for k, v in r.limits : { name = "${local.resource_prefixes[comp]}.limits.${k}", value = v }]
    )
  ])
}

variable "pod_security_labels" {
  description = "Pod Security Admission labels for the namespace, for example pod-security.kubernetes.io/enforce = \"baseline\". Empty map sets no labels."
  type        = map(string)
  default     = {}
}

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
    name   = var.namespace
    labels = var.pod_security_labels
  }
}

variable "chart_version" {
  description = "External Secrets Operator Helm chart version (https://charts.external-secrets.io)."
  type        = string
  default     = "1.2.0"
}

resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  version          = var.chart_version
  namespace        = var.namespace
  create_namespace = true

  set = local.resource_set
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
