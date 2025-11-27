variable "compartment_id" {
  description = "The OCID of the compartment."
}

data "oci_core_services" "all_services" {}

resource "oci_core_vcn" "k8s_vcn" {
  compartment_id = var.compartment_id
  display_name   = "k8s_vcn"
  cidr_block     = "10.0.0.0/16"
  dns_label      = "k8svcn"
}

resource "oci_core_internet_gateway" "k8s_ig" {
  compartment_id = var.compartment_id
  display_name   = "k8s_ig"
  vcn_id         = oci_core_vcn.k8s_vcn.id
}

resource "oci_core_nat_gateway" "k8s_nat" {
  compartment_id = var.compartment_id
  display_name   = "k8s_nat"
  vcn_id         = oci_core_vcn.k8s_vcn.id
}

resource "oci_core_service_gateway" "k8s_sg" {
  compartment_id = var.compartment_id
  display_name   = "k8s_sg"
  vcn_id         = oci_core_vcn.k8s_vcn.id
  services {
    service_id = data.oci_core_services.all_services.services[0].id
  }
}

resource "oci_core_route_table" "k8s_worker_rt" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.k8s_vcn.id
  display_name   = "k8s_worker_rt"
  route_rules {
    destination       = "0.0.0.0/0"
    network_entity_id = oci_core_nat_gateway.k8s_nat.id
  }
  route_rules {
    destination       = data.oci_core_services.all_services.services[0].cidr_block
    destination_type  = "SERVICE_CIDR_BLOCK"
    network_entity_id = oci_core_service_gateway.k8s_sg.id
  }
}

resource "oci_core_route_table" "k8s_api_rt" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.k8s_vcn.id
  display_name   = "k8s_api_rt"
  route_rules {
    destination       = "0.0.0.0/0"
    network_entity_id = oci_core_nat_gateway.k8s_nat.id
  }
}

resource "oci_core_route_table" "k8s_lb_rt" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.k8s_vcn.id
  display_name   = "k8s_lb_rt"
  route_rules {
    destination       = "0.0.0.0/0"
    network_entity_id = oci_core_internet_gateway.k8s_ig.id
  }
}

resource "oci_core_route_table" "k8s_pod_rt" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.k8s_vcn.id
  display_name   = "k8s_pod_rt"
  route_rules {
    destination       = "0.0.0.0/0"
    network_entity_id = oci_core_nat_gateway.k8s_nat.id
  }
  route_rules {
    destination       = data.oci_core_services.all_services.services[0].cidr_block
    destination_type  = "SERVICE_CIDR_BLOCK"
    network_entity_id = oci_core_service_gateway.k8s_sg.id
  }
}

resource "oci_core_route_table" "vpn_rt" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.k8s_vcn.id
  display_name   = "vpn_rt"
  route_rules {
    destination       = "0.0.0.0/0"
    network_entity_id = oci_core_internet_gateway.k8s_ig.id
  }
}

resource "oci_core_subnet" "k8s_worker_subnet" {
  compartment_id             = var.compartment_id
  vcn_id                     = oci_core_vcn.k8s_vcn.id
  display_name               = "k8s_worker_subnet"
  cidr_block                 = "10.0.1.0/24"
  route_table_id             = oci_core_route_table.k8s_worker_rt.id
  dns_label                  = "k8sworker"
  prohibit_public_ip_on_vnic = true
}

resource "oci_core_subnet" "k8s_api_subnet" {
  compartment_id             = var.compartment_id
  vcn_id                     = oci_core_vcn.k8s_vcn.id
  display_name               = "k8s_api_subnet"
  cidr_block                 = "10.0.0.0/29"
  route_table_id             = oci_core_route_table.k8s_api_rt.id
  dns_label                  = "k8sapi"
  prohibit_public_ip_on_vnic = true
}

resource "oci_core_subnet" "k8s_lb_subnet" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.k8s_vcn.id
  display_name   = "k8s_lb_subnet"
  cidr_block     = "10.0.2.0/24"
  route_table_id = oci_core_route_table.k8s_lb_rt.id
  dns_label      = "k8slb"
}

