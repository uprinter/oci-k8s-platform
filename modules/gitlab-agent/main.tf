variable "agent_name" {
  type = string
}

variable "namespace" {
  type = string
}

variable "token" {
  type      = string
  sensitive = true
}

variable "chart_version" {
  description = "GitLab agent for Kubernetes Helm chart version (https://charts.gitlab.io)."
  type        = string
  default     = "2.22.0"
}

resource "helm_release" "gitlab_agent" {
  name             = var.agent_name
  repository       = "https://charts.gitlab.io"
  chart            = "gitlab-agent"
  version          = var.chart_version
  namespace        = var.namespace
  create_namespace = true

  set = [
    {
      name  = "config.token"
      value = var.token
    },
    {
      name  = "config.kasAddress"
      value = "wss://kas.gitlab.com"
    }
  ]
}
