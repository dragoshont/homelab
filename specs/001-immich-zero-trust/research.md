# Phase 0 Research — Immich Zero Trust Access

This document captures design decisions and rationale for adding Immich with Cloudflare Zero Trust access, consistent with this repository’s FluxCD + NodePort + hostPath patterns.

## Decisions

### Decision: Cloudflared runs in-cluster (Flux-managed)

- **Decision**: Deploy `cloudflared` as a Kubernetes `Deployment` in the cluster, reconciled by Flux.
- **Rationale**: Keeps the “front door” in GitOps, reduces host-level drift, and matches the repo’s preference for cluster-managed services.
- **Alternatives considered**:
  - Run `cloudflared` on the Ubuntu host via `systemd` (simpler runtime, but drifts outside GitOps).
  - Run `cloudflared` on the router (tight coupling to networking device; harder to manage/roll back in Git).

### Decision: Two entrypoints (external via Cloudflare, internal via LAN/VPN)

- **Decision**: Provide a Cloudflare-protected external entrypoint and a LAN/VPN internal entrypoint.
- **Rationale**: Supports the requirement that uploads >100MB must use LAN/VPN while keeping internet access Zero Trust.
- **Alternatives considered**:
  - Force all traffic through Cloudflare (harder to support large uploads; adds dependency for local usage).

### Decision: Origin-side enforcement via in-cluster reverse proxy

- **Decision**: Put a small reverse proxy in front of Immich for the external path that:
  - rejects requests missing `Cf-Access-Jwt-Assertion`
  - blocks request bodies larger than 100MB
  - forwards allowed traffic to Immich
- **Rationale**: Cloudflare Access can be misconfigured; origin enforcement ensures deny-by-default even if the tunnel/hostname is exposed.
- **Alternatives considered**:
  - Let Immich validate Cloudflare Access directly (not assumed available; couples to upstream features).
  - Rely solely on Cloudflare Access (no defense-in-depth at the origin).

### Decision: Storage uses host-mounted NAS + hostPath mounts (Plex pattern)

- **Decision**: Use existing host OS NAS mount (NFS) and mount it into pods via Kubernetes `hostPath`.
- **Rationale**: Matches repo conventions and avoids introducing new storage controllers.
- **Alternatives considered**:
  - NFS PV/PVC in Kubernetes (valid, but is a new storage pattern in this repo).

## Security Notes (Zero Trust)

- External access is authenticated/authorized by Cloudflare Access.
- Origin enforcement requires the Cloudflare Access JWT header at the reverse proxy.
- No plaintext secrets or private identifiers (personal domain/hostname, tunnel credentials) are committed to Git.

## Open Questions

None remaining for Phase 1. Implementation specifics (ports, exact container images) will follow upstream Immich docs during execution, but do not change the architecture choices above.
