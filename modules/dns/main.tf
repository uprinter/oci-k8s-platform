variable "compartment_id" { type = string }
variable "vcn_id" { type = string }
variable "internal_dns_zone" { type = string }
variable "external_dns_zone" { type = string }
variable "public_dns_zones" { type = list(string) }

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
  scope          = "PRIVATE"
  view_id        = oci_dns_view.private_view.id
}

resource "oci_dns_zone" "external_dns_zone" {
  compartment_id = var.compartment_id
  name           = var.external_dns_zone
  zone_type      = "PRIMARY"
  scope          = "PRIVATE"
  view_id        = oci_dns_view.private_view.id
}

resource "oci_dns_zone" "public_dns_zones" {
  for_each       = toset(var.public_dns_zones)
  compartment_id = var.compartment_id
  name           = each.value
  zone_type      = "PRIMARY"
  scope          = "GLOBAL"
}

