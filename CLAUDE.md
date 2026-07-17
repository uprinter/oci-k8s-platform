# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

OpenTofu (Terraform) IaC for a Kubernetes platform on Oracle Cloud Infrastructure (OKE), sized to fit OCI's Always Free tier. The deployment is split into numbered stacks (`01-network` … `12-origin-ca-issuer`) that must be applied **in order** — each later stack consumes OCIDs produced by earlier ones via `terraform.tfvars`.

## This repository is PUBLIC

This repo is published on GitHub. **Never put domain names, hostnames, project names, or other identifying values as defaults or in comments in any tracked file** (`*.tf`, `*.md`, `*.yaml`). Declare such values as required variables with **no default** and supply them only through each stack's gitignored `terraform.tfvars`. When you add a variable whose value is domain- or environment-specific, give it no default and describe it generically. Before finishing any change, sweep the working tree for identifying strings. (A domain leaked into tracked variable defaults once; it was caught pre-commit — keep it that way.)

## Common commands

All operations are driven through `Taskfile.yaml` using [Task](https://taskfile.dev/). The tasks `cd` into the correct numbered directory and run `tofu init && tofu apply` with the right variables.

```bash
task --list                                       # all tasks
task oci:login                                    # OCI session auth (run first)
task oci-platform:generate-dns-keys               # creates .keys/dns/* (consumed by 02 & 08 & 09)
task oci-platform:generate-ssh-keys               # creates .keys/ssh/* (consumed by 03-oke)
task oci-platform:install-network                 # Step 1
task oci-platform:install-identity                # Step 2 (injects DNS public key)
task oci-platform:install-oke                     # Step 3 (injects SSH public key)
task oci-platform:install-dns                     # Step 4
task oci-platform:install-vpn                     # Step 5 (optional — see README for manual path)
task oci-platform:install-cert-manager            # Step 6.1 — requires VPN + kubeconfig
task oci-platform:install-nginx-gateway           # Step 6.2
task oci-platform:install-external-dns            # Step 6.3 (injects DNS private key + fingerprint)
task oci-platform:install-external-secrets        # Step 6.4 (two-phase apply — see below)
task oci-platform:install-gitlab-agent            # Step 6.5
task oci-platform:install-filesystem-storage-class # Step 6.6
```

Direct OpenTofu use inside a stack:
```bash
cd 03-oke
tofu init
tofu plan -var="ssh_public_key=$(cat ../.keys/ssh/ssh_public.key)"
tofu apply -var="ssh_public_key=$(cat ../.keys/ssh/ssh_public.key)"
tofu state list
tofu destroy ...                                  # use the matching task var-injection
```

There are no tests, linters, or build steps — this is pure IaC.

## Architecture

**Two-layer pattern.** Each numbered top-level directory (`NN-name/`) is a thin **stack** (root module): provider config, a single `module` call into `modules/<name>/`, plus `variables.tf` / `terraform.tfvars` / `backend.tf` / `main.tf`. The reusable logic lives in `modules/<name>/main.tf`. To change behavior, edit the module; to change wiring between stacks, edit the stack.

**State per stack.** Every stack has its own `backend.tf` and its own remote state. Stacks do **not** use `terraform_remote_state` — instead, outputs from earlier stacks (VCN ID, subnet IDs, NSG IDs, vault OCID, etc.) are copy-pasted into the next stack's `terraform.tfvars`. After applying `01-network`, take its `vcn_id` / `subnet_ids` / `nsg_ids` outputs and paste them into `03-oke/terraform.tfvars`, `05-vpn/terraform.tfvars`, `11-filesystem-storage-class/terraform.tfvars`, etc.

**Dependency order (do not reorder):**
1. `01-network` — VCN, subnets (worker, api, lb, pod, vpn, fss_mount_target), NSGs, gateways
2. `02-identity` — compartments, dynamic groups, IAM policies, including the DNS user that consumes the public key from `.keys/dns/`
3. `03-oke` — OKE cluster + node pool + KMS vault for external-secrets; outputs `oke_external_secrets_vault_ocid`
4. `04-dns` — OCI DNS zones
5. `05-vpn` — OpenVPN instance (optional automated path; the manual marketplace path in README is the default)
6. `06-cert-manager` → `07-nginx-gateway` → `08-external-dns` → `09-external-secrets` → `10-gitlab-agent` → `11-filesystem-storage-class` → `12-origin-ca-issuer` — Helm/Kubernetes workloads applied via the Helm + kubernetes Terraform providers (require kubeconfig + VPN reachability to the private API endpoint). `12-origin-ca-issuer` is optional and depends on `07` (writes the origin cert Secret into the gateway namespace) and `09` (reads the Cloudflare Origin CA token from OCI Vault via the `oci-secret-store` ClusterSecretStore).

**Secret handling.** `.gitignore` excludes `*.tfvars`, `backend.tf`, `.keys/`, and `*.tfstate*`. That means:
- `terraform.tfvars` and `backend.tf` in each stack are local-only and contain real OCIDs / GitLab tokens / etc. Never commit them. `backend.tf.template` shows the supported backend shapes.
- DNS API keys and SSH keys live in `.keys/dns/` and `.keys/ssh/` and are injected at apply time via `-var=` from the Taskfile — never baked into tfvars.
- When adding a new stack, also create its own `backend.tf` (gitignored) and `terraform.tfvars` (gitignored).

**Two-phase apply for `09-external-secrets`.** The Taskfile first runs `tofu apply -exclude="module.external-secrets.kubernetes_manifest.oci_secret_store"` and then a second unrestricted `tofu apply`. This is intentional: the `ClusterSecretStore` CRD doesn't exist until the External Secrets Operator chart is installed, so the manifest must be applied on a second pass. Preserve this pattern when editing that task.

**Two-phase apply for `12-origin-ca-issuer`.** Same pattern, same reason. The Cloudflare origin-ca-issuer Helm chart does not ship its CRDs, and the `ClusterOriginIssuer`/`Certificate`/`ExternalSecret` custom resources can't be planned until their CRDs exist. `task oci-platform:install-origin-ca-issuer` first runs `tofu apply` with `-exclude` on `module.origin-ca-issuer.kubernetes_manifest.{origin_ca_token,cluster_origin_issuer,origin_certificate}` (installs namespace + CRDs + chart), then a second unrestricted `tofu apply` (creates the CRs). Preserve this two-pass structure when editing that task. Note: `modules/origin-ca-issuer` uses `data "http"` (needs the `hashicorp/http` provider, already wired into `12-origin-ca-issuer`) to fetch the issuer CRDs at plan time. `modules/network`'s shared Load Balancer NSG deliberately keeps its world-open `:443` ingress rule — a Cloudflare-only firewall lockdown was considered and not adopted, for LB flexibility (founder decision, 2026-07-18).

**Filesystem storage stack (`11`).** Creates a single shared FSS mount target up front and passes its OCID into the `StorageClass` so dynamically provisioned PVCs reuse it instead of spawning new mount targets per PVC. Requires the `oke-fss-csi-policy` from `02-identity` (re-apply `02-identity` if upgrading from an older state) and `mount_target_subnet_ocid` set to the `subnet_ids.fss_mount_target` output from `01-network`.

**Provider auth.** All OCI providers use `auth = "SecurityToken"` with `config_file_profile = "DEFAULT"` — run `task oci:login` (`oci session authenticate`) before any apply. Region defaults to `eu-frankfurt-1` in `terraform.tfvars`.

**Helm values & manifests.** `helm-values/` and `k8s-manifests/` exist but are currently empty — Helm chart values are inlined inside the relevant `modules/<name>/main.tf` files.
