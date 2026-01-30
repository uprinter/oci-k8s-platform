variable "compartment_id" { type = string }
variable "region" { type = string }
variable "oci_api_public_key" { type = string }
variable "approved_sender_emails" {
  type    = list(string)
  default = []
}

variable "technical_users_domain_name" { type = string }
variable "technical_users_domain_url" { type = string }

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

resource "oci_identity_domains_api_key" "external_dns_api_key" {
  idcs_endpoint = var.technical_users_domain_url
  key           = var.oci_api_public_key
  schemas       = ["urn:ietf:params:scim:schemas:oracle:idcs:apikey"]

  user {
    ocid  = oci_identity_domains_user.external_dns_user.ocid
    value = oci_identity_domains_user.external_dns_user.id
  }
}

resource "oci_identity_domains_user" "external_dns_user" {
  idcs_endpoint = var.technical_users_domain_url
  schemas = [
    "urn:ietf:params:scim:schemas:core:2.0:User",
    "urn:ietf:params:scim:schemas:oracle:idcs:extension:userState:User",
    "urn:ietf:params:scim:schemas:oracle:idcs:extension:OCITags",
    "urn:ietf:params:scim:schemas:oracle:idcs:extension:capabilities:User",
    "urn:ietf:params:scim:schemas:oracle:idcs:extension:user:User"
  ]
  user_name = "external-dns"
  name {
    family_name = "ExternalDNS"
  }
}

resource "oci_identity_domains_group" "external_dns_group" {
  display_name   = "ExternalDNS Users"
  idcs_endpoint  = var.technical_users_domain_url
  attribute_sets = ["all"]
  schemas = [
    "urn:ietf:params:scim:schemas:core:2.0:Group",
    "urn:ietf:params:scim:schemas:oracle:idcs:extension:OCITags",
    "urn:ietf:params:scim:schemas:oracle:idcs:extension:group:Group",
  ]

  members {
    value = oci_identity_domains_user.external_dns_user.id
    type  = "User"
  }
}

resource "oci_identity_policy" "external_dns_policy" {
  compartment_id = var.compartment_id
  name           = "external-dns-policy"
  description    = "Policy for ExternalDNS"
  statements = [
    "Allow group '${var.technical_users_domain_name}'/'${oci_identity_domains_group.external_dns_group.display_name}' to read dns-zones in compartment id ${var.compartment_id}",
    "Allow group '${var.technical_users_domain_name}'/'${oci_identity_domains_group.external_dns_group.display_name}' to manage dns in compartment id ${var.compartment_id}"
  ]
}

output "external_dns_user_ocid" {
  value = oci_identity_domains_user.external_dns_user.ocid
}

resource "oci_identity_domains_api_key" "external_secrets_api_key" {
  idcs_endpoint = var.technical_users_domain_url
  key           = var.oci_api_public_key
  schemas       = ["urn:ietf:params:scim:schemas:oracle:idcs:apikey"]

  user {
    ocid  = oci_identity_domains_user.external_secrets_user.ocid
    value = oci_identity_domains_user.external_secrets_user.id
  }
}

resource "oci_identity_domains_user" "external_secrets_user" {
  idcs_endpoint = var.technical_users_domain_url
  schemas = [
    "urn:ietf:params:scim:schemas:core:2.0:User",
    "urn:ietf:params:scim:schemas:oracle:idcs:extension:userState:User",
    "urn:ietf:params:scim:schemas:oracle:idcs:extension:OCITags",
    "urn:ietf:params:scim:schemas:oracle:idcs:extension:capabilities:User",
    "urn:ietf:params:scim:schemas:oracle:idcs:extension:user:User"
  ]
  user_name = "external-secrets"
  name {
    family_name = "ExternalSecrets"
  }
}

resource "oci_identity_domains_group" "external_secrets_group" {
  display_name   = "ExternalSecrets Users"
  idcs_endpoint  = var.technical_users_domain_url
  attribute_sets = ["all"]
  schemas = [
    "urn:ietf:params:scim:schemas:core:2.0:Group",
    "urn:ietf:params:scim:schemas:oracle:idcs:extension:OCITags",
    "urn:ietf:params:scim:schemas:oracle:idcs:extension:group:Group",
  ]

  members {
    value = oci_identity_domains_user.external_secrets_user.id
    type  = "User"
  }
}

resource "oci_identity_policy" "external_secrets_policy" {
  compartment_id = var.compartment_id
  name           = "external-secrets-policy"
  description    = "Policy for ExternalSecrets"
  statements = [
    "Allow group '${var.technical_users_domain_name}'/'${oci_identity_domains_group.external_secrets_group.display_name}' to use vaults in compartment id ${var.compartment_id}",
    "Allow group '${var.technical_users_domain_name}'/'${oci_identity_domains_group.external_secrets_group.display_name}' to manage keys in compartment id ${var.compartment_id}",
    "Allow group '${var.technical_users_domain_name}'/'${oci_identity_domains_group.external_secrets_group.display_name}' to manage secret-family in compartment id ${var.compartment_id}"
  ]
}

output "external_secrets_user_ocid" {
  value = oci_identity_domains_user.external_secrets_user.ocid
}

resource "oci_identity_domains_user" "email_sender_user" {
  idcs_endpoint = var.technical_users_domain_url
  schemas = [
    "urn:ietf:params:scim:schemas:core:2.0:User",
    "urn:ietf:params:scim:schemas:oracle:idcs:extension:userState:User",
    "urn:ietf:params:scim:schemas:oracle:idcs:extension:OCITags",
    "urn:ietf:params:scim:schemas:oracle:idcs:extension:capabilities:User",
    "urn:ietf:params:scim:schemas:oracle:idcs:extension:user:User"
  ]
  user_name = "email-sender"
  name {
    family_name = "EmailSender"
  }
}

resource "oci_identity_domains_group" "email_sender_group" {
  display_name   = "Email Senders"
  idcs_endpoint  = var.technical_users_domain_url
  attribute_sets = ["all"]
  schemas = [
    "urn:ietf:params:scim:schemas:core:2.0:Group",
    "urn:ietf:params:scim:schemas:oracle:idcs:extension:OCITags",
    "urn:ietf:params:scim:schemas:oracle:idcs:extension:group:Group",
  ]

  members {
    value = oci_identity_domains_user.email_sender_user.id
    type  = "User"
  }
}

resource "oci_identity_policy" "email_sender_policy" {
  compartment_id = var.compartment_id
  name           = "email-sender-policy"
  description    = "Policy for Email Sender"
  statements = [
    "Allow group '${var.technical_users_domain_name}'/'${oci_identity_domains_group.email_sender_group.display_name}' to use email-family in compartment id ${var.compartment_id}"
  ]
}

resource "oci_email_sender" "approved_sender" {
  for_each       = toset(var.approved_sender_emails)
  compartment_id = var.compartment_id
  email_address  = each.value
}
