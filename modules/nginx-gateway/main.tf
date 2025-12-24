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

variable "public_dns_zone_records" {
  description = "The public DNS zone records for the external gateway"
  type        = list(string)
}

variable "acme_registration_email" {
  description = "The email address for ACME registration"
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

locals {
  all_dns_zones = concat([var.external_dns_zone], var.public_dns_zone_records)
  
  https_listeners = [
    for idx, zone in local.all_dns_zones : {
      name     = "https-${idx + 1}"
      port     = 443
      protocol = "HTTPS"
      hostname = idx == 0 ? "*.${zone}" : zone
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
            name = idx == 0 ? kubernetes_manifest.external_certificate.manifest.metadata.name : "${replace(zone, ".", "-")}-cert"
          }
        ]
      }
    }
  ]
  
  http_listeners = [
    for idx, zone in var.public_dns_zone_records : {
      name     = "http-${idx + 1}"
      port     = 80
      protocol = "HTTP"
      hostname = zone
      allowedRoutes = {
        namespaces = {
          from = "All"
        }
      }
    }
  ]
}

# External Gateway (via Load Balancer)
resource "kubernetes_manifest" "nginx_fabric_gateway_external" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "Gateway"
    metadata = {
      name      = "nginx-fabric-gateway-external"
      namespace = helm_release.nginx_fabric_gateway.metadata.namespace
      annotations = {
        "cert-manager.io/cluster-issuer" = "letsencrypt-issuer"
      }
    }
    spec = {
      gatewayClassName = "nginx"
      infrastructure = {
        annotations = {
          "external-dns.alpha.kubernetes.io/hostname"                   = "*.${var.external_dns_zone}${length(var.public_dns_zone_records) > 0 ? format(",%s", join(",", var.public_dns_zone_records)) : ""}"
          "service.beta.kubernetes.io/oci-load-balancer-shape"          = "flexible"
          "service.beta.kubernetes.io/oci-load-balancer-shape-flex-min" = "10"
          "service.beta.kubernetes.io/oci-load-balancer-shape-flex-max" = "50"
          "oci.oraclecloud.com/oci-network-security-groups"             = var.lb_sg_id
        }
      }
      listeners = concat(local.https_listeners, local.http_listeners)
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

resource "kubernetes_manifest" "letsencrypt_issuer" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "letsencrypt-issuer"
    }
    spec = {
      acme = {
        server  = "https://acme-v02.api.letsencrypt.org/directory"
        email   = var.acme_registration_email
        profile = "tlsserver"
        privateKeySecretRef = {
          name = "letsencrypt"
        }
        solvers = [
          {
            http01 = {
              gatewayHTTPRoute = {
                parentRefs = [
                  {
                    name = kubernetes_manifest.nginx_fabric_gateway_external.manifest.metadata.name
                  }
                ]
              }
            }
          }
        ]
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
