---
title: "OCI VCN DNS listener — Deployment Record"
feature: 001-oci-dns-listener
status: Active
size: L
owner: devops-infra-expert
created: 2026-09-05
updated: 2026-09-05
spec: "specs/001-oci-dns-listener/spec.md"
plan: "specs/001-oci-dns-listener/plan.md"
---

# OCI VCN DNS listener deployment record

## 1. Implemented topology

- The root network stack requires `dns_listener_address`, passes it to the reusable network module, and exports the provider-reported listener address. (P-1)
- The network module derives the protected resolver associated with its managed VCN. (P-2)
- A dedicated resolver NSG permits stateful UDP/53 and TCP/53 ingress only from the existing VPN NSG. (P-3)
- A listening-only private resolver endpoint uses the existing private IPv4 worker subnet and attaches only the dedicated resolver NSG. (P-4)

The deployment-specific address remains outside tracked files and must be supplied through the ignored stack `terraform.tfvars` or a protected CI variable.

## 2. Pre-merge validation evidence

Validation was run from `01-network` on 2026-09-05 with OpenTofu 1.12.6 and OCI provider 7.26.1. The real deployment inputs and saved plan remained untracked.

```text
tofu validate: Success! The configuration is valid.
tofu plan: 4 to add, 0 to change, 0 to destroy.
```

The saved-plan JSON contains exactly these non-no-op actions:

| Resource | Action | Material properties |
|---|---|---|
| `oci_core_network_security_group.dns_resolver_nsg` | create | Dedicated NSG in the managed VCN |
| `oci_core_network_security_group_security_rule.dns_resolver_ingress_udp` | create | Ingress, UDP/53, stateful, VPN NSG source |
| `oci_core_network_security_group_security_rule.dns_resolver_ingress_tcp` | create | Ingress, TCP/53, stateful, VPN NSG source |
| `oci_dns_resolver_endpoint.vcn_listener` | create | Private, listening enabled, forwarding disabled, existing private subnet |

The plan contains no update, replacement, or deletion and no route-table, subnet, security-list, or existing NSG-rule change. The root output resolves to the supplied listener address. This satisfies AC-1.1 through AC-1.6.

A tracked-diff sweep must remain clean of the supplied address, internal names, and OCI identifiers before every push. This supplies AC-1.7 evidence.

## 3. Approval boundary

Merging the implementation does not deploy infrastructure. After merge, generate a fresh plan from the reviewed commit and present the exact `tofu apply` command, affected resources, blast radius, and rollback strategy for explicit human approval. Never apply an older saved plan or apply from an unreviewed working tree.

## 4. Rollout

1. Merge the independently reviewed implementation at the attested SHA.
2. Supply the listener address through ignored or protected deployment configuration.
3. Generate and review a fresh OpenTofu plan from the merged commit.
4. Obtain explicit approval for the exact apply command.
5. Apply the reviewed plan and confirm the endpoint reaches `ACTIVE` with the expected private address and resolver NSG.
6. Through a separate configuration-as-code change, repoint the VPN appliance to the new primary DNS server, remove the public secondary resolver, and scope private resolution to the intended internal zone.
7. Reconnect a client and complete the live verification below.

## 5. Live verification

AC-1.8 remains pending until both the approved network apply and the separate VPN configuration change are complete.

From the VPN appliance, query a known private name directly through the listener. From a reconnected client, confirm that the listener route uses the tunnel, the intended internal zone is scoped to the listener, and both direct and operating-system resolver queries succeed. Repeat after a one-hour soak and a sleep/wake cycle.

Record sanitized command results in the `/verify` evidence. Do not commit the listener address, internal names, client details, or OCI identifiers.

## 6. Blast radius and rollback

The network apply is additive: one endpoint, one NSG, and two rules. Existing traffic is unaffected until the VPN appliance is repointed. The appliance change affects DNS for all connected VPN clients and can require reconnection.

Rollback in reverse dependency order:

1. Repoint the VPN appliance away from the listener and verify clients no longer depend on it.
2. Revert the implementation commit through the normal reviewed Git workflow.
3. Generate and review the destroy plan produced by that revert.
4. Obtain explicit approval and apply it to remove the endpoint before its NSG and rules.

Deleting the endpoint while VPN clients still use it creates a DNS outage and is prohibited.
