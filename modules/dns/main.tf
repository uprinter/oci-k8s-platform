variable "compartment_id" { type = string }
variable "vcn_id" { type = string }
variable "internal_dns_zone" { type = string }
variable "external_dns_zone" { type = string }
variable "external_dns_public_key" { type = string }
variable "scope" { type = string }
variable "technical_users_domain_name" { type = string }
variable "technical_users_domain_url" { type = string }

data "oci_core_vcn_dns_resolver_association" "vcn_dns_resolver_association" {
  vcn_id = var.vcn_id
}

resource "oci_dns_view" "private_view" {
  compartment_id = var.compartment_id
  display_name   = "private"
}

resource "oci_dns_resolver" "resolver" {
  resolver_id = data.oci_core_vcn_dns_resolver_association.vcn_dns_resolver_association.dns_resolver_id

  attached_views {
    view_id = oci_dns_view.private_view.id
  }
}

resource "oci_dns_zone" "internal_dns_zone" {
  compartment_id = var.compartment_id
  name           = var.internal_dns_zone
  zone_type      = "PRIMARY"
  scope          = var.scope
  view_id        = oci_dns_view.private_view.id
}

resource "oci_dns_zone" "external_dns_zone" {
  compartment_id = var.compartment_id
  name           = var.external_dns_zone
  zone_type      = "PRIMARY"
  scope          = var.scope
  view_id        = oci_dns_view.private_view.id
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
    "urn:ietf:params:scim:schemas:oracle:idcs:extension:dynamic:Group",
    "urn:ietf:params:scim:schemas:oracle:idcs:extension:OCITags"
  ]

  members {
    value = oci_identity_domains_user.external_dns_user.id
    type  = "User"
  }
}

resource "oci_identity_policy" "external_dns_policy" {
  compartment_id = var.compartment_id
  name           = "external-dns-policy"
  description    = "Policy for External DNS"
  statements = [
    "Allow group '${var.technical_users_domain_name}'/'${oci_identity_domains_group.external_dns_group.display_name}' to read dns-zones in compartment id ${var.compartment_id}",
    "Allow group '${var.technical_users_domain_name}'/'${oci_identity_domains_group.external_dns_group.display_name}' to manage dns in compartment id ${var.compartment_id}"
  ]
}

resource "oci_identity_domains_api_key" "external_dns_api_key" {
  idcs_endpoint = var.technical_users_domain_url
  key           = var.external_dns_public_key
  schemas       = ["urn:ietf:params:scim:schemas:oracle:idcs:apikey"]

  user {
    ocid  = oci_identity_domains_user.external_dns_user.ocid
    value = oci_identity_domains_user.external_dns_user.id
  }
}

output "external_dns_user_ocid" {
  value = oci_identity_domains_user.external_dns_user.ocid
}