resource "oci_core_subnet" "k8s_pod_subnet" {
  compartment_id             = var.compartment_id
  vcn_id                     = oci_core_vcn.k8s_vcn.id
  display_name               = "k8s_pod_subnet"
  cidr_block                 = "10.0.32.0/19"
  route_table_id             = oci_core_route_table.k8s_pod_rt.id
  dns_label                  = "k8spod"
  prohibit_public_ip_on_vnic = true
}

resource "oci_core_subnet" "vpn_subnet" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.k8s_vcn.id
  display_name   = "vpn_subnet"
  cidr_block     = "10.0.3.0/24"
  route_table_id = oci_core_route_table.vpn_rt.id
  dns_label      = "vpn"
}

resource "oci_core_network_security_group" "k8s_api_nsg" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.k8s_vcn.id
  display_name   = "k8s_api_nsg"
}

resource "oci_core_network_security_group" "k8s_worker_nsg" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.k8s_vcn.id
  display_name   = "k8s_worker_nsg"
}

resource "oci_core_network_security_group" "k8s_pod_nsg" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.k8s_vcn.id
  display_name   = "k8s_pod_nsg"
}

resource "oci_core_network_security_group" "k8s_lb_nsg" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.k8s_vcn.id
  display_name   = "k8s_lb_nsg"
}

resource "oci_core_network_security_group" "vpn_nsg" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.k8s_vcn.id
  display_name   = "vpn_nsg"
}


/*
 * Security List Rules for Public Kubernetes API Endpoint Subnet
 */

# Public access to Kubernetes API endpoint.
resource "oci_core_network_security_group_security_rule" "api_ingress_public" {
  network_security_group_id = oci_core_network_security_group.k8s_api_nsg.id
  description               = "Allow public access to Kubernetes API endpoint"
  direction                 = "INGRESS"
  protocol                  = "6" // TCP
  source                    = "0.0.0.0/0"
  source_type               = "CIDR_BLOCK"
  tcp_options {
    destination_port_range {
      min = 6443
      max = 6443
    }
  }
}

# Kubernetes worker to Kubernetes API endpoint communication.
resource "oci_core_network_security_group_security_rule" "api_ingress_worker" {
  network_security_group_id = oci_core_network_security_group.k8s_api_nsg.id
  description               = "Allow worker nodes to communicate with the Kubernetes API endpoint"
  direction                 = "INGRESS"
  protocol                  = "6" // TCP
  source                    = oci_core_subnet.k8s_worker_subnet.cidr_block
  source_type               = "CIDR_BLOCK"
  tcp_options {
    destination_port_range {
      min = 6443
      max = 6443
    }
  }
}

# Kubernetes worker to Kubernetes API endpoint communication.
resource "oci_core_network_security_group_security_rule" "api_ingress_worker_control_plane" {
  network_security_group_id = oci_core_network_security_group.k8s_api_nsg.id
  description               = "Allow worker nodes to communicate with the Kubernetes API control plane"
  direction                 = "INGRESS"
  protocol                  = "6" // TCP
  source                    = oci_core_subnet.k8s_worker_subnet.cidr_block
  source_type               = "CIDR_BLOCK"
  tcp_options {
    destination_port_range {
      min = 12250
      max = 12250
    }
  }
}

# Path Discovery.
resource "oci_core_network_security_group_security_rule" "api_ingress_worker_path_discovery" {
  network_security_group_id = oci_core_network_security_group.k8s_api_nsg.id
  description               = "Allow worker nodes to communicate with the Kubernetes API endpoint for path discovery"
  direction                 = "INGRESS"
  protocol                  = "1" // ICMP
  source                    = oci_core_subnet.k8s_worker_subnet.cidr_block
  source_type               = "CIDR_BLOCK"
  icmp_options {
    type = 3
    code = 4
  }
}

