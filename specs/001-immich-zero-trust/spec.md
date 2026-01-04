# Feature Specification: Immich Zero Trust Access

**Feature Branch**: `001-immich-zero-trust`  
**Created**: 2026-01-04  
**Status**: Draft  
**Input**: Add Immich as an additional homelab service with secure external access (via Cloudflare Zero Trust), GitOps deployment, and NAS-backed storage for iPhone backups. Personal domain details must not be committed.

## Glossary

- **IMMICH_FQDN**: Placeholder for the private hostname used to access Immich. The real value must not be committed.
- **External path**: Internet → Cloudflare Access → Cloudflare Tunnel (`cloudflared`) → in-cluster reverse proxy → Immich.
- **Internal path**: Home LAN / UniFi VPN → local DNS (split-horizon for the same hostname) → Kubernetes NodePort → Immich.
- **Origin (for this feature)**: The in-cluster reverse proxy that fronts Immich on the external path. (Not the Cloudflare edge, and not necessarily the Immich container itself.)

## Entrypoints (explicit)

- **Entrypoint A (External / Internet)**: `IMMICH_FQDN` over HTTPS at Cloudflare edge, gated by Cloudflare Access, routed via Cloudflare Tunnel to the in-cluster reverse proxy.
- **Entrypoint B (Internal / LAN+VPN)**: `IMMICH_FQDN` resolved internally to the node LAN IP, reaching Immich via NodePort, without Cloudflare.

## Storage Paths (placeholders)

- **NAS_LIBRARY_PATH**: Placeholder for the NAS-backed directory that stores the Immich library (photos/videos) and iPhone backups.
- **NAS_BACKUP_PATH**: Not used as a distinct path for this feature. iPhone backups are part of the Immich library and are stored under `NAS_LIBRARY_PATH` with no additional Immich configuration.

## Clarifications

### Session 2026-01-04

- Q: Where should the Cloudflare Tunnel (`cloudflared`) run/terminate for Immich external access? → A: In the Kubernetes cluster as a Flux-managed Deployment.
- Q: How should the “required Cloudflare headers at the origin” be enforced for Immich? → A: An in-cluster reverse proxy in front of Immich rejects requests unless `Cf-Access-Jwt-Assertion` is present.
- Q: How should the NAS storage be presented to Immich in Kubernetes? → A: The NAS is mounted on the Ubuntu host OS already; Immich should use the same `hostPath` mount pattern as Plex.
- Q: For LAN/VPN use (including >100MB uploads), should Immich be reachable without going through Cloudflare Access? → A: Yes—home LAN and UniFi VPN should use local DNS/split-horizon to reach Immich without Cloudflare.

## Namespace

All resources for this feature are deployed in the Kubernetes `default` namespace (consistent with existing apps in this repo).

## User Scenarios & Testing *(mandatory)*

<!--
  IMPORTANT: User stories should be PRIORITIZED as user journeys ordered by importance.
  Each user story/journey must be INDEPENDENTLY TESTABLE - meaning if you implement just ONE of them,
  you should still have a viable MVP (Minimum Viable Product) that delivers value.
  
  Assign priorities (P1, P2, P3, etc.) to each story, where P1 is the most critical.
  Think of each story as a standalone slice of functionality that can be:
  - Developed independently
  - Tested independently
  - Deployed independently
  - Demonstrated to users independently
-->

### User Story 1 - Secure external access (Priority: P1)

As the homelab owner, I want to access Immich from outside my home network using a private subdomain of my personal domain, so I can view my photo library remotely without exposing the service publicly.

**Why this priority**: Remote access is the main value of adding the service; security and privacy constraints must be satisfied first.

**Independent Test**: Can be fully tested by accessing Immich via the external hostname from a non-home network and confirming it is gated by Zero Trust access controls (and does not work through direct/origin access).

**Acceptance Scenarios**:

1. **Given** a client device is outside the home network, **When** it opens the Immich external hostname, **Then** access is granted only after passing the configured Zero Trust policy.
2. **Given** a request attempts to reach the Immich origin directly (not via the approved Cloudflare path), **When** the request is made, **Then** it is rejected and the Immich UI/API is not reachable.
3. **Given** a request reaches Immich through the approved Cloudflare path, **When** the request is forwarded to Immich, **Then** the Cloudflare Access identity header `Cf-Access-Jwt-Assertion` is present (added by Cloudflare) and the origin requires it.
4. **Given** a client is outside the home network, **When** it tries to upload a file larger than 100MB via the external hostname, **Then** the upload is blocked and the user is instructed to use UniFi VPN or the local network.
5. **Given** a client is on home LAN or UniFi VPN, **When** it resolves `IMMICH_FQDN`, **Then** it reaches the internal path (NodePort) without requiring Cloudflare Access.

