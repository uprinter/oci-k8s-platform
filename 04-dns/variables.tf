variable "root_compartment_id" {
  description = "The OCID of the root compartment"
  type        = string
}

variable "region" {
  description = "The OCI region to deploy resources in"
  type        = string
}

variable "internal_zone_name" {
  description = "Internal DNS zone name"
  type        = string
}     

variable "external_zone_name" {
  description = "External DNS zone name"
  type        = string
}

variable "public_zone_names" {
  description = "Public DNS zone names"
  type        = list(string)
  default     = []
}

variable "vcn_id" {
  description = "VCN ID"
  type        = string
}