# Pod to Kubernetes API endpoint communication.
resource "oci_core_network_security_group_security_rule" "api_ingress_pod" {
  network_security_group_id = oci_core_network_security_group.k8s_api_nsg.id
  description               = "Allow pod nodes to communicate with the Kubernetes API endpoint"
  direction                 = "INGRESS"
  protocol                  = "6" // TCP
  source                    = oci_core_subnet.k8s_pod_subnet.cidr_block
  source_type               = "CIDR_BLOCK"
  tcp_options {
    destination_port_range {
      min = 6443
      max = 6443
    }
  }
}

# Pod to Kubernetes API endpoint communication.
resource "oci_core_network_security_group_security_rule" "api_ingress_pod_control_plane" {
  network_security_group_id = oci_core_network_security_group.k8s_api_nsg.id
  description               = "Allow pod nodes to communicate with the Kubernetes API control plane"
  direction                 = "INGRESS"
  protocol                  = "6" // TCP
  source                    = oci_core_subnet.k8s_pod_subnet.cidr_block
  source_type               = "CIDR_BLOCK"
  tcp_options {
    destination_port_range {
      min = 12250
      max = 12250
    }
  }
}

# Allow Kubernetes API endpoint to communicate with OKE.
resource "oci_core_network_security_group_security_rule" "api_egress_oke" {
  network_security_group_id = oci_core_network_security_group.k8s_api_nsg.id
  description               = "Allow Kubernetes API endpoint to communicate with OKE."
  direction                 = "EGRESS"
  protocol                  = "6" // TCP
  destination               = data.oci_core_services.all_services.services[0].cidr_block
  destination_type          = "SERVICE_CIDR_BLOCK"
}

# Path Discovery.
resource "oci_core_network_security_group_security_rule" "api_egress_path_discovery" {
  network_security_group_id = oci_core_network_security_group.k8s_api_nsg.id
  description               = "Allow Kubernetes API endpoint to communicate with worker nodes for path discovery."
  direction                 = "EGRESS"
  protocol                  = "1" // ICMP
  destination               = data.oci_core_services.all_services.services[0].cidr_block
  destination_type          = "SERVICE_CIDR_BLOCK"
  icmp_options {
    type = 3
    code = 4
  }
}

# Allow Kubernetes API endpoint to communicate with worker nodes.
resource "oci_core_network_security_group_security_rule" "api_egress_worker" {
  network_security_group_id = oci_core_network_security_group.k8s_api_nsg.id
  description               = "Allow Kubernetes API endpoint to communicate with worker nodes."
  direction                 = "EGRESS"
  protocol                  = "6" // TCP
  destination               = oci_core_subnet.k8s_worker_subnet.cidr_block
  destination_type          = "CIDR_BLOCK"
  tcp_options {
    destination_port_range {
      min = 10250
      max = 10250
    }
  }
}

# Path Discovery.
resource "oci_core_network_security_group_security_rule" "api_egress_worker_path_discovery" {
  network_security_group_id = oci_core_network_security_group.k8s_api_nsg.id
  description               = "Allow Kubernetes API endpoint to communicate with worker nodes for path discovery."
  direction                 = "EGRESS"
  protocol                  = "1" // ICMP
  destination               = oci_core_subnet.k8s_worker_subnet.cidr_block
  destination_type          = "CIDR_BLOCK"
  icmp_options {
    type = 3
    code = 4
  }
}

# Allow Kubernetes API endpoint to communicate with pods.
resource "oci_core_network_security_group_security_rule" "api_egress_pod" {
  network_security_group_id = oci_core_network_security_group.k8s_api_nsg.id
  description               = "Allow Kubernetes API endpoint to communicate with pod nodes."
  direction                 = "EGRESS"
  protocol                  = "6" // TCP
  destination               = oci_core_subnet.k8s_pod_subnet.cidr_block
  destination_type          = "CIDR_BLOCK"
}


/*
 * Security List Rules for Private Worker Nodes Subnet
 */

