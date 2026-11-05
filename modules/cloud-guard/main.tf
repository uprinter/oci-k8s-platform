variable "tenancy_id" {
  description = "OCID of the tenancy (root compartment). Cloud Guard is configured and targeted here."
  type        = string
}

variable "region" {
  description = "OCI region the provider calls. Must equal reporting_region."
  type        = string
}

variable "reporting_region" {
  description = "Cloud Guard reporting region. Problems, targets, recipes and Cloud Guard events live in this region."
  type        = string
}

variable "notification_email" {
  description = "Email address that receives Cloud Guard problem notifications. Supply it only through the stack's gitignored terraform.tfvars."
  type        = string
  sensitive   = true
}

variable "min_risk_levels" {
  description = "Cloud Guard risk levels that trigger an email. An empty list sends every detected problem."
  type        = list(string)
  default     = ["CRITICAL", "HIGH"]

  validation {
    condition     = alltrue([for l in var.min_risk_levels : contains(["CRITICAL", "HIGH", "MEDIUM", "LOW", "MINOR"], l)])
    error_message = "min_risk_levels accepts only CRITICAL, HIGH, MEDIUM, LOW and MINOR."
  }
}

variable "target_name" {
  description = "Display name of the Cloud Guard target on the root compartment."
  type        = string
  default     = "cloud-guard-root"
}

variable "topic_name" {
  description = "Name of the Notifications topic and the Events rule for Cloud Guard problems."
  type        = string
  default     = "cloud-guard-problems"
}

variable "responder_recipe_name" {
  description = "Display name of the cloned responder recipe."
  type        = string
  default     = "cloud-guard-detect-only"
}

locals {
  # Aliases of the Oracle-managed recipes. They are not recipe ids: once Cloud
  # Guard is enabled, each Oracle recipe has its own OCID and carries the alias
  # only in source_detector_recipe_id or source_responder_recipe_id. The data
  # sources below look the OCIDs up by alias. The Instance Security and
  # Container Security recipes are deliberately absent: they need agents or
  # paid tiers and are not part of this setup.
  detector_recipe_aliases = [
    "Oracle_Managed_Recipe_Configuration",
    "Oracle_Managed_Recipe_Activity",
    "Oracle_Managed_Recipe_Threat",
  ]

  responder_recipe_alias = "Oracle_Managed_Responder_Recipe"

  detector_recipe_ids_by_alias = {
    for r in data.oci_cloud_guard_detector_recipes.oracle.detector_recipe_collection[0].items :
    r.source_detector_recipe_id => r.id
  }

  # Every rule of the Oracle responder recipe. Only EVENT (publish the problem
  # to the Events service) stays enabled; every rule that can change a
  # resource is disabled. The postcondition on the clone fails the apply if
  # this list and the real recipe differ, so a renamed or new Oracle rule can
  # never stay enabled unnoticed.
  responder_rules = {
    EVENT                   = true
    DELETE_IAM_POLICY       = false
    DELETE_INTERNET_GATEWAY = false
    DELETE_PUBLIC_IP        = false
    DISABLE_IAM_USER        = false
    ENABLE_DB_BACKUP        = false
    MAKE_BUCKET_PRIVATE     = false
    ROTATE_VAULT_KEY        = false
    STOP_INSTANCE           = false
    TERMINATE_INSTANCE      = false
  }

  risk_filter = length(var.min_risk_levels) > 0 ? {
    additionalDetails = { riskLevel = var.min_risk_levels }
  } : {}

  event_condition = merge(
    { eventType = ["com.oraclecloud.cloudguard.problemdetected"] },
    length(local.risk_filter) > 0 ? { data = local.risk_filter } : {},
  )
}

resource "oci_cloud_guard_cloud_guard_configuration" "this" {
  compartment_id        = var.tenancy_id
  reporting_region      = var.reporting_region
  status                = "ENABLED"
  self_manage_resources = false

  lifecycle {
    precondition {
      condition     = var.region == var.reporting_region
      error_message = "Run this stack with region equal to reporting_region: Cloud Guard targets, recipes and events exist only in the reporting region."
    }
  }
}

# The lookups depend on the enabling resource: the Oracle recipes have OCIDs
# only while Cloud Guard is enabled, so a plan taken before the service was
# enabled cannot prove these lookups.
data "oci_cloud_guard_detector_recipes" "oracle" {
  compartment_id            = var.tenancy_id
  access_level              = "ACCESSIBLE"
  compartment_id_in_subtree = true
  state                     = "ACTIVE"

  filter {
    name   = "owner"
    values = ["ORACLE"]
  }

  filter {
    name   = "source_detector_recipe_id"
    values = local.detector_recipe_aliases
  }

  lifecycle {
    postcondition {
      condition     = length(self.detector_recipe_collection) == 1 && length(self.detector_recipe_collection[0].items) == length(local.detector_recipe_aliases) && toset([for r in self.detector_recipe_collection[0].items : r.source_detector_recipe_id]) == toset(local.detector_recipe_aliases)
      error_message = "Expected exactly the Oracle-managed Configuration, Activity and Threat detector recipes."
    }
  }

  depends_on = [oci_cloud_guard_cloud_guard_configuration.this]
}

