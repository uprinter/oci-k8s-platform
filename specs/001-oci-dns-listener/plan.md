---
title: "OCI VCN DNS listener — Implementation Plan"
feature: 001-oci-dns-listener
status: Active
size: L
owner: lead-system-architect
created: 2026-09-04
updated: 2026-09-04
spec: "specs/001-oci-dns-listener/spec.md"
target_repo_path: "specs/001-oci-dns-listener/plan.md"
---

# OCI VCN DNS listener implementation plan

## 1. Architecture

The existing `01-network` stack remains the owner of the VCN, subnets, NSGs, and the new private resolver endpoint. The reusable `modules/network` module derives the VCN-created resolver through `oci_core_vcn_dns_resolver_association`, creates a dedicated listener NSG, and attaches that NSG to a listening-only `oci_dns_resolver_endpoint`.

The VPN gateway already NATs client traffic into the VCN and its NSG is the sole source identity accepted by the listener. The endpoint is placed in an existing routed private IPv4 subnet, so the data path is:

```text
VPN client -> VPN tunnel -> gateway NAT/VNIC (vpn_nsg) -> UDP/TCP 53 -> listener NSG -> VCN resolver
```

## 2. Code elements

### P-1 — Root-stack input and output

- Add required string variable `dns_listener_address` to `01-network/variables.tf`, with no default.
- Pass it to `module.network` in `01-network/main.tf`.
- Export `dns_listener_address` from the root using the module's provider-reported output.
- Supply the real address only in ignored `01-network/terraform.tfvars` or protected CI configuration.

Implements FR-5 and FR-6.

### P-2 — Resolver discovery

- Add `data "oci_core_vcn_dns_resolver_association"` in `modules/network/main.tf`.
- Set `vcn_id` from the managed VCN resource and use `dns_resolver_id` for the endpoint.

Implements FR-2.

### P-3 — Dedicated listener NSG

- Create `oci_core_network_security_group.dns_resolver_nsg` in the managed VCN.
- Create two stateful `oci_core_network_security_group_security_rule` resources:
  - protocol `17`, UDP destination port 53;
  - protocol `6`, TCP destination port 53.
- For both, set `source_type = "NETWORK_SECURITY_GROUP"` and source to `vpn_nsg.id`.
- Do not add egress rules: stateful ingress permits response traffic for established DNS exchanges.

Implements FR-3 and FR-4.

### P-4 — Listening resolver endpoint

- Create `oci_dns_resolver_endpoint.vcn_listener` with `is_listening = true`, `is_forwarding = false`, and `scope = "PRIVATE"`.
- Use the existing private IPv4 subnet and the P-1 input as `listening_address`.
- Attach only P-3's NSG.
- Export the endpoint's `listening_address` from the module.

Implements FR-1, FR-4, and FR-5.

### P-5 — Deployment record

The implementation MR adds `deploy.md` with the reviewed plan summary, approval boundary, rollout order, live verification, and rollback sequence. It must not contain the real address or internal names because the repository is public.

Implements AC-1.1 through AC-1.8 operational traceability.

## 3. Validation

Run from `01-network` without applying:

```bash
tofu fmt -check -recursive ..
tofu validate
tofu plan -out=<temporary-plan-path>
tofu show <temporary-plan-path>
```

The plan review must prove:

- only the four intended managed resources are added;
- existing resources have no changes or replacements;
- the endpoint is listening-only and private;
- the selected subnet is the existing private IPv4 subnet;
- both port-53 rules source the VPN NSG;
- no identifying deployment value is tracked.

The saved plan is temporary evidence only and must not be committed.

## 4. Rollout

1. Merge the independently reviewed implementation MR.
2. Generate and review a fresh plan against the merged commit.
3. Obtain explicit human approval for the exact `tofu apply` command.
4. Apply the reviewed network plan.
5. Confirm the endpoint reaches `ACTIVE` and reports the expected listening address and NSG.
6. In a separately governed configuration-as-code change, repoint the VPN appliance's primary DNS to the listener, remove any public secondary resolver, and set the intended private DNS resolution zone.
7. Reconnect clients and execute AC-1.8.

No merge request in this feature applies live infrastructure.

## 5. Blast radius and rollback

Creating the endpoint and NSG is additive and receives no traffic until a VPN appliance is configured to use it. The later VPN DNS switch affects all connected VPN clients and can interrupt resolution during reconnection.

Rollback order is the reverse dependency order: first repoint the VPN appliance away from the listener, then apply a reviewed revert of the OpenTofu change to delete the endpoint, its NSG rules, and its NSG. Deleting the endpoint first would leave clients pointing at an unavailable DNS address.

## 6. Security and cost

- The endpoint has no public address and accepts port 53 only from the VPN NSG.
- NSG identity avoids a brittle allowlist tied to an ephemeral gateway address.
- Deployment-specific values remain outside Git.
- OCI Private DNS has no additional service charge; the listener consumes one subnet address and one service-managed VNIC.
