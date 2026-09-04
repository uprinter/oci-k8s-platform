---
title: "OCI VCN DNS listener — Tasks"
feature: 001-oci-dns-listener
status: Draft
size: L
owner: team-lead-coordinator
created: 2026-09-04
updated: 2026-09-04
spec: "specs/001-oci-dns-listener/spec.md"
plan: "specs/001-oci-dns-listener/plan.md"
---

# OCI VCN DNS listener tasks

| ID | Task | Owner | Depends on | Status |
|---|---|---|---|---|
| T1 | Author `spec.md`, `plan.md`, and this task graph; establish SDD in `CLAUDE.md` | product-owner / lead-system-architect / team-lead-coordinator | — | Done |
| T2 | Obtain independent infrastructure review of the governing-documents MR and merge it | second devops-infra-expert / human | T1 | Pending |
| T3 | Add root/module input plumbing, resolver association lookup, listener NSG and rules, endpoint, and output | devops-infra-expert | T2 | Blocked |
| T4 | Add `deploy.md` with plan evidence, approval boundary, rollout, verification, and rollback | devops-infra-expert | T2 | Blocked |
| T5 | Run formatting, validation, public-repository hygiene sweep, and reviewed OpenTofu plan | devops-infra-expert | T3, T4 | Blocked |
| T6 | Obtain independent Tier-2 infrastructure review and attestation for the implementation MR | second devops-infra-expert | T5 | Blocked |
| T7 | Merge the SHA-pinned implementation MR; do not apply infrastructure as part of merge | devops-infra-expert / human | T6 | Blocked |
| T8 | Generate a fresh plan from the merged commit and obtain explicit approval for the exact apply command | devops-infra-expert / human | T7 | Blocked |
| T9 | Apply the reviewed network plan and confirm the endpoint is active | devops-infra-expert / human | T8 | Blocked |
| T10 | Repoint the VPN appliance through a separately governed configuration-as-code change | devops-infra-expert / human | T9 | Blocked |
| T11 | Verify client routing, private-name resolution, one-hour soak, and sleep/wake behavior; append `/verify` evidence | team-lead-coordinator | T10 | Blocked |

## Review classification

The implementation MR is Tier 2 because it changes live network infrastructure and the DNS path for all VPN clients. The governing-documents MR is Tier 0 documentation/process work, but it still requires a second instance and may not be self-reviewed.