# Allow Kubernetes API endpoint to communicate with worker nodes.
resource "oci_core_network_security_group_security_rule" "worker_ingress_api" {
  network_security_group_id = oci_core_network_security_group.k8s_worker_nsg.id
  description               = "Allow Kubernetes API endpoint to communicate with worker nodes."
  direction                 = "INGRESS"
  protocol                  = "6" // TCP
  source                    = oci_core_subnet.k8s_api_subnet.cidr_block
  source_type               = "CIDR_BLOCK"
  tcp_options {
    destination_port_range {
      min = 10250
      max = 10250
    }
  }
}

# Allow VPN to communicate with worker nodes.
resource "oci_core_network_security_group_security_rule" "worker_ingress_vpn" {
  network_security_group_id = oci_core_network_security_group.k8s_worker_nsg.id
  description               = "Allow VPN to communicate with worker nodes."
  direction                 = "INGRESS"
  protocol                  = "6" // TCP
  source                    = oci_core_subnet.vpn_subnet.cidr_block
  source_type               = "CIDR_BLOCK"
  tcp_options {
    destination_port_range {
      min = 30000
      max = 32767
    }
  }
}

# Path Discovery.
resource "oci_core_network_security_group_security_rule" "worker_ingress_path_discovery" {
  network_security_group_id = oci_core_network_security_group.k8s_worker_nsg.id
  description               = "Allow worker nodes to communicate with the Kubernetes API endpoint for path discovery."
  direction                 = "INGRESS"
  protocol                  = "1" // ICMP
  source                    = "0.0.0.0/0"
  source_type               = "CIDR_BLOCK"
  icmp_options {
    type = 3
    code = 4
  }
}

# Load balancer to worker nodes node ports.
resource "oci_core_network_security_group_security_rule" "worker_ingress_lb" {
  network_security_group_id = oci_core_network_security_group.k8s_worker_nsg.id
  description               = "Allow load balancer to communicate with worker node ports."
  direction                 = "INGRESS"
  protocol                  = "6" // TCP
  source                    = oci_core_subnet.k8s_lb_subnet.cidr_block
  source_type               = "CIDR_BLOCK"
  tcp_options {
    destination_port_range {
      min = 30000
      max = 32767
    }
  }
}

# Allow load balancer to communicate with kube-proxy on worker nodes.
resource "oci_core_network_security_group_security_rule" "worker_ingress_lb_kubeproxy" {
  network_security_group_id = oci_core_network_security_group.k8s_worker_nsg.id
  description               = "Allow load balancer to communicate with kube-proxy on worker nodes."
  direction                 = "INGRESS"
  protocol                  = "6" // TCP
  source                    = oci_core_subnet.k8s_lb_subnet.cidr_block
  source_type               = "CIDR_BLOCK"
  tcp_options {
    destination_port_range {
      min = 10256
      max = 10256
    }
  }
}

# Allow worker nodes to access public internet.
resource "oci_core_network_security_group_security_rule" "worker_egress_internet" {
  network_security_group_id = oci_core_network_security_group.k8s_worker_nsg.id
  description               = "Allow worker nodes to access public internet."
  direction                 = "EGRESS"
  protocol                  = "6" // TCP
  destination               = "0.0.0.0/0"
  destination_type          = "CIDR_BLOCK"
  tcp_options {
    destination_port_range {
      min = 443
      max = 443
    }
  }
}

# Allow worker nodes to access pods.
resource "oci_core_network_security_group_security_rule" "worker_egress_to_pod" {
  network_security_group_id = oci_core_network_security_group.k8s_worker_nsg.id
  description               = "Allow worker nodes to access pods."
  direction                 = "EGRESS"
  protocol                  = "all"
  destination               = oci_core_subnet.k8s_pod_subnet.cidr_block
  destination_type          = "CIDR_BLOCK"
}

# Path Discovery.
resource "oci_core_network_security_group_security_rule" "worker_egress_path_discovery" {
  network_security_group_id = oci_core_network_security_group.k8s_worker_nsg.id
  description               = "Allow worker nodes to communicate with the Kubernetes API endpoint for path discovery."
  direction                 = "EGRESS"
  protocol                  = "1" // ICMP
  destination               = "0.0.0.0/0"
  destination_type          = "CIDR_BLOCK"
  icmp_options {
    type = 3
    code = 4
  }
}

