variable "root_compartment_id" {
  description = "The OCID of the root compartment"
  type        = string
}

variable "region" {
  description = "The OCI region to deploy resources in"
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key for accessing instances"
  type        = string
}

variable "vpn_image_id" {
  description = "OCID of the OpenVPN image"
  type        = string
}

variable "vpn_instance_shape" {
  description = "Shape for the VPN instance"
  type        = string
  default     = "VM.Standard.E2.1.Micro"
}

variable "vpn_instance_name" {
  description = "Display name for the VPN instance"
  type        = string
  default     = "openvpn-instance"
}

variable "vpn_subnet_id" {
  description = "VPN subnet ID"
  type        = string
}

variable "vpn_nsg_id" {
  description = "VPN NSG ID"
  type        = string
}
