terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 7.25.0"
    }
  }
  required_version = ">= 1.5.0"
}

provider "oci" {
  auth                = "SecurityToken"
  config_file_profile = "DEFAULT"
  region              = var.region
}

module "cloud_guard" {
  source             = "../modules/cloud-guard"
  tenancy_id         = var.root_compartment_id
  region             = var.region
  reporting_region   = var.reporting_region
  notification_email = var.notification_email
  min_risk_levels    = var.min_risk_levels
}

output "target_id" {
  description = "OCID of the Cloud Guard target on the root compartment"
  value       = module.cloud_guard.target_id
}

output "responder_recipe_id" {
  description = "OCID of the detect-only responder recipe"
  value       = module.cloud_guard.responder_recipe_id
}

output "topic_id" {
  description = "OCID of the Cloud Guard problems notification topic"
  value       = module.cloud_guard.topic_id
}

output "events_rule_id" {
  description = "OCID of the Events rule that forwards Cloud Guard problems"
  value       = module.cloud_guard.events_rule_id
}

output "events_rule_condition" {
  description = "Condition of the Events rule"
  value       = module.cloud_guard.events_rule_condition
}
