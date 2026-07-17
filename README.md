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
- [**Cloudflare Origin CA issuer**](https://github.com/cloudflare/origin-ca-issuer) (optional) for issuing origin certificates to hosts served behind Cloudflare's proxy

## ⚠️ This repository is PUBLIC

This repo is published on GitHub. **No domain names, hostnames, project names, or other identifying values may appear as defaults or in comments in any tracked file** (`*.tf`, `*.md`, `*.yaml`). Such values are declared as required variables with **no default** and supplied only through each stack's gitignored `terraform.tfvars`. When adding a variable whose value is environment- or domain-specific, give it no default and document it generically — never bake the real value into tracked code.

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
task oci-platform:generate-ssh-keys
task oci-platform:install-oke
```

### Step 4. Deploy DNS Module

```bash
task oci-platform:generate-dns-keys
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

#### Step 6.6. Deploy OCI File Storage StorageClass

```bash
task oci-platform:install-filesystem-storage-class
```

This creates a Kubernetes `StorageClass` backed by the OCI File Storage CSI driver (`fss.csi.oraclecloud.com`).

Before applying it:

- Ensure the Step 2 identity layer has been reapplied so the new `oke-fss-csi-policy` exists.
- In `11-filesystem-storage-class/terraform.tfvars`, set `mount_target_subnet_ocid` to the dedicated `subnet_ids.fss_mount_target` output from `01-network`.
- This stack now creates one shared mount target up front and passes its `mountTargetOcid` into the StorageClass, so dynamically provisioned PVCs reuse the same mount target instead of creating new ones.
- Configure the File Storage network security rules for the worker nodes and mount target as described in Oracle's manual: https://docs.oracle.com/en-us/iaas/Content/ContEng/Tasks/contengcreatingpersistentvolumeclaim_Provisioning_PVCs_on_FSS.htm

#### Step 6.7. Deploy Cloudflare Origin CA Issuer (optional)

```bash
task oci-platform:install-origin-ca-issuer
```

Installs the [Cloudflare Origin CA issuer](https://github.com/cloudflare/origin-ca-issuer) and issues an origin certificate for a host served behind Cloudflare's proxy (Full/strict SSL). Use this when a public hostname on the shared Load Balancer is fronted by Cloudflare rather than getting a public Let's Encrypt certificate directly.

Depends on Steps 6.2 (NGINX Gateway) and 6.4 (External Secrets): the origin certificate's Secret is written into the gateway namespace, and the scoped Cloudflare Origin CA API token is pulled from OCI Vault through the existing `oci-secret-store` `ClusterSecretStore`.

**Two-phase apply.** Like External Secrets (Step 6.4), the task runs `tofu apply` twice: the first pass (with `-exclude` on the `ExternalSecret`, `ClusterOriginIssuer`, and `Certificate`) installs the namespace, the issuer CRDs, and the Helm chart; the second unrestricted pass creates the custom resources once their CRDs exist. Run it via the task above — do not run a single `tofu apply`.

Before applying it:

- Create `12-origin-ca-issuer/terraform.tfvars` (gitignored) and set the required variables — notably the name of the OCI Vault secret holding the scoped Origin CA token, the origin certificate's Secret name (must match the name the gateway listener expects, `replace(host, ".", "-") + "-cert"`), and its SANs. None of these have defaults, by design (see the public-repo rule above).
- The origin certificate is intentionally named identically to its target Secret and carries no owner reference, so cert-manager's Gateway shim detects it and does not issue a competing certificate for the same listener.

> The shared Load Balancer NSG (`modules/network`) intentionally keeps its world-open `:443` ingress rule — a Cloudflare-only firewall lockdown was considered and deliberately not adopted, to keep the LB flexible for non-Cloudflare-fronted traffic. The origin is reachable directly, not only through Cloudflare's proxy; that tradeoff is a conscious choice, not an oversight.
