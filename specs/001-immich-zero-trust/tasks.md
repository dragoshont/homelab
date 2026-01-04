---
description: "Task list for feature implementation"
---

# Tasks: Immich Zero Trust Access

**Input**: Design documents from `specs/001-immich-zero-trust/`

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create the repo structure and Kustomize entrypoints that Flux will reconcile.

- [x] T001 Create `apps/media/immich/kustomization.yaml` referencing `deployment.yaml`, `service.yaml`, and any supporting resources
- [x] T002 Create `apps/networking/immich-origin-proxy/kustomization.yaml` referencing `deployment.yaml`, `service.yaml`, and `configmap.yaml`
- [x] T003 Create `apps/networking/cloudflared/kustomization.yaml` referencing `deployment.yaml`, `serviceaccount.yaml`, and `configmap.yaml`


---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Decisions and shared wiring that block all story work.

- [x] T004 Decide and document fixed NodePorts for Immich internal access in `specs/001-immich-zero-trust/quickstart.md` (replace `IMMICH_NODEPORT` placeholder with an actual port in 30000-32767)
- [x] T005 Decide and document the Kubernetes namespace for all Immich resources (default vs dedicated) in `specs/001-immich-zero-trust/spec.md` and `specs/001-immich-zero-trust/quickstart.md`
- [x] T006 Define the placeholder conventions for NAS storage and the single supported method for supplying real `hostPath` values without committing them: a local-only Kustomize overlay/patch that replaces the placeholder hostPath strings (document in `specs/001-immich-zero-trust/spec.md` and `specs/001-immich-zero-trust/quickstart.md`).
- [x] T007 Add repo-level wiring for new apps in `clusters/home/kustomization.yaml` (resources for Immich, immich-origin-proxy, and cloudflared)

**Checkpoint**: Flux can reconcile new app directories (even if pods are not yet running).

---

## Phase 3: User Story 1 — Secure external access (Priority: P1) 🎯 MVP

**Goal**: External access is Cloudflare Access-gated, tunneled in-cluster, and enforced at origin (header required + >100MB blocked).

**Independent Test**: From off-LAN, browse the external hostname and verify Cloudflare Access gating; direct access to the origin proxy without `Cf-Access-Jwt-Assertion` returns 401; uploads >100MB return 413.

### Implementation for User Story 1

- [x] T008 [P] [US1] Create `apps/networking/immich-origin-proxy/configmap.yaml` with reverse-proxy config that (a) requires `Cf-Access-Jwt-Assertion` and (b) enforces a 100MB request body limit
- [x] T009 [P] [US1] Create `apps/networking/immich-origin-proxy/deployment.yaml` (replicas=1) mounting the proxy config and forwarding to the Immich service
- [x] T010 [P] [US1] Create `apps/networking/immich-origin-proxy/service.yaml` as `ClusterIP` exposing the proxy to `cloudflared`
- [x] T011 [P] [US1] Create `apps/networking/cloudflared/serviceaccount.yaml` for the `cloudflared` Deployment
- [x] T012 [P] [US1] Create `apps/networking/cloudflared/configmap.yaml` defining tunnel ingress rules mapping the external hostname to the immich-origin-proxy service (use placeholder hostname; do not commit real domain)
- [x] T013 [US1] Create `apps/networking/cloudflared/deployment.yaml` that reads the tunnel token/credentials from an out-of-band Kubernetes Secret (do not commit secrets)
- [x] T014 [US1] Update `specs/001-immich-zero-trust/quickstart.md` to include the exact Kubernetes Secret name/key expected by `apps/networking/cloudflared/deployment.yaml` and the `kubectl create secret` example command

---

## Phase 4: User Story 2 — NAS-backed iPhone backups (Priority: P2)

**Goal**: Immich stores its library and iPhone backups on NAS-backed hostPath mounts.

**Independent Test**: From LAN/VPN, run an iPhone backup and verify new assets appear on the NAS path(s) and are visible in Immich.

### Implementation for User Story 2

- [x] T015 [P] [US2] Create `apps/media/immich/deployment.yaml` for the Immich server container, with a NAS-backed library volume via `hostPath` (iPhone backups use the same Immich library folder; no additional backup path/config)
- [x] T016 [P] [US2] Create `apps/media/immich/deployment-postgres.yaml` for Postgres with persistent hostPath on internal drive (matching the Plex-style hostPath patterns)
- [x] T017 [P] [US2] Create `apps/media/immich/deployment-redis.yaml` for Redis (ephemeral unless persistence is explicitly required)
- [x] T018 [P] [US2] Create `apps/media/immich/deployment-machine-learning.yaml` for Immich ML (if required by the chosen Immich version)
- [x] T019 [US2] Create `apps/media/immich/service.yaml` exposing Immich via `NodePort` for internal LAN/VPN access
- [x] T020 [US2] Implement the “NAS must be mounted or do not write” safeguard by adding an initContainer or readiness gate in `apps/media/immich/deployment.yaml` that fails when NAS is not mounted/available (document the operator-visible failure signal)
- [x] T021 [US2] Update `specs/001-immich-zero-trust/quickstart.md` with the exact placeholder hostPath values used in manifests and the exact overlay/patch mechanism operators use to supply the real NAS mount path locally (not committed), plus operator prerequisites (mount stability + permissions)

### Optional (OIDC) — support Google login without committed secrets

- [ ] T022 [P] [US2] Create `apps/media/immich/overlays/oidc/kustomization.yaml` that composes the base Immich manifests plus an OIDC patch (overlay is not enabled by default)
- [ ] T023 [US2] Create `apps/media/immich/overlays/oidc/patch-oidc-env.yaml` adding the required Immich OIDC env vars and referencing an out-of-band Kubernetes Secret for the OIDC client secret
- [ ] T024 [US2] Update `specs/001-immich-zero-trust/quickstart.md` with OIDC enablement steps (overlay apply) and the expected secret name/keys (no secret values in Git)

