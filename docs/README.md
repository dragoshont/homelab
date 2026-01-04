# Docs

- [ubuntu-lts-runbook.md](ubuntu-lts-runbook.md) — setup + reinstall runbook for `home.hont.ro` (Ubuntu LTS), including Ansible bootstrap, NAS mount, and troubleshooting.

## Operator To-Dos (Immich)

Immich is deployed via Flux from manifests under `apps/` and is designed to use:

- Internal access (LAN/VPN): NodePort `30082`
- External access (Internet): Cloudflare Access → Cloudflare Tunnel (`cloudflared`) → in-cluster origin proxy → Immich

### 1) Ensure NAS is mounted on the Kubernetes node

- Mount your NAS on the Ubuntu host at a stable path.
- Ensure the Kubernetes runtime can read/write the NAS path.

### 2) Create the NAS safety marker file

Immich refuses to start unless this file exists on the NAS-backed library folder (prevents writing to the wrong disk if the NAS is not mounted).

- Create on the node (example): `touch /mnt/nas/immich/.immich_nas_marker`

### 3) Supply the real NAS mount path locally (do not commit)

Base manifests intentionally use the placeholder hostPath `/__NAS_LIBRARY_PATH__`.

- Create a local-only Kustomize overlay/patch that replaces `/__NAS_LIBRARY_PATH__` with your real host mount path.
- Keep it uncommitted (the repo ignores `apps/**/overlays/local*/`).

### 4) Create required Kubernetes Secrets (out-of-band)

Postgres password secret (required):

- Secret: `immich-postgres-secret`
- Key: `POSTGRES_PASSWORD`

Example:

- `kubectl -n default create secret generic immich-postgres-secret --from-literal=POSTGRES_PASSWORD='change-me'`

Cloudflare tunnel secret (required):

- Secret: `cloudflared-immich`
- Keys:
	- `credentials.json` (tunnel credentials file)
	- `TUNNEL_ID` (tunnel UUID)
	- `IMMICH_FQDN` (your real hostname)

Example:

- `kubectl -n default create secret generic cloudflared-immich --from-literal=IMMICH_FQDN="IMMICH_FQDN" --from-literal=TUNNEL_ID="TUNNEL_ID" --from-file=credentials.json=./credentials.json`

### 5) Configure DNS split-horizon on UniFi (same hostname)

- Public DNS in Cloudflare: `IMMICH_FQDN` points to the tunnel (`TUNNEL_ID.cfargotunnel.com`).
- Local DNS override on UniFi Dream Machine: `IMMICH_FQDN` → node LAN IP.

### 6) Configure Cloudflare Access policy

- Default deny
- Allow only your identity/group (optionally require MFA)
- The origin proxy requires `Cf-Access-Jwt-Assertion` (defense in depth)

### 7) Verify behavior

- On LAN/VPN: `http://NODE_LAN_IP:30082` should load Immich.
- Off-LAN: `https://IMMICH_FQDN` should be Cloudflare Access gated.
- External requests without the Access header should get `401` from the origin proxy.
- External uploads >100MB should fail (blocked); do them over LAN/VPN.

## Pre-commit safety: no private identifiers/secrets

Before pushing changes, scan the repo for accidental secrets or private identifiers (especially hostnames and tunnel credentials).

Examples (run locally):

- `git grep -n "YOUR_REAL_IMMICH_FQDN" -- .`
- `git grep -n "cfargotunnel.com" -- .`
- `git grep -n "credentials.json" -- .`
- `git grep -n "TUNNEL_TOKEN" -- .`
