resource "kubernetes_namespace" "cert_manager" {
  metadata {
    name = "cert-manager"
  }
}

resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  namespace        = kubernetes_namespace.cert_manager.metadata[0].name
  create_namespace = false

  set = [
    {
      name  = "config.apiVersion"
      value = "controller.config.cert-manager.io/v1alpha1"
    },
    {
      name  = "config.kind"
      value = "ControllerConfiguration"
    },
    {
      name  = "config.enableGatewayAPI"
      value = "true"
    },
    {
      name  = "crds.enabled"
      value = "true"
    }
  ]
}

# Root Self-signed Issuer
resource "kubernetes_manifest" "selfsigned_root_issuer" {
  depends_on = [helm_release.cert_manager]

  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "selfsigned-root-issuer"
    }
    spec = {
      selfSigned = {}
    }
  }
}

# Root CA Certificate (self-signed)
resource "kubernetes_manifest" "root_ca_cert" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "root-ca-cert"
      namespace = kubernetes_namespace.cert_manager.metadata[0].name
    }
    spec = {
      isCA       = true
      commonName = "Root CA"
      secretName = "root-ca-cert"
      privateKey = {
        algorithm = "RSA"
        size      = 2048
      }
      issuerRef = {
        name = kubernetes_manifest.selfsigned_root_issuer.manifest.metadata.name
        kind = "ClusterIssuer"
      }
    }
  }
}

# Intermediate CA Issuer
resource "kubernetes_manifest" "intermediate_ca_issuer" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "intermediate-ca-issuer"
    }
    spec = {
      ca = {
        secretName = kubernetes_manifest.root_ca_cert.manifest.spec.secretName
      }
    }
  }
}

# Intermediate CA Certificate
resource "kubernetes_manifest" "intermediate_ca_cert" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "intermediate-ca-cert"
      namespace = kubernetes_namespace.cert_manager.metadata[0].name
    }
    spec = {
      isCA       = true
      commonName = "Intermediate CA"
      secretName = "intermediate-ca-cert"
      privateKey = {
        algorithm = "RSA"
        size      = 2048
      }
      issuerRef = {
        name = kubernetes_manifest.intermediate_ca_issuer.manifest.metadata.name
        kind = "ClusterIssuer"
      }
    }
  }
}

# Leaf CA Issuer
resource "kubernetes_manifest" "leaf_ca_issuer" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "leaf-ca-issuer"
    }
    spec = {
      ca = {
        secretName = kubernetes_manifest.intermediate_ca_cert.manifest.spec.secretName
      }
    }
  }
}

output "issuer_name" {
  value = kubernetes_manifest.leaf_ca_issuer.manifest.metadata.name
}

output "issuer_kind" {
  value = kubernetes_manifest.leaf_ca_issuer.manifest.kind
}