---

## Phase 5: User Story 3 — Operate via GitOps with clear setup docs (Priority: P3)

**Goal**: Flux reconciles all manifests; operator docs cover Cloudflare Tunnel, Cloudflare DNS, UniFi split-horizon DNS, and large-upload LAN/VPN guidance.

**Independent Test**: A fresh operator can follow docs to configure DNS/tunnel and confirm external access is gated while internal access works without Cloudflare.

### Implementation for User Story 3

- [x] T025 [US3] Verify `clusters/home/kustomization.yaml` includes `../../apps/media/immich/`, `../../apps/networking/immich-origin-proxy/`, and `../../apps/networking/cloudflared/` (and that the paths match the actual directories)
- [x] T026 [US3] Update `clusters/home/networking/dns/README.md` with UniFi Dream Machine split-horizon DNS instructions aligned to this feature (same hostname, internal resolves to node IP)
- [x] T027 [US3] Update `specs/001-immich-zero-trust/quickstart.md` to reference the actual Service names and ports created in manifests (no placeholders for ports)
- [x] T028 [US3] Add a troubleshooting section to `troubleshooting.md` for Immich external vs internal path diagnosis (DNS resolution, Cloudflare Access challenge, tunnel health)
- [x] T029 [US3] Add a “no private identifiers/secrets” pre-commit operator check section to `docs/README.md` (use `git grep` examples; no private values committed)
- [x] T034 [US3] Update `specs/001-immich-zero-trust/quickstart.md` to include a concrete Cloudflare Access policy checklist (default-deny + allow owner identity/group) aligned to spec FR-003a
- [x] T035 [US3] Update `specs/001-immich-zero-trust/quickstart.md` with explicit bootstrap/admin steps (OIDC admin path vs bootstrap admin secret path) aligned to spec FR-008c
- [x] T036 [US3] Re-validate and, if needed, adjust `specs/001-immich-zero-trust/quickstart.md` sections “TLS expectations” and “Logging/audit expectations” to match the final manifests (spec FR-010, FR-012)
- [x] T037 [US3] Add a brief “single-node + hostPath scheduling note” to `specs/001-immich-zero-trust/quickstart.md` describing the assumption and what to do if the cluster becomes multi-node (constitution Workload Pinning)

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Validate, harden defaults, and ensure the repo stays private-safe.

- [x] T030 [P] Normalize labels/selectors across `apps/media/immich/deployment.yaml`, `apps/media/immich/deployment-postgres.yaml`, `apps/media/immich/deployment-redis.yaml`, `apps/media/immich/deployment-machine-learning.yaml`, and `apps/media/immich/service.yaml` to match repo conventions
- [x] T031 Validate manifests render cleanly with `kustomize build clusters/home` and fix any kustomize/resource path issues in `clusters/home/kustomization.yaml` and referenced app kustomizations
- [ ] T032 Verify no private identifiers are introduced by following the scan steps in `specs/001-immich-zero-trust/quickstart.md` and reviewing changed YAML under `apps/` for accidental real hostnames/tokens
- [x] T033 Confirm external-only enforcement by verifying `apps/media/immich/service.yaml` is the only `NodePort` and `apps/networking/immich-origin-proxy/service.yaml` remains `ClusterIP`

---

## Dependencies & Execution Order

Note: Story priority reflects user value (P1/P2/P3), but the recommended execution order is risk-driven (validate storage internally before exposing external access).

### User Story Dependencies

- **US1 (P1)** depends on Phase 1 + Phase 2 being complete.
- **US2 (P2)** depends on Phase 1 + Phase 2 being complete.
- **US3 (P3)** depends on Phase 1 + Phase 2 being complete.

A practical execution order that minimizes risk:

1. Phase 1 → Phase 2
2. US2 minimal stack (internal only) so you can validate storage safely
3. US1 (cloudflared + origin proxy enforcement) for external access
4. US3 docs + operational polish

Dependency graph (recommended):

```text
Phase 1 -> Phase 2 -> US2(minimal internal stack) -> US1(external access) -> US3(docs)
```

### Parallel Opportunities

- [P] tasks in US1 (`configmap.yaml`, `serviceaccount.yaml`, `service.yaml`) can be developed in parallel.
- [P] tasks in US2 (server/postgres/redis/ml manifests) can be developed in parallel.
- Docs tasks (US3) can proceed in parallel once resource names/ports are finalized.

---

## Parallel Example: User Story 1

- Task: `apps/networking/immich-origin-proxy/configmap.yaml` (T008)
- Task: `apps/networking/cloudflared/configmap.yaml` (T012)
- Task: `apps/networking/cloudflared/serviceaccount.yaml` (T011)

---

## Parallel Example: User Story 2

- Task: `apps/media/immich/deployment.yaml` (T015)
- Task: `apps/media/immich/deployment-postgres.yaml` (T016)
- Task: `apps/media/immich/deployment-redis.yaml` (T017)
- Task: `apps/media/immich/deployment-machine-learning.yaml` (T018)

---

## Parallel Example: User Story 3

- Task: `clusters/home/networking/dns/README.md` (T026)
- Task: `troubleshooting.md` (T028)
- Task: `README.md` or `docs/README.md` (T029)

---

## Implementation Strategy

### MVP Scope

- Implement Phase 1 + Phase 2 + US1 (external access) + minimal Immich service wiring needed for the proxy upstream.

### Incremental Delivery

1. Land internal-only Immich (US2 minimal) to validate storage and NodePort behavior
2. Add US1 tunnel + origin proxy enforcement
3. Add US3 documentation and operational hardening