---

### User Story 2 - NAS-backed iPhone backups (Priority: P2)

As the homelab owner, I want iPhone Immich backups to be stored on my NAS (not on the phone), so backups are durable, centralized, and align with how other media services use NAS storage.

**Why this priority**: The core purpose of Immich is to safely preserve photos/videos. NAS storage is the durability requirement.

**Independent Test**: Can be tested by performing a backup from an iPhone and verifying that new assets are written to the NAS-backed storage location.

**Acceptance Scenarios**:

1. **Given** Immich is running and storage is configured, **When** an iPhone performs a backup, **Then** the backed-up photos/videos are persisted to a NAS-backed location.
2. **Given** a single photo/video asset exists in Immich, **When** it is requested through the Immich UI, **Then** it can be served/read from the NAS-backed storage.

---

### User Story 3 - Operate via GitOps with clear setup docs (Priority: P3)

As the homelab owner, I want Immich to be managed like my other services (automatically applied from the repo by FluxCD) and have clear setup instructions for Cloudflare Tunnel and DNS, so the system is repeatable and maintainable.

**Why this priority**: Once access and storage work, operability and documentation reduce ongoing maintenance cost and mistakes.

**Independent Test**: Can be tested by syncing the repository and confirming the service deploys/updates through the GitOps flow, and by following the docs on a fresh machine/account to reach the same configuration.

**Acceptance Scenarios**:

1. **Given** the GitOps controller is running, **When** Immich manifests are added/updated in the repository, **Then** the running service converges to match the repository state.
2. **Given** documentation exists for Cloudflare Tunnel and DNS, **When** the documented steps are followed, **Then** the external hostname resolves correctly and routes through the tunnel.
3. **Given** the repository is searched, **When** searching for the real personal domain name and other private identifiers, **Then** no matches are found (placeholders only).

---

[Add more user stories as needed, each with an assigned priority]

### Edge Cases

- Large uploads: When an upload is larger than 100MB and the client is outside the home network, the user should be directed to use UniFi VPN or local network access instead (bypassing Cloudflare).
- Storage disruption: If the NAS/external storage is unavailable, Immich should fail safely (no data corruption) and MUST NOT write media assets until NAS storage is available again. The system should provide clear operational signals that storage is not mounted/available.
- DNS split-horizon: If local DNS and public DNS differ, clients on the home network should still resolve the hostname correctly without hairpin/loop issues.
- Zero Trust denial: If a device/user is not authorized by policy, access should be denied without leaking service details.
- Cloudflare outage: If Cloudflare Access/Tunnel is unavailable, internal LAN/VPN access remains the supported fallback.

## Requirements *(mandatory)*

<!--
  ACTION REQUIRED: The content in this section represents placeholders.
  Fill them out with the right functional requirements.
-->

### Functional Requirements

- **FR-001**: The repository MUST define Immich as an additional service alongside existing apps (managed the same way as other services).
- **FR-002**: The service MUST be reachable from outside the home network via a private subdomain of the owner’s personal domain, without committing the real domain name to the repository.
- **FR-003**: External access MUST follow Zero Trust principles: deny-by-default, explicit allow rules for the owner, and no direct public exposure of the origin.
- **FR-003a**: The Cloudflare Access application policy MUST be default-deny, and the allow rule MUST be limited to a single owner identity (email) or a named group controlled by the owner.
- **FR-004**: The Immich origin MUST only accept requests that arrive through the approved Cloudflare path and MUST require the Cloudflare Access identity header `Cf-Access-Jwt-Assertion` at the origin.
- **FR-004a**: The origin-side enforcement MUST be implemented using an in-cluster reverse proxy in front of Immich which rejects requests missing `Cf-Access-Jwt-Assertion`.
- **FR-004b**: The header requirement (`Cf-Access-Jwt-Assertion`) MUST apply to the external path only; the internal LAN/VPN path MUST NOT require Cloudflare Access headers.
- **FR-004c**: The external reverse proxy MUST block request bodies larger than 100MB (e.g., by returning HTTP 413) and direct users to use LAN/VPN for large uploads.
- **FR-005**: The solution MUST include operator documentation describing how to set up:
  - a Cloudflare Tunnel (cloudflared) for the Immich hostname
  - public DNS in Cloudflare for the hostname
  - local DNS on a UniFi Dream Machine router so home clients resolve the hostname correctly
