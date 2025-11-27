variable "compartment_id" { type = string }
variable "availability_domain" { type = string }
variable "vpn_subnet_id" { type = string }
variable "vpn_sg_id" { type = string }
variable "ssh_public_key" { type = string }
variable "vpn_image_id" { type = string }
variable "vpn_instance_shape" { type = string }
variable "vpn_instance_name" { type = string }

resource "oci_core_instance" "openvpn_instance" {
  compartment_id      = var.compartment_id
  availability_domain = var.availability_domain
  shape               = var.vpn_instance_shape
  display_name        = var.vpn_instance_name

  shape_config {
    ocpus         = 1
    memory_in_gbs = 1
  }

  source_details {
    source_type = "image"
    source_id   = var.vpn_image_id
  }

  create_vnic_details {
    subnet_id = var.vpn_subnet_id
    nsg_ids   = [var.vpn_sg_id]
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
  }
}
