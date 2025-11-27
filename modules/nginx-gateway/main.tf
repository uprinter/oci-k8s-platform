variable "namespace" {
  description = "The namespace where resources will be created"
  type        = string
  default     = "nginx-gateway"
}

variable "issuer_name" {
  description = "The name of the issuer to be used for certificates"
  type        = string
}

variable "issuer_kind" {
  description = "The kind of the issuer (e.g., ClusterIssuer or Issuer)"
  type        = string
}

variable "internal_dns_zone" {
  description = "The internal DNS zone for the internal gateway"
  type        = string
}

variable "external_dns_zone" {
  description = "The external DNS zone for the external gateway"
  type        = string
}

variable "lb_sg_id" {
  description = "The OCID of the network security group for the load balancer"
  type        = string
}

resource "helm_release" "nginx_fabric_gateway" {
  name             = "ngf"
  repository       = "oci://ghcr.io/nginx/charts/"
  chart            = "nginx-gateway-fabric"
  namespace        = var.namespace
  create_namespace = true
}

# External Gateway (via Load Balancer)
resource "kubernetes_manifest" "nginx_fabric_gateway_external" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "Gateway"
    metadata = {
      name      = "nginx-fabric-gateway-external"
      namespace = helm_release.nginx_fabric_gateway.metadata.namespace
    }
    spec = {
      gatewayClassName = "nginx"
      infrastructure = {
        annotations = {
          "external-dns.alpha.kubernetes.io/hostname"                   = "*.${var.external_dns_zone}"
          "service.beta.kubernetes.io/oci-load-balancer-shape"          = "flexible"
          "service.beta.kubernetes.io/oci-load-balancer-shape-flex-min" = "10"
          "service.beta.kubernetes.io/oci-load-balancer-shape-flex-max" = "50"
          "oci.oraclecloud.com/oci-network-security-groups"             = var.lb_sg_id
        }
      }
      listeners = [
        {
          name     = "https"
          port     = 443
          protocol = "HTTPS"
          allowedRoutes = {
            namespaces = {
              from = "All"
            }
          }
          tls = {
            mode = "Terminate"
            certificateRefs = [
              {
                kind = "Secret"
                name = kubernetes_manifest.external_certificate.manifest.metadata.name
              }
            ]
          }
        }
      ]
    }
  }
}

resource "kubernetes_manifest" "nginx_proxy_for_internal_gateway" {
  manifest = {
    apiVersion = "gateway.nginx.org/v1alpha2"
    kind       = "NginxProxy"
    metadata = {
      name      = "nginx-proxy-for-internal-gateway"
      namespace = helm_release.nginx_fabric_gateway.metadata.namespace
    }
    spec = {
      kubernetes = {
        service = {
          type = "NodePort"
          nodePorts = [{
            port         = 30000,
            listenerPort = 443
          }]
        }
      }
    }
  }
}

# Internal Gateway (via NodePort)
resource "kubernetes_manifest" "nginx_fabric_gateway_internal" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "Gateway"
    metadata = {
      name      = "nginx-fabric-gateway-internal"
      namespace = helm_release.nginx_fabric_gateway.metadata.namespace
    }
    spec = {
      gatewayClassName = "nginx"
      infrastructure = {
        annotations = {
          "external-dns.alpha.kubernetes.io/hostname" = "*.${var.internal_dns_zone}"
          "external-dns.alpha.kubernetes.io/access"   = "private"
        }
        parametersRef = {
          kind  = "NginxProxy"
          group = "gateway.nginx.org"
          name  = "nginx-proxy-for-internal-gateway"
        }
      }
      listeners = [
        {
          name     = "https"
          port     = 443
          protocol = "HTTPS"
          allowedRoutes = {
            namespaces = {
              from = "All"
            }
          }
          tls = {
            mode = "Terminate"
            certificateRefs = [
              {
                kind = "Secret"
                name = kubernetes_manifest.internal_certificate.manifest.metadata.name
              }
            ]
          }
        }
      ]
    }
  }
}

# Internal Certificate
resource "kubernetes_manifest" "internal_certificate" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "internal-cert"
      namespace = helm_release.nginx_fabric_gateway.metadata.namespace
    }
    spec = {
      secretName = "internal-cert"
      dnsNames   = ["*.${var.internal_dns_zone}"]
      issuerRef = {
        name = var.issuer_name
        kind = var.issuer_kind
      }
    }
  }
}

# External Certificate
resource "kubernetes_manifest" "external_certificate" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "external-cert"
      namespace = helm_release.nginx_fabric_gateway.metadata.namespace
    }
    spec = {
      secretName = "external-cert"
      dnsNames   = ["*.${var.external_dns_zone}"]
      issuerRef = {
        name = var.issuer_name
        kind = var.issuer_kind
      }
    }
  }
}

# Nginx Gateway Fabric Server Certificate
resource "kubernetes_manifest" "server_cert" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "server-cert"
      namespace = helm_release.nginx_fabric_gateway.metadata.namespace
    }
    spec = {
      secretName = "server-tls"
      usages = [
        "digital signature",
        "key encipherment"
      ]
      dnsNames = [
        "ngf-nginx-gateway-fabric.nginx-gateway.svc"
      ]
      issuerRef = {
        name = var.issuer_name
        kind = var.issuer_kind
      }
    }
  }
}

# Nginx Gateway Fabric Agent Certificate
resource "kubernetes_manifest" "agent_cert" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "agent-cert"
      namespace = helm_release.nginx_fabric_gateway.metadata.namespace
    }
    spec = {
      secretName = "agent-tls"
      usages = [
        "digital signature",
        "key encipherment"
      ]
      dnsNames = [
        "*.cluster.local"
      ]
      issuerRef = {
        name = var.issuer_name
        kind = var.issuer_kind
      }
    }
  }
}
