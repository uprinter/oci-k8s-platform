variable "namespace" {
  description = "Namespace where the origin-ca-issuer controller runs. Also the clusterResourceNamespace where ClusterOriginIssuer token secrets are resolved."
  type        = string
  default     = "origin-ca-issuer"
}

variable "chart_version" {
  description = "origin-ca-issuer Helm chart version (oci://ghcr.io/cloudflare/origin-ca-issuer-charts/origin-ca-issuer)."
  type        = string
  default     = "0.6.9"
}

variable "crd_version" {
  description = "cloudflare/origin-ca-issuer release tag used to fetch the CRD manifests. Keep in step with the chart appVersion."
  type        = string
  default     = "v0.14.4"
}

variable "request_type" {
  description = "Origin CA certificate key type: OriginRSA or OriginECC."
  type        = string
  default     = "OriginRSA"
}

variable "token_vault_secret_name" {
  description = "Name of the OCI Vault secret (consumed via the oci-secret-store ClusterSecretStore) holding the scoped Cloudflare Origin CA API token. No default on purpose — set in terraform.tfvars."
  type        = string
}

variable "cluster_secret_store_name" {
  description = "Name of the existing ExternalSecrets ClusterSecretStore backed by OCI Vault (from 09-external-secrets)."
  type        = string
  default     = "oci-secret-store"
}

variable "issuer_name" {
  description = "Name of the ClusterOriginIssuer resource."
  type        = string
  default     = "cloudflare-origin-issuer"
}

variable "certificate_namespace" {
  description = "Namespace of the nginx-gateway external Gateway. The origin certificate and its Secret must live here so the Gateway listener can reference it."
  type        = string
  default     = "nginx-gateway"
}

variable "certificate_name" {
  description = "Name of the Certificate resource AND its target Secret. MUST equal the secret name the nginx-gateway listener expects (replace(host, \".\", \"-\") + \"-cert\"). This exact-name alignment is what makes cert-manager's gateway-shim back off — see module notes. Required, no default: this repo is public and the value is domain-derived."
  type        = string
}

variable "certificate_dns_names" {
  description = "SANs for the Origin CA certificate (apex + wildcard is the usual choice, so one cert covers the apex and any subdomain). Required, no default: this repo is public, the domain is not committed."
  type        = list(string)
}

variable "certificate_duration" {
  description = "Origin CA certificate validity. Must be a Cloudflare-supported Origin CA validity period."
  type        = string
  default     = "8760h" # 1 year
}

variable "certificate_renew_before" {
  description = "How long before expiry cert-manager renews the origin certificate."
  type        = string
  default     = "720h" # 30 days
}

resource "kubernetes_namespace_v1" "origin_ca_issuer" {
  metadata {
    name = var.namespace
  }
}

# The Helm chart does NOT ship the CRDs; they must be installed separately.
# Fetch the pinned CRD manifests and apply them declaratively.
data "http" "origin_issuer_crd" {
  url = "https://raw.githubusercontent.com/cloudflare/origin-ca-issuer/${var.crd_version}/deploy/crds/cert-manager.k8s.cloudflare.com_originissuers.yaml"
}

data "http" "cluster_origin_issuer_crd" {
  url = "https://raw.githubusercontent.com/cloudflare/origin-ca-issuer/${var.crd_version}/deploy/crds/cert-manager.k8s.cloudflare.com_clusteroriginissuers.yaml"
}

resource "kubernetes_manifest" "origin_issuer_crd" {
  manifest = yamldecode(data.http.origin_issuer_crd.response_body)
}

resource "kubernetes_manifest" "cluster_origin_issuer_crd" {
  manifest = yamldecode(data.http.cluster_origin_issuer_crd.response_body)
}

resource "helm_release" "origin_ca_issuer" {
  name             = "origin-ca-issuer"
  repository       = "oci://ghcr.io/cloudflare/origin-ca-issuer-charts"
  chart            = "origin-ca-issuer"
  version          = var.chart_version
  namespace        = kubernetes_namespace_v1.origin_ca_issuer.metadata[0].name
  create_namespace = false

  # Resolve ClusterOriginIssuer token secrets from this controller's namespace.
  set = [
    {
      name  = "controller.clusterResourceNamespace"
      value = var.namespace
    }
  ]

  depends_on = [
    kubernetes_manifest.origin_issuer_crd,
    kubernetes_manifest.cluster_origin_issuer_crd,
  ]
}

# Surface the scoped Cloudflare Origin CA token from OCI Vault into a k8s Secret
# the ClusterOriginIssuer can read (resolved from var.namespace / clusterResourceNamespace).
resource "kubernetes_manifest" "origin_ca_token" {
  manifest = {
    apiVersion = "external-secrets.io/v1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "cloudflare-origin-ca-token"
      namespace = var.namespace
    }
    spec = {
      refreshInterval = "1h"
      secretStoreRef = {
        name = var.cluster_secret_store_name
        kind = "ClusterSecretStore"
      }
      target = {
        name           = "cloudflare-origin-ca-token"
        creationPolicy = "Owner"
      }
      data = [
        {
          secretKey = "key"
          remoteRef = {
            key = var.token_vault_secret_name
          }
        }
      ]
    }
  }

  depends_on = [kubernetes_namespace_v1.origin_ca_issuer]
}

resource "kubernetes_manifest" "cluster_origin_issuer" {
  manifest = {
    apiVersion = "cert-manager.k8s.cloudflare.com/v1"
    kind       = "ClusterOriginIssuer"
    metadata = {
      name = var.issuer_name
    }
    spec = {
      requestType = var.request_type
      auth = {
        tokenRef = {
          name = "cloudflare-origin-ca-token"
          key  = "key"
        }
      }
    }
  }

  depends_on = [
    kubernetes_manifest.cluster_origin_issuer_crd,
    helm_release.origin_ca_issuer,
    kubernetes_manifest.origin_ca_token,
  ]
}

# Origin certificate for the shared LB edge.
#
# IMPORTANT — name alignment is load-bearing:
# The nginx-gateway external Gateway carries a cluster-wide
# cert-manager.io/cluster-issuer=letsencrypt-issuer annotation. cert-manager's
# gateway-shim (pkg/controller/certificate-shim/sync.go) builds one Certificate
# per TLS listener whose resource NAME equals the listener's secretName, and it
# looks up an existing Certificate via Get(secretName). Because THIS Certificate
# is named exactly var.certificate_name (== the secretName the listener expects)
# and has no controller ownerReference, the shim finds it, sees it is not owned,
# logs "refusing to update non-owned certificate resource", and backs off — it
# does NOT create a competing letsencrypt/HTTP-01 Certificate for the same
# secret. Renaming this resource away from the secretName would break that
# back-off and cause a duplicate HTTP-01 cert to fight over the Secret.
resource "kubernetes_manifest" "origin_certificate" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = var.certificate_name
      namespace = var.certificate_namespace
    }
    spec = {
      secretName  = var.certificate_name
      dnsNames    = var.certificate_dns_names
      duration    = var.certificate_duration
      renewBefore = var.certificate_renew_before
      issuerRef = {
        group = "cert-manager.k8s.cloudflare.com"
        kind  = "ClusterOriginIssuer"
        name  = var.issuer_name
      }
    }
  }

  depends_on = [kubernetes_manifest.cluster_origin_issuer]
}

output "issuer_name" {
  value = var.issuer_name
}

output "certificate_secret_name" {
  value = var.certificate_name
}
