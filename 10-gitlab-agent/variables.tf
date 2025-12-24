variable "k8s_context" {
  description = "Kubernetes context to use"
  type        = string
}

variable "agent_name" {
  description = "GitLab agent name"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace for GitLab agent"
  type        = string
  default     = "gitlab-agent"
}

variable "token" {
  description = "GitLab agent token"
  type        = string
  sensitive   = true
}