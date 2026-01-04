<!--
Sync Impact Report

- Version change: TEMPLATE → 1.0.0
- Modified principles: TEMPLATE placeholders → Homelab GitOps principles (5)
- Added sections: None (filled existing template sections)
- Removed sections: None
- Templates requiring updates:
	- ✅ updated: .specify/templates/plan-template.md
	- ✅ updated: .specify/templates/spec-template.md (no change needed)
	- ✅ updated: .specify/templates/tasks-template.md (no change needed)
	- ⚠ pending: .specify/templates/commands/*.md (directory not present)
- Follow-up TODOs: None
-->

# Homelab (FluxCD) Constitution

## Core Principles

### I. GitOps-First (Flux Source of Truth)
All cluster configuration MUST be declared in Git and applied by Flux.

- Changes intended to affect the running cluster MUST be made in manifests under `clusters/home/` and `apps/` (or their referenced kustomizations).
- Manual `kubectl` changes MUST be treated as temporary incident response only and MUST be reconciled back into Git promptly.
- The branch/path Flux watches MUST be respected; do not assume the default branch is what the cluster reconciles.

### II. Ubuntu-First Operations (Windows Allowed, Not Primary)
The primary execution environment is a single bare-metal Ubuntu LTS host.

- Operational procedures MUST target Ubuntu LTS first.
- Some services MAY run on Windows when required, but the repo MUST NOT assume Windows is available for core cluster operations.
- Host-level updates (apt upgrades, kernel changes, reboots) MUST be explicit and controlled; no “auto-reboot” automation.

### III. Workload Pinning (No Cross-Server Scaling)
Workloads are configured for specific machines and workloads; horizontal scaling across homelab servers is not a goal.

- Apps and services MUST NOT assume interchangeable nodes or multi-node scheduling for correctness.
- Any placement constraints (node selectors, affinity, tolerations) MUST be explicit.
- When a workload requires a particular host path, device, GPU, or local storage, it MUST declare that requirement clearly.

### IV. Uptime Over HA (Simple, Recoverable)
High availability is not a requirement, but high uptime is preferred.

- Prefer designs that minimize moving parts and reduce operational fragility.
- Prefer “recoverable by reinstall + bootstrap” over complex HA topologies.
- Changes MUST include a reasonable rollback path (Git revert + Flux reconciliation).

### V. Minimal Exposure, Predictable Storage, No Plaintext Secrets
Networking and storage choices MUST remain consistent and low-risk.

- Networking MUST default to LAN access via NodePort services; do not introduce Ingress/cert-manager/Traefik unless explicitly requested.
- Storage MUST default to `hostPath`-backed directories/PVs and the documented NAS mount; new storage patterns require explicit justification.
- Secrets MUST NOT be committed in plaintext; prefer documented manual creation steps or an encrypted-secrets approach only when explicitly adopted.

## Operational Constraints

- **Target Platform**: Ubuntu LTS (bare metal) is the default target.
- **Cluster Management**: FluxCD + Kustomize reconcile desired state from Git.
- **Access Model**: No ingress by default; expose UIs using NodePort services on the LAN.
- **Storage Model**: Host-local paths and PVs backed by host paths; NAS content mounted on the host and bind-mounted into pods as needed.
- **Scaling/HA**: No requirement for high availability; do not design for cross-node scaling unless explicitly requested.
- **Safety**: Prefer changes that are easy to roll back; avoid destructive actions by default.

## Change Workflow & Quality Gates

- **GitOps Gate**: If the desired end state is “cluster behavior changes,” the change MUST be represented in Git under `clusters/` and/or `apps/`.
- **Reconciliation Awareness**: Every change intended to apply MUST be placed where Flux actually reconciles for the cluster.
- **Minimalism Gate**: Prefer the smallest manifest change that achieves the goal; avoid introducing new controllers or platform components without explicit request.
- **Secrets Gate**: Any change requiring secrets MUST include non-secret instructions (or an encrypted-secrets approach if adopted), never plaintext.
- **Docs Gate**: If a change affects host requirements (paths, mounts, ports, prerequisites), update runbooks/docs accordingly.

## Governance
<!-- Example: Constitution supersedes all other practices; Amendments require documentation, approval, migration plan -->

This constitution governs how changes are proposed, reviewed, and applied.

- **Supremacy**: This document supersedes other templates when conflicts exist.
- **Amendment Process**:
	- Amendments MUST update this file and increment the version.
	- Amendments MUST include a short rationale and any required migration/rollback notes.
- **Versioning Policy** (Semantic Versioning for governance):
	- **MAJOR**: Backward-incompatible governance changes (principle removals or redefinitions).
	- **MINOR**: New principle/section added or materially expanded mandatory guidance.
	- **PATCH**: Clarifications, wording tweaks, typo fixes, non-semantic refinements.
- **Compliance Review**: Any PR that changes `clusters/`, `apps/`, or `ansible/` MUST be checked against the Core Principles and the two gates sections.
- **Runtime Guidance**: Operational guidance lives in `README.md`, `docs/`, and `troubleshooting.md`.

**Version**: 1.0.0 | **Ratified**: 2026-01-04 | **Last Amended**: 2026-01-04
<!-- Example: Version: 2.1.1 | Ratified: 2025-06-13 | Last Amended: 2025-07-16 -->
