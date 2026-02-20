variable "root_compartment_id" {
  description = "The OCID of the root compartment"
  type        = string
}

variable "region" {
  description = "The OCI region to deploy resources in"
  type        = string
}

variable "cluster_name" {
  description = "Name of the OKE cluster"
  type        = string
  default     = "k8s-cluster"
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "v1.34.2"
}

variable "cni_type" {
  description = "CNI type for the cluster"
  type        = string
  default     = "OCI_VCN_IP_NATIVE"
}

variable "is_basic_cluster" {
  description = "Whether to create a basic cluster"
  type        = bool
  default     = true
}

variable "node_pool_name" {
  description = "Name of the node pool"
  type        = string
  default     = "k8s-node-pool"
}

variable "node_shape" {
  description = "Shape of the worker nodes"
  type        = string
  default     = "VM.Standard.A1.Flex"
}

variable "node_ocpus" {
  description = "Number of OCPUs per node"
  type        = number
  default     = 8
}

variable "node_memory_in_gbs" {
  description = "Memory in GBs per node"
  type        = number
  default     = 27
}

variable "node_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 1
}

variable "node_image_id" {
  description = "OCID of the node image"
  type        = string
}

variable "vcn_id" {
  description = "VCN ID"
  type        = string
}

variable "worker_subnet_id" {
  description = "Worker subnet ID"
  type        = string
}

variable "api_subnet_id" {
  description = "API subnet ID"
  type        = string
}

variable "lb_subnet_id" {
  description = "Load balancer subnet ID"
  type        = string
}

variable "pod_subnet_id" {
  description = "Pod subnet ID"
  type        = string
}

variable "api_nsg_id" {
  description = "API NSG ID"
  type        = string
}

variable "worker_nsg_id" {
  description = "Worker NSG ID"
  type        = string
}

variable "pod_nsg_id" {
  description = "Pod NSG ID"
  type        = string
}

variable "use_preemptible_nodes" {
  description = "Whether to use preemptible capacity for worker nodes (50% cost savings)"
  type        = bool
  default     = false
}

variable "preserve_boot_volume_on_preemption" {
  description = "Whether to preserve boot volume when preemptible node is reclaimed"
  type        = bool
  default     = false
}

variable "capacity_reservation_id" {
  description = "OCID of compute capacity reservation for worker nodes (optional)"
  type        = string
  default     = null
}
