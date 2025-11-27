variable "namespace" {
  description = "The namespace where external-dns will be installed"
  type        = string
  default     = "external-dns"
}

variable "region" {
  description = "OCI region"
  type        = string
}

variable "tenancy_ocid" {
  description = "OCI tenancy OCID"
  type        = string
}

variable "user_ocid" {
  description = "External DNS user OCID"
  type        = string
}

variable "private_key_pem" {
  description = "Private key in PEM format"
  type        = string
  sensitive   = true
}

variable "fingerprint" {
  description = "API key fingerprint"
  type        = string
}

locals {
  oci_config_content = yamlencode({
    auth = {
      region      = var.region
      tenancy     = var.tenancy_ocid
      user        = var.user_ocid
      key         = var.private_key_pem
      fingerprint = var.fingerprint
    },
    compartment = var.tenancy_ocid
  })
}

resource "kubernetes_namespace" "external_dns" {
  metadata {
    name = var.namespace
  }
}

resource "kubernetes_secret" "external_dns_config" {
  metadata {
    name      = "external-dns-config"
    namespace = kubernetes_namespace.external_dns.metadata[0].name
  }

  data = {
    "oci.yaml" = local.oci_config_content
  }
}

resource "helm_release" "external_dns" {
  name       = "external-dns"
  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"
  namespace  = kubernetes_namespace.external_dns.metadata[0].name

  set = [
    {
      name  = "provider.name"
      value = "oci"
    },
    {
      name  = "extraArgs[0]"
      value = "--oci-zone-scope="
    },
    {
      name  = "extraArgs[1]"
      value = "--oci-config-file=/etc/kubernetes/oci.yaml"
    },
    {
      name  = "extraArgs[2]"
      value = "--oci-zones-cache-duration=5m"
    },
    {
      name  = "extraVolumes[0].name"
      value = "config"
    },
    {
      name  = "extraVolumes[0].secret.secretName"
      value = kubernetes_secret.external_dns_config.metadata[0].name
    },
    {
      name  = "extraVolumeMounts[0].name"
      value = "config"
    },
    {
      name  = "extraVolumeMounts[0].mountPath"
      value = "/etc/kubernetes"
    }
  ]

  depends_on = [kubernetes_secret.external_dns_config]
}
