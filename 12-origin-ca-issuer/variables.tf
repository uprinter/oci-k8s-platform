variable "k8s_context" {
  description = "Kubernetes context to use"
  type        = string
}

variable "origin_ca_token_vault_secret_name" {
  description = "Name of the OCI Vault secret (consumed via the oci-secret-store ClusterSecretStore) holding the scoped Cloudflare Origin CA API token."
  type        = string
}

variable "origin_ca_request_type" {
  description = "Origin CA certificate key type: OriginRSA or OriginECC."
  type        = string
  default     = "OriginRSA"
}

variable "nginx_gateway_namespace" {
  description = "Namespace of the nginx-gateway external Gateway where the origin certificate Secret must be created."
  type        = string
  default     = "nginx-gateway"
}

variable "origin_certificate_secret_name" {
  description = "Name of the origin Certificate resource and its Secret. cert-manager's gateway-shim backs off from a listener's auto-managed cert only when a Certificate resource already exists with the EXACT name the listener's TLS certificateRef expects (see modules/nginx-gateway: derived as replace(hostname, \".\", \"-\") + \"-cert\" for each entry in public_hosted_zone_records). This value MUST match that derivation for whichever hostname is being onboarded — set via terraform.tfvars (gitignored), no public default."
  type        = string
}

variable "origin_certificate_dns_names" {
  description = "SANs for the Origin CA certificate (apex + wildcard is the usual choice, so one cert covers the apex and any subdomain). Set via terraform.tfvars (gitignored) — this repo is public, so no domain name is committed as a default."
  type        = list(string)
}