# Allow worker nodes to communicate with OKE.
resource "oci_core_network_security_group_security_rule" "worker_egress_oci_services" {
  network_security_group_id = oci_core_network_security_group.k8s_worker_nsg.id
  description               = "Allow worker nodes to communicate with OCI services."
  direction                 = "EGRESS"
  protocol                  = "6" // TCP
  destination               = data.oci_core_services.all_services.services[0].cidr_block
  destination_type          = "SERVICE_CIDR_BLOCK"
}

# Kubernetes worker to Kubernetes API endpoint communication.
resource "oci_core_network_security_group_security_rule" "worker_egress_api" {
  network_security_group_id = oci_core_network_security_group.k8s_worker_nsg.id
  description               = "Allow worker nodes to communicate with the Kubernetes API endpoint."
  direction                 = "EGRESS"
  protocol                  = "6" // TCP
  destination               = oci_core_subnet.k8s_api_subnet.cidr_block
  destination_type          = "CIDR_BLOCK"
  tcp_options {
    destination_port_range {
      min = 6443
      max = 6443
    }
  }
}

# Kubernetes worker to Kubernetes API endpoint communication.
resource "oci_core_network_security_group_security_rule" "worker_egress_api_control_plane" {
  network_security_group_id = oci_core_network_security_group.k8s_worker_nsg.id
  description               = "Allow worker nodes to communicate with the Kubernetes API control plane."
  direction                 = "EGRESS"
  protocol                  = "6" // TCP
  destination               = oci_core_subnet.k8s_api_subnet.cidr_block
  destination_type          = "CIDR_BLOCK"
  tcp_options {
    destination_port_range {
      min = 12250
      max = 12250
    }
  }
}


/*
 * Security List Rules for Public Load Balancer Subnet
 */

# Load balancer listener protocol and port.
resource "oci_core_network_security_group_security_rule" "lb_ingress" {
  network_security_group_id = oci_core_network_security_group.k8s_lb_nsg.id
  description               = "Allow load balancer to communicate with worker nodes."
  direction                 = "INGRESS"
  protocol                  = "6" // TCP
  source                    = "0.0.0.0/0"
  source_type               = "CIDR_BLOCK"
  tcp_options {
    destination_port_range {
      min = 443
      max = 443
    }
  }
}

# Load balancer to worker nodes node ports.
resource "oci_core_network_security_group_security_rule" "lb_egress_worker_nodepool" {
  network_security_group_id = oci_core_network_security_group.k8s_lb_nsg.id
  description               = "Allow load balancer to communicate with worker node pool."
  direction                 = "EGRESS"
  protocol                  = "6" // TCP
  destination               = oci_core_subnet.k8s_worker_subnet.cidr_block
  destination_type          = "CIDR_BLOCK"
  tcp_options {
    destination_port_range {
      min = 30000
      max = 32767
    }
  }
}

# Allow load balancer to communicate with kube-proxy on worker nodes.
resource "oci_core_network_security_group_security_rule" "lb_egress_worker_nodepool_kube_proxy" {
  network_security_group_id = oci_core_network_security_group.k8s_lb_nsg.id
  description               = "Allow load balancer to communicate with kube-proxy on worker nodes."
  direction                 = "EGRESS"
  protocol                  = "6" // TCP
  destination               = oci_core_subnet.k8s_worker_subnet.cidr_block
  destination_type          = "CIDR_BLOCK"
  tcp_options {
    destination_port_range {
      min = 10256
      max = 10256
    }
  }
}

# Allow load balancer to communicate with pods.
resource "oci_core_network_security_group_security_rule" "lb_egress_pod" {
  network_security_group_id = oci_core_network_security_group.k8s_lb_nsg.id
  description               = "Allow load balancer to communicate with pods."
  direction                 = "EGRESS"
  protocol                  = "6" // TCP
  destination               = oci_core_subnet.k8s_pod_subnet.cidr_block
  destination_type          = "CIDR_BLOCK"
}


/*
 * Security List Rules for Private Pods Subnet
 */

