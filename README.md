# Free Kubernetes Cluster in Oracle Cloud

Kubernetes setup on Oracle Cloud Infrastructure (OCI) using **Always Free** tier resources.

## Why

I wanted to run my side projects in production without paying for a cloud. So I built the platform the way I build them at work: every layer as code, the Kubernetes API reachable only through VPN, TLS and DNS handled by the cluster itself. My personal site and side projects run on it today. An AI agent team maintains it, and every change goes through a reviewed merge request.

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
- [**Cloud Guard**](https://docs.oracle.com/iaas/cloud-guard/using/part-start.htm) in detect-only mode with email notifications
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
task oci-platform:generate-user-keys
task oci-platform:install-identity
```

`generate-user-keys` creates one API key pair for the `external-dns` user and one for the `external-secrets` user in `.keys/next/<user>/`. It creates only the pairs that are missing. It never overwrites a private key that exists.

#### Upgrade from the shared API key

Earlier versions gave the two users one shared API key from `.keys/oci/`. If you apply Step 2 with this version, OpenTofu deletes the shared key and creates the new keys in one apply. ExternalDNS and External Secrets then cannot authenticate until you apply Steps 6.3 and 6.4 again. To prevent this interruption, do these steps in this sequence:

1. Run `task oci-platform:generate-user-keys`.
2. Create only the new keys. The shared key stays in place:

   ```bash
   cd 02-identity
   export TF_VAR_external_dns_next_public_key="$(cat ../.keys/next/external-dns/public.pem)"
   export TF_VAR_external_secrets_next_public_key="$(cat ../.keys/next/external-secrets/public.pem)"
   tofu apply \
     -var="ci_terraform_public_key=$(cat ../.keys/ci/ci-terraform_public.pem)" \
     -target='module.identity.oci_identity_domains_api_key.external_dns_api_key_next' \
     -target='module.identity.oci_identity_domains_api_key.external_secrets_api_key_next'
   ```

3. Run `task oci-platform:install-external-dns` and `task oci-platform:install-external-secrets`.
4. Restart ExternalDNS. ExternalDNS reads its configuration only when it starts. Replace `<namespace>` with the ExternalDNS namespace (the default is `external-dns`):

   ```bash
   kubectl -n <namespace> rollout restart deployment/external-dns
   kubectl -n <namespace> rollout status deployment/external-dns
   ```

5. Make sure that all ExternalSecrets are `Ready` and that the ExternalDNS log shows no authentication error.
6. Run `task oci-platform:install-identity`. The plan must show only the deletion of the two `external_dns_api_key` and `external_secrets_api_key` resources.

A deleted API key cannot be restored. If a step fails, keep the shared key and repeat the step.

#### ExternalDNS and External Secrets policies

By default, Step 2 gives the two technical users these rights:

- `external-dns-policy`: `read dns-zones` and `manage dns`.
- `external-secrets-policy`: `use vaults`, `manage keys` and `manage secret-family`.

These rights also let the users write secrets back to the vault, manage keys, and manage DNS zones and views.

To grant only the rights that the documented operations need, set `least_privilege_dns_and_secrets_policies = true` in `02-identity/terraform.tfvars` and apply Step 2 again. The policies then contain these rights:

- `external-dns-policy`: `use dns-zones` and `manage dns-records`.
- `external-secrets-policy`: `read vaults` and `read secret-bundles`.

The narrow set supports these operations:

- ExternalDNS creates, updates and deletes records through `ListZones`, `GetZoneRecords` and `PatchZoneRecords`.
- External Secrets reads named secrets through `GetSecretBundleByName` and `GetVault`. This access is read-only.

The narrow set does not support these operations:

- `PushSecret` or any other write of secrets back to the vault.
- Key management (the old `manage keys` right).
- `dataFrom.find` (looking up secrets by name or tag through `ListSecrets`).
- Management of DNS zones, views or other DNS resource types by ExternalDNS.

Set the flag to `true` only if you do not use these operations.

The Oracle IAM policy reference gives these permissions: `PatchZoneRecords` needs `DNS_ZONE_UPDATE` and `DNS_RECORD_UPDATE`, which `use dns-zones` and `manage dns-records` grant. `GetSecretBundleByName` needs `SECRET_BUNDLE_READ` and `GetVault` needs `VAULT_READ`, which `read secret-bundles` and `read vaults` grant.

The flag does not change the apply order. The default is `false`, so an existing deployment shows no plan change. To roll back, set the flag to `false` and apply Step 2 again.

### Step 3. Deploy OKE Cluster

```bash
task oci-platform:generate-ssh-keys
task oci-platform:install-oke
```

### Step 4. Deploy DNS Module

```bash
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

> By default, the shared Load Balancer accepts TCP 443 from all sources, so the origin is also reachable directly and not only through Cloudflare's proxy. To accept traffic only from Cloudflare, see [Restrict the Load Balancer to Cloudflare (optional)](#restrict-the-load-balancer-to-cloudflare-optional).

#### Step 6.8. Deploy OCI Block Volume StorageClass

```bash
task oci-platform:install-block-storage-class
```

Creates a Kubernetes `StorageClass` backed by the OCI Block Volume CSI driver (`blockvolume.csi.oraclecloud.com`) with `reclaimPolicy: Retain`, and annotates it as the cluster default so that a PVC created without an explicit `storageClassName` gets a volume that survives PVC deletion.

Notes:

- A `StorageClass`'s `reclaimPolicy` is immutable and is read only at provisioning time. Changing it therefore requires a new class (or a delete-and-recreate), and it has no effect on already-provisioned `PersistentVolume`s — those carry their own copy of the field.
- The block volume class shipped by the managed control plane is left in place, untouched, as the explicit opt-in for genuinely disposable volumes. This stack only patches its `storageclass.kubernetes.io/is-default-class` annotation to `false` via `demote_storage_class_name`, so the cluster has exactly one default class.
- The control plane's CSI addon may reconcile that annotation back. After applying, verify with `kubectl get sc` that exactly one class is marked `(default)`, and re-check after cluster or addon upgrades.
- Destroying this stack restores the demoted class's default-class annotation instead of just dropping the key, so a teardown does not leave the cluster with no default class. That restore shells out to `kubectl`, so `kubectl` must be on `PATH` and `k8s_context` must name a reachable context at destroy time.

#### Step 6.9. Deploy metrics-server

```bash
task oci-platform:install-metrics-server
```

Installs metrics-server into `kube-system`, which registers the `metrics.k8s.io` aggregated API. OKE does not ship it, so without this stack `kubectl top node` / `kubectl top pods` fail with `Metrics API not available`, and any `HorizontalPodAutoscaler` cannot read CPU or memory.

Notes:

- Runs with `--kubelet-insecure-tls`. OKE kubelets serve a node-local self-signed certificate rather than one issued by the cluster CA (`serverTLSBootstrap` is off and no kubelet-serving CSRs are issued), so there is nothing for metrics-server to verify the kubelet against; without the flag every scrape fails with `x509: certificate signed by unknown authority`.
- The chart's default `--kubelet-preferred-address-types` already prefers `InternalIP`, which is what OKE nodes publish, so no override is needed.
- The container has a memory limit but deliberately no CPU limit — CPU throttling stalls the scrape loop and leaves gaps in the reported metrics.
- Metrics are in-memory and short-lived; this provides live utilization only, not historical trend data. A restart resets it, and it is not a substitute for Prometheus.

### Pod Security Admission labels (optional)

Stacks `06-cert-manager`, `07-nginx-gateway`, `08-external-dns`, `09-external-secrets` and `12-origin-ca-issuer` accept the variable `pod_security_labels` (map of strings, default `{}`). With the default, no label is set and a plan shows no change.

To enforce a Pod Security Standard on a namespace, set the labels in the tfvars of the stack, for example:

```hcl
pod_security_labels = {
  "pod-security.kubernetes.io/enforce" = "baseline"
  "pod-security.kubernetes.io/warn"    = "restricted"
  "pod-security.kubernetes.io/audit"   = "restricted"
}
```

Notes:

- Four stacks put the labels in the namespace resource, so the change is an in-place update. `07-nginx-gateway` uses a `kubernetes_labels` resource because Helm creates its namespace; Terraform patches the labels and does not own the namespace.
- A label change does not restart or evict running pods. The `enforce` level applies only when a pod is created.
- Before you set `enforce`, check that every pod template in the namespace passes the level. Build a Pod from each workload template and run `kubectl create --dry-run=server -f -` in a namespace that has the label. A label dry-run (`kubectl label --dry-run=server`) only warns about existing pods and does not show pods that CI or a controller creates later.
- To roll back, set the variable to `{}` and apply the stack.

### Step 7. Enable Cloud Guard (detect-only)

Cloud Guard needs the `cloud-guard-policy` from Step 2. Step 2 does not create this policy by default. This step does not need the VPN or kubeconfig.

1. Set `create_cloud_guard_policy = true` in `02-identity/terraform.tfvars` and apply Step 2 again (`task oci-platform:install-identity`). Do this before you apply `15-cloud-guard`.
2. Create `15-cloud-guard/backend.tf` (gitignored).
3. Create `15-cloud-guard/terraform.tfvars` (gitignored) and set these variables:
   - `root_compartment_id`: the tenancy OCID.
   - `region` and `reporting_region`: set both to the same region.
   - `notification_email`: the address that receives the alerts. This variable is sensitive and has no default. Do not put the address in a tracked file.
   - `min_risk_levels` (optional): the default is `["CRITICAL", "HIGH"]`. An empty list sends every problem.
4. Run the task:

   ```bash
   task oci-platform:install-cloud-guard
   ```

5. Open the email from OCI Notifications and click the confirmation link. Until you confirm, the subscription stays pending and no alert is sent.

What this step creates:

- The Cloud Guard configuration, with status `ENABLED`.
- A target on the root compartment with the Oracle-managed Configuration, Activity and Threat detector recipes.
- A clone of the Oracle responder recipe. All rules are disabled except `EVENT`, so Cloud Guard reports problems and changes no resource.
- A Notifications topic with one email subscription, and an Events rule that sends detected problems to the topic.

> **Rollback:** `tofu destroy` does not disable Cloud Guard, because the provider's delete for the configuration resource makes no API call. Cloud Guard stays `ENABLED`. To disable it, set `status = "DISABLED"` in `modules/cloud-guard/main.tf` and apply the stack.

### Step 8. Back up block volumes (optional)

This step creates a user-defined backup policy and assigns it to the block volumes that you list. The policy makes an incremental backup each Sunday at 03:00 UTC and keeps it for 13 days, so each volume has two backups at most. This step does not need the VPN or kubeconfig.

1. Get the OCIDs of the volumes. For a volume that a PVC provisioned, the OCID is the `volumeHandle` of its PersistentVolume.
2. Create `16-volume-backup/backend.tf` (gitignored).
3. Create `16-volume-backup/terraform.tfvars` (gitignored) and set these variables:
   - `region`: the region of the volumes.
   - `compartment_id`: the compartment for the policy.
   - `volume_ids`: a map from a label to a volume OCID. Do not put the OCIDs in a tracked file.
   - `day_of_week`, `hour_of_day` and `retention_days` (optional): the defaults are `SUNDAY`, `3` and `13`.
4. Run the task:

   ```bash
   task oci-platform:install-volume-backup
   ```

> **Note:** A new PVC gets a new volume with a new OCID. When you recreate a PVC, update `volume_ids` and apply this step again.

> **Rollback:** `tofu destroy` removes the policy and its assignments. Backups that exist stay until their retention ends.

## Restrict the Load Balancer to Cloudflare (optional)

By default, the shared Load Balancer accepts TCP 443 from all sources. If all your public hostnames are proxied through Cloudflare, you can accept traffic only from Cloudflare's IPv4 ranges. Two settings do this, and you must set both:

- `lb_ingress_source_cidrs` in `01-network/terraform.tfvars`: the CIDRs that can reach the Load Balancer on TCP 443. When the list does not contain `0.0.0.0/0`, `modules/network` also adopts the VCN default security list and keeps only the rules from the Load Balancer subnet to the worker node ports. This removes all other rules from that list, including the world-open rules that the cloud controller manager wrote.
- `disable_lb_security_rule_management = true` in `07-nginx-gateway/terraform.tfvars`: the external Gateway gets the annotation `oci.oraclecloud.com/security-rule-management-mode: "None"`, so the cloud controller manager does not write security rules for the Load Balancer.

Example for `01-network/terraform.tfvars`, with the IPv4 ranges that Cloudflare published at the time of writing:

```hcl
lb_ingress_source_cidrs = [
  "173.245.48.0/20",
  "103.21.244.0/22",
  "103.22.200.0/22",
  "103.31.4.0/22",
  "141.101.64.0/18",
  "108.162.192.0/18",
  "190.93.240.0/20",
  "188.114.96.0/20",
  "197.234.240.0/22",
  "198.41.128.0/17",
  "162.158.0.0/15",
  "104.16.0.0/13",
  "104.24.0.0/14",
  "172.64.0.0/13",
  "131.0.72.0/22",
]
```

Procedure:

1. Get the current list from `https://api.cloudflare.com/client/v4/ips` (field `result.ipv4_cidrs`) and compare it with your list.
2. Apply `07-nginx-gateway` first (`task oci-platform:install-nginx-gateway`). If you apply `01-network` first, the cloud controller manager can write a world-open rule again before the annotation is live.
3. Apply `01-network` (`task oci-platform:install-network`).
4. When Cloudflare publishes new ranges, update the list and apply `01-network` again. Traffic from a range that is not in the list cannot reach the Load Balancer.

> A hostname that is not proxied through Cloudflare cannot reach the Load Balancer after this change. To go back, remove both settings, apply `01-network`, and then apply `07-nginx-gateway`.
