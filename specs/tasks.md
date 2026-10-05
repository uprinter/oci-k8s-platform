---
title: "XS-lane tasks"
status: Active
size: XS
owner: team-lead-coordinator
created: 2026-10-05
updated: 2026-10-05
---

# XS-lane tasks

Changes with no behavior change (documentation, comments, or a fix that leaves live infrastructure as it is) get one row here instead of a feature directory.

| ID | Task | Owner | Depends on | Status |
|---|---|---|---|---|
| XS-1 | Pin the cert-manager, nginx-gateway, external-dns, external-secrets and gitlab-agent Helm chart versions to the installed releases (#35) | devops-infra-expert | — | Done |
| XS-2 | Remove the two duplicate worker-to-pod NSG rule declarations from `modules/network`, keeping `worker_egress_to_pod`; drop the removed addresses from state with `tofu state rm` | devops-infra-expert | — | In review |