data "oci_cloud_guard_responder_recipes" "oracle" {
  compartment_id            = var.tenancy_id
  access_level              = "ACCESSIBLE"
  compartment_id_in_subtree = true
  state                     = "ACTIVE"

  filter {
    name   = "owner"
    values = ["ORACLE"]
  }

  filter {
    name   = "source_responder_recipe_id"
    values = [local.responder_recipe_alias]
  }

  lifecycle {
    postcondition {
      condition     = length(self.responder_recipe_collection) == 1 && length(self.responder_recipe_collection[0].items) == 1
      error_message = "Expected exactly one Oracle-managed responder recipe."
    }
  }

  depends_on = [oci_cloud_guard_cloud_guard_configuration.this]
}

# The list data source returns no rules, so the rules are read by id.
data "oci_cloud_guard_responder_recipe" "oracle" {
  responder_recipe_id = data.oci_cloud_guard_responder_recipes.oracle.responder_recipe_collection[0].items[0].id

  lifecycle {
    postcondition {
      condition     = toset([for r in self.effective_responder_rules : r.responder_rule_id]) == toset(keys(local.responder_rules))
      error_message = "The Oracle responder recipe rules differ from local.responder_rules. Update the list in modules/cloud-guard before you clone the recipe."
    }
  }
}

resource "oci_cloud_guard_responder_recipe" "detect_only" {
  compartment_id             = var.tenancy_id
  display_name               = var.responder_recipe_name
  description                = "Clone of the Oracle responder recipe with every rule disabled except EVENT"
  source_responder_recipe_id = data.oci_cloud_guard_responder_recipe.oracle.id

  dynamic "responder_rules" {
    for_each = local.responder_rules
    content {
      responder_rule_id = responder_rules.key
      details {
        is_enabled = responder_rules.value
      }
    }
  }

  lifecycle {
    postcondition {
      condition     = toset([for r in self.effective_responder_rules : r.responder_rule_id]) == toset(keys(local.responder_rules))
      error_message = "The Oracle responder recipe rules differ from local.responder_rules. Update the list in modules/cloud-guard before you attach the recipe to a target."
    }
    postcondition {
      condition = alltrue([
        for r in self.effective_responder_rules :
        alltrue([for d in r.details : d.is_enabled == (r.responder_rule_id == "EVENT")])
      ])
      error_message = "A responder rule other than EVENT is enabled on the detect-only recipe."
    }
  }

  depends_on = [oci_cloud_guard_cloud_guard_configuration.this]
}

resource "oci_cloud_guard_target" "root" {
  compartment_id       = var.tenancy_id
  display_name         = var.target_name
  description          = "Cloud Guard target on the root compartment, detect-only"
  target_resource_type = "COMPARTMENT"
  target_resource_id   = var.tenancy_id

  dynamic "target_detector_recipes" {
    for_each = local.detector_recipe_aliases
    content {
      detector_recipe_id = local.detector_recipe_ids_by_alias[target_detector_recipes.value]
    }
  }

  target_responder_recipes {
    responder_recipe_id = oci_cloud_guard_responder_recipe.detect_only.id
  }

  depends_on = [oci_cloud_guard_cloud_guard_configuration.this]
}

resource "oci_ons_notification_topic" "problems" {
  compartment_id = var.tenancy_id
  name           = var.topic_name
  description    = "Cloud Guard problem notifications"
}

resource "oci_ons_subscription" "email" {
  compartment_id = var.tenancy_id
  topic_id       = oci_ons_notification_topic.problems.id
  protocol       = "EMAIL"
  endpoint       = var.notification_email
}

resource "oci_events_rule" "problems" {
  compartment_id = var.tenancy_id
  display_name   = var.topic_name
  description    = "Send detected Cloud Guard problems to the notification topic"
  is_enabled     = true
  condition      = jsonencode(local.event_condition)

  actions {
    actions {
      action_type = "ONS"
      is_enabled  = true
      topic_id    = oci_ons_notification_topic.problems.id
    }
  }
}

output "target_id" {
  description = "OCID of the Cloud Guard target on the root compartment"
  value       = oci_cloud_guard_target.root.id
}

output "responder_recipe_id" {
  description = "OCID of the detect-only responder recipe"
  value       = oci_cloud_guard_responder_recipe.detect_only.id
}

output "topic_id" {
  description = "OCID of the Cloud Guard problems notification topic"
  value       = oci_ons_notification_topic.problems.id
}

output "events_rule_id" {
  description = "OCID of the Events rule that forwards Cloud Guard problems"
  value       = oci_events_rule.problems.id
}

output "events_rule_condition" {
  description = "Condition of the Events rule"
  value       = oci_events_rule.problems.condition
}
