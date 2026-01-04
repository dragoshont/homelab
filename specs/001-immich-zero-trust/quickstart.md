# Quickstart — Immich Zero Trust Access

This quickstart describes how to deploy Immich via FluxCD and how to configure Cloudflare Tunnel + Cloudflare Access + split-horizon DNS on a UniFi Dream Machine.

This document intentionally uses placeholders and must NOT contain your real personal domain/hostname.

## Placeholders

- `IMMICH_FQDN`: the private subdomain you want to use (do not commit this)
- `NODE_LAN_IP`: LAN IP of the Kubernetes node (Ubuntu host)
- `IMMICH_NODEPORT`: `30082` (fixed NodePort used for LAN/VPN access)
- `TUNNEL_ID`: Cloudflare Tunnel ID
- `NAS_LIBRARY_PATH`: NAS-backed directory containing Immich library media
- `NAS_BACKUP_PATH`: not used for this feature (iPhone backups are stored in the Immich library under `NAS_LIBRARY_PATH`)

## Namespace

This feature deploys into the Kubernetes `default` namespace.

## NAS hostPath placeholders (and local override)

This repository MUST NOT commit your real NAS mount path.

- Base manifests use a non-sensitive placeholder `hostPath.path` string: `/__NAS_LIBRARY_PATH__`.
- You MUST replace that placeholder locally using a Kustomize patch/overlay that is not committed.

NAS safety guard (prevents writes to the wrong disk):

- The Immich `Deployment` includes an initContainer named `verify-nas`.
- It refuses to start unless the file `/usr/src/app/upload/.immich_nas_marker` exists (this path is inside the NAS-backed volume).
- Operator-visible signal: the pod will remain in init state / crash-loop with logs mentioning `NAS marker file missing`.

Create the marker file once on your NAS library folder (example shown):

- `touch /mnt/nas/immich/.immich_nas_marker`

Suggested local-only overlay pattern:

1. Create a directory such as `apps/media/immich/overlays/local-nas/` (do not commit).
2. Add a `kustomization.yaml` that references the base and applies a patch replacing `/__NAS_LIBRARY_PATH__` with your real host mount path.

Example patch snippet (placeholder values shown):

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
	name: immich
spec:
	template:
		spec:
			volumes:
				- name: library
					hostPath:
						path: /mnt/nas/immich
```

## 0) Model: two entrypoints (same hostname)

This feature intentionally uses the same hostname (`IMMICH_FQDN`) for both:

- **External (Internet)**: `IMMICH_FQDN` → Cloudflare Access → Cloudflare Tunnel → in-cluster reverse proxy → Immich
- **Internal (LAN/VPN)**: `IMMICH_FQDN` → UniFi local DNS override → `NODE_LAN_IP` → NodePort (`IMMICH_NODEPORT`) → Immich

Internal LAN/VPN access must work without Cloudflare.

## 1) Prerequisites

- FluxCD is already installed and reconciling from branch `localdev-dhont-flux-linux` (confirm this in `clusters/home/flux-system/gotk-sync.yaml`).
- NAS is mounted on the Ubuntu host OS (see repo runbook) and is stable for `hostPath` mounts.
- Kubernetes has read/write permissions to the NAS mount paths used for `hostPath` volumes.
- You are comfortable creating Kubernetes Secrets out-of-band (not in Git), or injecting them via CI/CD (for example using GitHub Secrets) without committing secret values.

Cloudflare prerequisites (high level):

- Cloudflare Zero Trust enabled
- Ability to create an Access application and a Tunnel
- DNS zone for `IMMICH_FQDN` managed in Cloudflare

## 2) Deploy manifests via FluxCD

1. Add the new app manifests under `apps/media/immich/`.
2. Add `cloudflared` manifests under `apps/networking/cloudflared/`.
3. Add both to `clusters/home/kustomization.yaml` resources list.

Flux will reconcile and apply.

**Important**: This feature runs `cloudflared` in Kubernetes and manages it via Flux. Do not run `cloudflared` as a host `systemd` service for this setup.

## 3) Create Cloudflare Tunnel and credentials (out-of-band)

Create a tunnel in Cloudflare Zero Trust.

- Name: `immich` (example)
- Connector: `cloudflared` (Kubernetes)

Then create a Kubernetes Secret containing tunnel credentials and the non-committed identifiers needed to render the tunnel config.

This repo expects:

- Secret name: `cloudflared-immich`
- Keys:
	- `credentials.json` (Cloudflare tunnel credentials file)
	- `TUNNEL_ID` (the tunnel UUID)
	- `IMMICH_FQDN` (your real hostname; do not commit it)

Example:

- `kubectl -n default create secret generic cloudflared-immich --from-literal=IMMICH_FQDN="IMMICH_FQDN" --from-literal=TUNNEL_ID="TUNNEL_ID" --from-file=credentials.json=./credentials.json`

## 4) Configure Cloudflare Public Hostname + Access (Zero Trust)

### Public DNS (Cloudflare)

Create a DNS record for `IMMICH_FQDN` pointing to your tunnel:

- Type: `CNAME`
- Name: `IMMICH_FQDN`
- Target: `TUNNEL_ID.cfargotunnel.com`

(Use the tunnel ID provided by Cloudflare.)

### Tunnel routing

Tunnel routing is defined by the in-cluster `cloudflared` config template and rendered at runtime from the `cloudflared-immich` Secret.

The manifests route:

- `IMMICH_FQDN` → `http://immich-origin-proxy:8080`

