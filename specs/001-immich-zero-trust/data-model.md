# Phase 1 Design — Data Model (Operational)

This feature does not introduce a new application API; it introduces Kubernetes-managed services and operational entities.

## Entities

### Immich Stack

- **Immich Server**
  - Purpose: primary UI/API for clients
  - Depends on: Postgres, Redis, persistent library storage

- **Immich Machine Learning**
  - Purpose: background ML tasks (e.g., facial recognition)
  - Depends on: Immich server, library access (read)

- **Postgres**
  - Purpose: metadata database
  - State: persistent data directory on hostPath (internal drive recommended)

- **Redis**
  - Purpose: cache/queue
  - State: ephemeral or persistent based on implementation preference (default ephemeral unless durability is required)

### Storage Locations

- **NAS Library Path**
  - Source: host-mounted NAS (NFS) on Ubuntu
  - Mounted into pods via `hostPath`
  - Holds: photo/video library and iPhone backups

- **Internal Drive Config Path**
  - Source: host local storage (e.g., `/mnt/internal_drive/config/...`)
  - Holds: database files and app configuration

### Access Plane

- **Internal Endpoint (LAN/VPN)**
  - Exposure: Kubernetes `Service` type `NodePort`
  - Auth: Immich native auth
  - DNS: split-horizon record on UniFi Dream Machine points hostname to the node IP

- **External Endpoint (Internet)**
  - Exposure: Cloudflare Tunnel (`cloudflared`) → in-cluster reverse proxy → Immich
  - Auth: Cloudflare Access + origin enforcement

- **Origin Enforcement Reverse Proxy**
  - Rules:
    - require `Cf-Access-Jwt-Assertion` header
    - block request bodies >100MB
    - forward all other traffic to Immich

## Relationships

- Immich Server ↔ Postgres (stateful)
- Immich Server ↔ Redis
- Immich Server ↔ NAS Library Path
- Cloudflared → Reverse Proxy → Immich Server (external path)
- LAN/VPN clients → NodePort → Immich Server (internal path)

## State Transitions (high level)

- **Backup Upload**: iPhone client uploads → Immich server persists media → NAS library path updated
- **External Access**: unauthenticated request → Cloudflare Access login → reverse proxy header check → upstream request served
