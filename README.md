# Free Kubernetes Cluster in Oracle Cloud

Kubernetes setup on Oracle Cloud Infrastructure (OCI) using **Always Free** tier resources.

## What's Included

Default setup manages the following components:

- [**Kubernetes Cluster (OKE)**](https://docs.oracle.com/en-us/iaas/Content/ContEng/Concepts/contengoverview.htm) with 1 worker node
- [**Load Balancer**](https://docs.oracle.com/en-us/iaas/Content/Balance/Concepts/balanceoverview.htm) for ingress traffic management
- [**NAT Gateway**](https://docs.oracle.com/en-us/iaas/Content/Network/Tasks/NATgateway.htm) for outbound internet connectivity
- [**OpenVPN Instance**](https://openvpn.net/) for secure access to private Kubernetes API
- [**DNS Zones**](https://docs.oracle.com/en-us/iaas/Content/DNS/Concepts/dnszonemanagement.htm) for internal and external DNS management
- [**cert-manager**](http://cert-manager.io/) for automated TLS certificate management
- [**F5 NGINX Gateway Fabric**](https://docs.nginx.com/nginx-gateway-fabric) as a Kubernetes Gateway API implementation
- [**ExternalDNS**](https://github.com/kubernetes-sigs/external-dns) for automatic DNS record management for Kubernetes services

## Prerequisites

### Required Tools
- [Task](https://taskfile.dev/)
- [OpenTofu](https://opentofu.org/)
- [OCI CLI](https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/cliinstall.htm)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [OpenSSL](https://www.openssl.org/)
- [OpenVPN Client](https://openvpn.net/client/)

### OCI Account Requirements
- Active OCI account with appropriate permissions
- OCI CLI configured with authentication profile
- SSH key pair for VPN instance access

### OpenTofu Backend Configuration
Configure [OpenTofu backend](https://opentofu.org/docs/language/settings/backends/configuration/) for each module. See examples in `backend.tf.template`.

## Deployment Steps

### Step 1. Deploy Network Layer

```bash
task oci-platform:install-network
```

### Step 2. Deploy Identity Layer

```bash
task oci-platform:install-identity
```

### Step 3. Deploy OKE Cluster

```bash
task oci-platform:install-oke
```

### Step 4. Deploy DNS Module

```bash
task oci-platform:generate-keys
task oci-platform:install-dns
```

### Step 5. Deploy VPN

#### Option A: Manual Setup (Recommended First)

1. **Launch OpenVPN Instance from OCI Marketplace**
   - Follow the guide: https://openvpn.net/as-docs/oracle.html#oracle-vpn--cloud-vpn-quick-start-guide-from-openvpn
   - Use these parameters:
     - **Network Security Group:** `vpn_nsg`
     - **Subnet:** `vpn_subnet`
     - **Shape:** `VM.Standard.E2.1.Micro` (Always Free-eligible)

2. **Install OpenVPN Client**
   - Download and install from: https://openvpn.net/client/

3. **Configure OpenVPN Server Settings**
   
   Access the OpenVPN Admin UI and configure:
   
   **Routing Settings:**
   - Should VPN clients have access to private subnets?: **Yes**
   - Specify the private subnets to which all clients should be given access (one per line):
     - CIDR block of `k8s_pod_subnet`
     - CIDR block of `k8s_api_subnet`
     - CIDR block of `k8s_worker_subnet`
   - Should client Internet traffic be routed through the VPN?: **No**
   
   **DNS Settings:**
   - Do not alter clients' DNS server settings: **No**
   - Have clients use the same DNS servers as the Access Server host: **No**
   - Have clients use specific DNS servers: **Yes**
   - Primary DNS Server: `169.254.169.254`
   - Secondary DNS Server: `8.8.8.8`

4. **Connect to VPN**
   - Download the VPN profile from OpenVPN Access Server
   - Import the profile into OpenVPN Client
   - Connect to verify access to private subnets

#### Option B: Automated Deployment (If You Have Image OCID)

If you already know the OpenVPN image OCID and have added it to `05-vpn/terraform.tfvars`:

```bash
task oci-platform:install-vpn
```

After deployment, follow steps 2-4 from Option A to configure the OpenVPN server and connect.

### Step 6. Deploy Kubernetes Resources

**Important:** Before proceeding, ensure:
1. OpenVPN is connected and you have access to private subnets
2. Configure access to your OKE cluster following the guide: https://docs.oracle.com/en-us/iaas/Content/ContEng/Tasks/contengdownloadkubeconfigfile.htm

#### Step 6.1. Deploy cert-manager

```bash
task oci-platform:install-cert-manager
```

#### Step 6.2. Deploy NGINX Gateway

```bash
task oci-platform:install-nginx-gateway
```

#### Step 6.3. Deploy ExternalDNS

```bash
task oci-platform:install-external-dns
```

#### Step 6.4. Deploy External Secrets

```bash
task oci-platform:install-external-secrets
```

#### Step 6.5. Deploy GitLab Agent

```bash
task oci-platform:install-gitlab-agent
```