### Access policy

Create an Access application for `IMMICH_FQDN` and configure:

- Default: deny
- Allow: only your identity (email) or group

Policy checklist (recommended minimum):

- Application is protected by Access (no bypass rule)
- Default action is deny
- Only the owner identity/group is allowed
- Optional: require MFA
- Optional: short session duration for external access

Ensure Cloudflare Access injects the identity JWT header:

- The origin enforcement expects `Cf-Access-Jwt-Assertion` to be present.

## 4a) TLS expectations

- External access is **HTTPS** at the Cloudflare edge.
- The tunnel-to-cluster hop is **HTTP** to `immich-origin-proxy:8080`.
- Internal LAN/VPN NodePort access is **HTTP** to `NODE_LAN_IP:30082`.

## 5) Origin enforcement behavior (external only)

External traffic must:

- arrive through Cloudflare Tunnel
- pass Cloudflare Access
- include `Cf-Access-Jwt-Assertion`

The reverse proxy rejects missing headers and blocks uploads >100MB.

## 5a) Optional: Google login (OIDC) for internal auth

If Immich supports OIDC in your chosen version, you may configure Google login for your owner account so internal LAN/VPN access uses Google auth instead of (or in addition to) Immich local credentials.

Requirements constraints for this repo:

- OIDC client ID/secret must be stored in a Kubernetes Secret created out-of-band (or injected via CI/CD using GitHub Secrets).
- Do not commit any OIDC secrets or real identity details to Git.

## 5b) Initial bootstrap/admin (no committed credentials)

This feature expects one of these bootstrap approaches:

- Owner becomes admin via Google OIDC login (email/group allowlist configured in Immich), OR
- Operator provisions an initial admin credential stored in a Kubernetes Secret created out-of-band.

Practical guidance (recommended):

- Do the initial bootstrap from LAN/VPN using the internal NodePort (`http://NODE_LAN_IP:30082`).
- Create the first user and verify you can log in.
- If you use OIDC, complete one OIDC login for the owner account and then promote/administer accounts from the Immich UI.

## 6) UniFi Dream Machine: split-horizon DNS (LAN/VPN bypass)

Goal: the same hostname `IMMICH_FQDN` resolves differently internally vs publicly.

- Public: `IMMICH_FQDN` → Cloudflare Tunnel
- Internal (LAN/VPN): `IMMICH_FQDN` → `NODE_LAN_IP`

On the UniFi Dream Machine, add a local DNS override/host record:

- Hostname: `IMMICH_FQDN`
- IP: `NODE_LAN_IP`

This allows LAN/VPN clients to reach Immich directly (NodePort) without Cloudflare.

### DNS diagnostics (requirements-oriented)

Expected outcomes:

- On LAN/VPN: `IMMICH_FQDN` resolves to `NODE_LAN_IP`
- Off LAN: `IMMICH_FQDN` resolves to the Cloudflare public record (tunnel)

If a LAN client resolves the public record instead, fix the UniFi DNS override.

## 7) Using UniFi VPN or LAN for files >100MB

For large uploads (>100MB):

- Connect to UniFi VPN (or be on LAN)
- Ensure `IMMICH_FQDN` resolves to `NODE_LAN_IP`
- Upload via the internal NodePort path

## 8) Safety check: no private identifiers in Git

Before pushing changes:

- Search the repo for your *real* `IMMICH_FQDN` value and remove anything that would identify it.
- Ensure tunnel credentials, tokens, and Access secrets are only created out-of-band.

Example local checks (run on your workstation; do not commit outputs):

- `git grep -n "YOUR_REAL_IMMICH_FQDN" -- .`
- `git grep -n "TUNNEL_TOKEN" -- .`

## 9) Logging/audit expectations (out of the box)

No additional logging/auditing work is required for this feature.

- For external access decisions, rely on Cloudflare Access logs.
- For in-cluster components, rely on standard Kubernetes/container logs.

Common log entrypoints:

- `kubectl -n default logs deploy/cloudflared --tail=200`
- `kubectl -n default logs deploy/immich-origin-proxy --tail=200`

## 10) Single-node + hostPath scheduling note

Immich uses `hostPath`, so it must run on the node that has:

- the NAS mount path (your real `NAS_LIBRARY_PATH`), and
- the local disk paths for Postgres state.

If this cluster becomes multi-node, add node pinning (nodeSelector/affinity) so these pods only schedule to the node with the required mounts.