- **FR-005a**: The Cloudflare Tunnel MUST be deployed in-cluster and managed via FluxCD (with tunnel credentials created out-of-band).
- **FR-006**: Immich MUST be able to read/write media to a NAS-backed storage location accessible from the Ubuntu host, using the same approach as Plex (host-mounted NAS + Kubernetes `hostPath` mounts into pods).
- **FR-006a**: The spec/docs MUST define the placeholder path for NAS storage (`NAS_LIBRARY_PATH`) and state that iPhone backups are stored in the same library folder (no separate `NAS_BACKUP_PATH` and no extra Immich configuration).
- **FR-007**: iPhone Immich backups MUST be stored on the NAS-backed storage location.
- **FR-007a**: Backup retention/lifecycle behavior is intentionally out of scope for this feature and defaults to Immich behavior unless explicitly specified later.
- **FR-008**: For files larger than 100MB, the documented supported access methods MUST be limited to UniFi VPN or local network access (not “public internet” access).
- **FR-008a**: For home LAN and UniFi VPN, access MUST be possible without Cloudflare (via local DNS override/split-horizon to an internal endpoint).
- **FR-008b**: Internal LAN/VPN access MUST still be authenticated/authorized using Immich authentication. If supported by Immich, the solution SHOULD allow configuring Google login (OIDC) for the owner account, with all OIDC secrets provided out-of-band (not committed).
- **FR-008c**: Initial bootstrap MUST support an owner-admin path that does not require committing credentials:
  - Option A: owner becomes admin via Google OIDC login (email/group allowlist configured in Immich), OR
  - Option B: operator-provisioned bootstrap admin credentials stored in a Kubernetes Secret created out-of-band.
- **FR-009**: Secrets and private identifiers MUST NOT be committed; documentation MUST use placeholders and instruct operators to supply values locally.
- **FR-009a**: The following MUST be treated as sensitive for this feature and MUST NOT be committed: the real `IMMICH_FQDN`, Cloudflare Tunnel tokens/credentials, and any Cloudflare Access policy identifiers that would reveal private identity details.
- **FR-010**: TLS expectations MUST be explicit in docs: external users connect via HTTPS at Cloudflare edge; the tunnel-to-cluster hop may be HTTP; internal LAN/VPN NodePort access may be HTTP.
- **FR-011**: If NAS-backed storage is not mounted/available, the system MUST fail safely by preventing media writes (e.g., by failing readiness/startup) until storage is available.
- **FR-012**: No additional logging/auditing implementation is required beyond out-of-the-box Cloudflare Access logs and Kubernetes/container logs; operator docs SHOULD point to where those logs can be viewed.

### Key Entities *(include if feature involves data)*

- **Media Asset**: A photo or video stored in Immich, including metadata (timestamp, device source) and its storage location.
- **Storage Location**: A NAS-backed path and any attached external storage path used for Immich media.
- **Access Policy**: The set of Zero Trust rules determining who can access Immich externally and under what conditions.

## Success Criteria *(mandatory)*

<!--
  ACTION REQUIRED: Define measurable success criteria.
  These must be technology-agnostic and measurable.
-->

### Measurable Outcomes

- **SC-001**: From outside the home network, the owner can reach Immich via the external hostname and is challenged by Zero Trust controls before access is granted.
- **SC-002**: Requests to the external origin (reverse proxy) that do not include `Cf-Access-Jwt-Assertion` are rejected 100% of the time.
- **SC-003**: An iPhone backup run results in new media assets being persisted on the NAS-backed storage location (verifiable by inspecting NAS files and Immich UI).
- **SC-004**: Documentation enables a fresh operator to complete tunnel + DNS setup in under 60 minutes, measured from “having Cloudflare + UniFi admin access and a repo checkout” to “external access is gated and internal split-horizon access works”.
- **SC-005**: No real `IMMICH_FQDN` value, tunnel credentials, or other sensitive values are present in the repository after implementation (verified by local repository search using operator-supplied values).

## Assumptions

- The personal domain name and exact hostname are treated as private and will be configured outside the repository (for example via local overlays, secret managers, or operator-supplied values).
- “Additional headers” refers to Cloudflare Zero Trust/Access identity/authorization headers injected by Cloudflare and required by the origin; clients should not need to embed long-lived secrets in apps.
- Uploads larger than 100MB are expected to be performed while on the home network or connected through UniFi VPN.
- Single-node availability is acceptable for this homelab deployment; no HA requirement is implied.
- Secrets may be provided out-of-band (for example via `kubectl create secret` or via CI/CD using GitHub Secrets), but secret values must not be committed to Git.

## Dependencies

- A Cloudflare account with Zero Trust enabled and the ability to create an Access application and a Tunnel.
- A UniFi Dream Machine router providing local DNS (or the ability to add DNS overrides).
- A NAS reachable from the Ubuntu host and suitable for storing photo/video libraries.
- A Kubernetes cluster where a `cloudflared` Deployment can run and reach the Immich service.
- The NAS is already mounted on the Ubuntu host OS at stable mount paths suitable for `hostPath` usage.
- The Kubernetes node runtime has read/write permissions to the NAS mount paths used for `hostPath` volumes.
