# Implementation Plan: Immich Zero Trust Access

**Branch**: `001-immich-zero-trust` | **Date**: 2026-01-04 | **Spec**: specs/001-immich-zero-trust/spec.md
**Input**: Feature specification from `specs/001-immich-zero-trust/spec.md`

## Summary

Add Immich as a new homelab service with NAS-backed storage and two access paths:

- External access via Cloudflare Tunnel + Cloudflare Access (Zero Trust), enforced at the origin by an in-cluster reverse proxy requiring the `Cf-Access-Jwt-Assertion` header and blocking uploads >100MB.
- Internal access (home LAN / UniFi VPN) via NodePort, using split-horizon DNS to reuse the same hostname but bypass Cloudflare.

All configuration is GitOps-managed by FluxCD and follows the repo’s existing patterns (no ingress controller, `hostPath` storage, no plaintext secrets).

## Technical Context

**Language/Version**: Kubernetes manifests (YAML) + Kustomize; FluxCD (current branch is `localdev-dhont-flux-linux`; confirm in `clusters/home/flux-system/gotk-sync.yaml`)  
**Primary Dependencies**: FluxCD, Kustomize, Kubernetes (apps via Deployments/Services), Cloudflare Tunnel (`cloudflared`)  
**Storage**: Host-mounted NAS (NFS) exposed to pods via `hostPath` (pattern used by Plex) + hostPath-backed state for DB/cache  
**Testing**: `kustomize build` validation; optional `kubectl apply --dry-run=server` in-cluster  
**Target Platform**: Bare-metal Ubuntu LTS host running Kubernetes (single-node assumed)  
**Project Type**: GitOps manifests (`clusters/home/**`, `apps/**`, `docs/**`)  
**Performance Goals**: N/A (home usage; prioritize reliability)  
**Constraints**: No plaintext secrets in Git; no ingress controller; minimal exposure; uploads >100MB must use LAN/VPN  
**Scale/Scope**: Single household; single owner; single-node scheduling and host-specific paths

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- GitOps-First: PASS (all cluster changes are manifests under `apps/` and referenced from `clusters/home/kustomization.yaml`).
- Ubuntu-First: PASS (NAS mount is host-managed; operational steps target Ubuntu).
- Workload Pinning: PASS (hostPath mounts require the specific node; document required host paths).
- Uptime Over HA: PASS (single replicas; simple components).
- Minimal Exposure/Storage/Secrets: PASS (NodePort for LAN; Cloudflare Tunnel for external; hostPath storage; secrets created out-of-band).

## Project Structure

### Documentation (this feature)

```text
specs/001-immich-zero-trust/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
apps/
├── media/
│   └── immich/
│       ├── deployment*.yaml
│       ├── service*.yaml
│       └── kustomization.yaml
└── networking/
    ├── immich-origin-proxy/
    │   ├── deployment.yaml
    │   ├── service.yaml
    │   ├── configmap.yaml
    │   └── kustomization.yaml
    └── cloudflared/
        ├── deployment.yaml
        ├── configmap.yaml
        ├── serviceaccount.yaml
        └── kustomization.yaml

clusters/
└── home/
    ├── kustomization.yaml              # add new resources
    └── networking/
        └── dns/README.md               # extend with split-horizon guidance

docs/
└── [optional additions]
```

**Structure Decision**: This is a Kubernetes/FluxCD GitOps change. New service manifests live under `apps/` and are wired into the cluster via `clusters/home/kustomization.yaml`.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

No constitution violations identified for this feature.

## Phase 0 — Research (output: research.md)

Research tasks to resolve design decisions and best practices:

- Cloudflare Access origin enforcement: require `Cf-Access-Jwt-Assertion` and block direct-origin access.
- Cloudflared in Kubernetes: token-based tunnel with credentials stored in a Kubernetes Secret (created out-of-band).
- Immich runtime components: minimal required services (server, machine-learning, redis, postgres) and storage directories.
- Repo alignment: no ingress controller; NodePort for LAN; hostPath storage consistent with Plex.

## Phase 1 — Design & Contracts

Deliverables:

- `data-model.md`: resources and operational entities (Immich components, storage locations, entrypoints).
- `contracts/*`: access/entrypoint contract describing what is exposed internally vs externally.
- `quickstart.md`: operator steps for tunnel, Cloudflare DNS/Access, UniFi DNS override, and LAN/VPN >100MB guidance.

## Constitution Re-check (post Phase 1)

- PASS: design keeps NodePort-only LAN access and avoids adding an ingress controller.
- PASS: storage uses hostPath + existing NAS mount as per repository model.
- PASS: tunnel token / any secrets are created out-of-band and not committed.

## Phase 2 — Execution Plan (for /speckit.tasks)

High-level implementation steps that `tasks.md` should break down:

1. Add Immich app manifests under `apps/media/immich/` (server + supporting services + volumes).
2. Add origin enforcement reverse proxy in front of Immich external entrypoint (header required; 100MB body limit).
3. Add Cloudflared manifests under `apps/networking/cloudflared/` (token secret out-of-band).
4. Wire new resources into `clusters/home/kustomization.yaml`.
5. Add/extend docs for Cloudflare Tunnel + Cloudflare DNS + UniFi DNS split-horizon + VPN upload guidance.
6. Add a “no private identifiers” validation step (repo search checklist).
