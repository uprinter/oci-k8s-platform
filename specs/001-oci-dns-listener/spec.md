---
title: "OCI VCN DNS listener — Product Specification"
feature: 001-oci-dns-listener
status: Draft
size: L
owner: product-owner
created: 2026-09-04
updated: 2026-09-04
source_request: "Provide a durable OCI-native DNS path for remote-access VPN clients."
target_repo_path: "specs/001-oci-dns-listener/spec.md"
---

# OCI VCN DNS listener

## 1. Problem

Remote-access VPN clients receive OCI's link-local VCN resolver address. Link-local addresses are valid from OCI VNICs but are not a durable routed destination on client operating systems; a client can later prefer a local-interface route and lose private-name resolution while its VPN tunnel remains connected.

The VCN needs a stable RFC1918 DNS listener that is reachable through the already-routed private subnet and accepts queries only from the VPN gateway.

## 2. Requirements

- **FR-1 [M] — Provide a routable private DNS listener.** The network stack creates one listening-only endpoint on the VCN's existing private IPv4 subnet. Its listening address is a required deployment input with no tracked default.
- **FR-2 [M] — Reuse the VCN resolver.** The endpoint belongs to the protected resolver automatically associated with the VCN; the resolver OCID is derived from the VCN rather than copied into configuration.
- **FR-3 [M] — Restrict DNS ingress to the VPN gateway.** A dedicated NSG permits stateful UDP and TCP destination port 53 only from VNICs in the existing VPN NSG. No public CIDR or whole-subnet DNS ingress is allowed.
- **FR-4 [M] — Preserve existing routing.** The listener uses a subnet already routed to VPN clients. No route table, subnet CIDR, security list, or existing NSG rule changes are introduced.
- **FR-5 [M] — Expose the listener address.** The network stack outputs the effective listening address for downstream VPN configuration and verification.
- **FR-6 [M] — Keep deployment-specific values untracked.** The real listener address is supplied through the ignored stack `terraform.tfvars` or an equivalent protected CI variable. Tracked files contain no environment-specific hostnames, domains, account identifiers, or real deployment values.

## 3. Acceptance criteria

- **AC-1.1 `[MUST-TEST]`** — Given the network configuration, `tofu validate` succeeds and a reviewed `tofu plan` proposes exactly one resolver endpoint, one dedicated NSG, and two DNS ingress rules, with no replacement or deletion of an existing resource. (FR-1, FR-2, FR-3)
- **AC-1.2 `[MUST-TEST]`** — The planned endpoint has `is_listening = true`, `is_forwarding = false`, `scope = "PRIVATE"`, uses the existing private IPv4 subnet, and receives its address from a required root-to-module input. (FR-1, FR-6)
- **AC-1.3 `[MUST-TEST]`** — The resolver ID comes from `oci_core_vcn_dns_resolver_association` for the managed VCN and is not a literal OCID. (FR-2)
- **AC-1.4 `[MUST-TEST]`** — The endpoint's NSG has one UDP/53 and one TCP/53 stateful ingress rule; both use `NETWORK_SECURITY_GROUP` source type and the VPN NSG as source. (FR-3)
- **AC-1.5 `[MUST-TEST]`** — The plan contains no route-table, subnet, security-list, or existing NSG-rule update. (FR-4)
- **AC-1.6 `[MUST-TEST]`** — The root network stack outputs the provider-reported listening address. (FR-5)
- **AC-1.7 `[MUST-TEST]`** — A repository sweep finds no supplied deployment value or identifying hostname, domain, tenancy ID, compartment ID, VCN ID, subnet ID, resolver ID, or NSG ID in tracked changes. (FR-6)
- **AC-1.8** — After a separately approved apply and VPN-server configuration, a reconnected VPN client routes the listener address through its tunnel and resolves a private name after a one-hour soak and a sleep/wake cycle. This live check is required before `/verify`, not before merge. (FR-1, FR-4)

## 4. Out of scope

- Applying the OpenTofu plan or changing live OCI resources in this feature's merge requests.
- Managing VPN appliance settings, credentials, connection profiles, or client software.
- Changing private DNS zones or records.
- Adding forwarding endpoints, resolver forwarding rules, a new subnet, or IPv6 DNS.
- Changing internet routing or sending general client traffic through the VPN.

## 5. Decisions

- **DEC-1 — Lane L.** The feature changes deployed network topology and therefore uses the full spec/plan/tasks/implementation/verify workflow.
- **DEC-2 — Existing private subnet.** Reusing an already-routed IPv4-only private subnet avoids a new subnet and client route while the dedicated NSG preserves isolation.
- **DEC-3 — NSG identity instead of an address allowlist.** Referencing the VPN NSG continues to identify the gateway after a compute-instance private address changes.
- **DEC-4 — TCP and UDP DNS.** UDP serves normal queries; TCP is required for standards-compliant fallback when responses are truncated or large.
- **DEC-5 — No endpoint charge.** OCI Private DNS is provided without additional service cost; the endpoint consumes one private address and a VNIC in the selected subnet.