# Allow worker nodes to access pods.
resource "oci_core_network_security_group_security_rule" "pod_ingress_worker" {
  network_security_group_id = oci_core_network_security_group.k8s_pod_nsg.id
  description               = "Allow worker nodes to access pods."
  direction                 = "INGRESS"
  protocol                  = "all"
  source                    = oci_core_subnet.k8s_worker_subnet.cidr_block
  source_type               = "CIDR_BLOCK"
}

# Allow Kubernetes API endpoint to communicate with pods.
resource "oci_core_network_security_group_security_rule" "pod_ingress_api" {
  network_security_group_id = oci_core_network_security_group.k8s_pod_nsg.id
  description               = "Allow Kubernetes API endpoint to communicate with pod nodes."
  direction                 = "INGRESS"
  protocol                  = "all"
  source                    = oci_core_subnet.k8s_api_subnet.cidr_block
  source_type               = "CIDR_BLOCK"
}

# Allow pods to communicate with other pods.
resource "oci_core_network_security_group_security_rule" "pod_ingress_pod" {
  network_security_group_id = oci_core_network_security_group.k8s_pod_nsg.id
  description               = "Allow pods to communicate with other pods."
  direction                 = "INGRESS"
  protocol                  = "all"
  source                    = oci_core_subnet.k8s_pod_subnet.cidr_block
  source_type               = "CIDR_BLOCK"
}

# Allow VPN to communicate with pods.
resource "oci_core_network_security_group_security_rule" "pod_ingress_vpn" {
  network_security_group_id = oci_core_network_security_group.k8s_pod_nsg.id
  description               = "Allow VPN to communicate with pods."
  direction                 = "INGRESS"
  protocol                  = "all"
  source                    = oci_core_subnet.vpn_subnet.cidr_block
  source_type               = "CIDR_BLOCK"
}

# Allow load balancer to communicate with pods.
resource "oci_core_network_security_group_security_rule" "pod_ingress_lb" {
  network_security_group_id = oci_core_network_security_group.k8s_pod_nsg.id
  description               = "Allow load balancer to communicate with pods."
  direction                 = "INGRESS"
  protocol                  = "6" // TCP
  source                    = oci_core_subnet.k8s_lb_subnet.cidr_block
  source_type               = "CIDR_BLOCK"
}

# Allow pods to communicate with other pods.
resource "oci_core_network_security_group_security_rule" "pod_egress_pod" {
  network_security_group_id = oci_core_network_security_group.k8s_worker_nsg.id
  direction                 = "EGRESS"
  protocol                  = "all"
  destination               = oci_core_subnet.k8s_pod_subnet.cidr_block
  destination_type          = "CIDR_BLOCK"
}

# Path Discovery.
resource "oci_core_network_security_group_security_rule" "pod_egress_path_discovery" {
  network_security_group_id = oci_core_network_security_group.k8s_worker_nsg.id
  direction                 = "EGRESS"
  protocol                  = "1" // ICMP
  destination               = data.oci_core_services.all_services.services[0].cidr_block
  destination_type          = "SERVICE_CIDR_BLOCK"
  icmp_options {
    type = 3
    code = 4
  }
}

# Allow pods to communicate with OCI services.
resource "oci_core_network_security_group_security_rule" "pod_egress_oci_services" {
  network_security_group_id = oci_core_network_security_group.k8s_pod_nsg.id
  direction                 = "EGRESS"
  protocol                  = "6" // TCP
  destination               = data.oci_core_services.all_services.services[0].cidr_block
  destination_type          = "SERVICE_CIDR_BLOCK"
}

# Allow pods to communicate with internet.
resource "oci_core_network_security_group_security_rule" "pod_egress_internet" {
  network_security_group_id = oci_core_network_security_group.k8s_pod_nsg.id
  direction                 = "EGRESS"
  protocol                  = "6" // TCP
  destination               = "0.0.0.0/0"
  destination_type          = "CIDR_BLOCK"
  tcp_options {
    destination_port_range {
      min = 443
      max = 443
    }
  }
}

