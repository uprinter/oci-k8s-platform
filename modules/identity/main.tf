variable "compartment_id" { type = string }
variable "region" { type = string }

resource "oci_identity_policy" "network_path_analyzer_policy" {
  compartment_id = var.compartment_id
  name           = "network-path-analyzer-policy"
  description    = "Policy for Network Path Analyzer"
  statements = [
    "Allow any-user to inspect compartments in tenancy where all { request.principal.type = 'vnpa-service' }",
    "Allow any-user to read instances in tenancy where all { request.principal.type = 'vnpa-service' }",
    "Allow any-user to read virtual-network-family in tenancy where all { request.principal.type = 'vnpa-service' }",
    "Allow any-user to read load-balancers in tenancy where all { request.principal.type = 'vnpa-service' }",
    "Allow any-user to read network-security-group in tenancy where all { request.principal.type = 'vnpa-service' }"
  ]
}

resource "oci_identity_domain" "technical_users_domain" {
  compartment_id            = var.compartment_id
  description               = "Technical users"
  display_name              = "TechnicalUsers"
  home_region               = var.region
  license_type              = "free"
  is_primary_email_required = false
}

output "technical_users_domain_url" {
  value = oci_identity_domain.technical_users_domain.url
}

output "technical_users_domain_name" {
  value = oci_identity_domain.technical_users_domain.display_name
}