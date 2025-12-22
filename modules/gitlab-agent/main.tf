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

resource "helm_release" "gitlab_agent" {
  name             = var.agent_name
  repository       = "https://charts.gitlab.io"
  chart            = "gitlab-agent"
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