# Pod to Kubernetes API endpoint communication
resource "oci_core_network_security_group_security_rule" "pod_egress_api" {
  network_security_group_id = oci_core_network_security_group.k8s_pod_nsg.id
  direction                 = "EGRESS"
  protocol                  = "6" // TCP
  destination               = oci_core_subnet.k8s_api_subnet.cidr_block
  destination_type          = "CIDR_BLOCK"
  tcp_options {
    destination_port_range {
      min = 6443
      max = 6443
    }
  }
}

# Pod to Kubernetes API endpoint communication
resource "oci_core_network_security_group_security_rule" "pod_egress_api_control_plane" {
  network_security_group_id = oci_core_network_security_group.k8s_pod_nsg.id
  direction                 = "EGRESS"
  protocol                  = "6" // TCP
  destination               = oci_core_subnet.k8s_api_subnet.cidr_block
  destination_type          = "CIDR_BLOCK"
  tcp_options {
    destination_port_range {
      min = 12250
      max = 12250
    }
  }
}

# Allow pods to communicate with other pods.
resource "oci_core_network_security_group_security_rule" "worker_egress_pod" {
  network_security_group_id = oci_core_network_security_group.k8s_worker_nsg.id
  direction                 = "EGRESS"
  protocol                  = "all"
  destination               = oci_core_subnet.k8s_pod_subnet.cidr_block
  destination_type          = "CIDR_BLOCK"
}


/*
 * Security List Rules for VPN Subnet
 */

resource "oci_core_network_security_group_security_rule" "vpn_ingress_https" {
  network_security_group_id = oci_core_network_security_group.vpn_nsg.id
  description               = "Allow HTTPS from anywhere"
  direction                 = "INGRESS"
  protocol                  = "6" // TCP
  source                    = "0.0.0.0/0"
  source_type               = "CIDR_BLOCK"
  tcp_options {
    destination_port_range {
      min = 443
      max = 443
    }
  }
}

resource "oci_core_network_security_group_security_rule" "vpn_ingress_ssh" {
  network_security_group_id = oci_core_network_security_group.vpn_nsg.id
  description               = "Allow SSH from anywhere"
  direction                 = "INGRESS"
  protocol                  = "6" // TCP
  source                    = "0.0.0.0/0"
  source_type               = "CIDR_BLOCK"
  tcp_options {
    destination_port_range {
      min = 22
      max = 22
    }
  }
}

resource "oci_core_network_security_group_security_rule" "vpn_ingress_openvpn" {
  network_security_group_id = oci_core_network_security_group.vpn_nsg.id
  description               = "Allow OpenVPN from anywhere"
  direction                 = "INGRESS"
  protocol                  = "17" // UDP
  source                    = "0.0.0.0/0"
  source_type               = "CIDR_BLOCK"
  udp_options {
    destination_port_range {
      min = 1194
      max = 1194
    }
  }
}

resource "oci_core_network_security_group_security_rule" "vpn_egress_all" {
  network_security_group_id = oci_core_network_security_group.vpn_nsg.id
  description               = "Allow all egress traffic"
  direction                 = "EGRESS"
  protocol                  = "all"
  destination               = "0.0.0.0/0"
  destination_type          = "CIDR_BLOCK"
}

output "vcn_id" {
  value = oci_core_vcn.k8s_vcn.id
}

output "subnet_ids" {
  value = {
    api    = oci_core_subnet.k8s_api_subnet.id
    worker = oci_core_subnet.k8s_worker_subnet.id
    lb     = oci_core_subnet.k8s_lb_subnet.id,
    pod    = oci_core_subnet.k8s_pod_subnet.id
    vpn    = oci_core_subnet.vpn_subnet.id
  }
}

output "nsg_ids" {
  value = {
    api    = oci_core_network_security_group.k8s_api_nsg.id
    worker = oci_core_network_security_group.k8s_worker_nsg.id
    lb     = oci_core_network_security_group.k8s_lb_nsg.id
    pod    = oci_core_network_security_group.k8s_pod_nsg.id
    vpn    = oci_core_network_security_group.vpn_nsg.id
  }
}
