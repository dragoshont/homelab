# homelab Development Guidelines

Auto-generated from all feature plans. Last updated: 2026-01-04

## Active Technologies
- FluxCD + Kustomize (Kubernetes manifests, YAML) (001-immich-zero-trust)
- Cloudflare Tunnel (`cloudflared`) (001-immich-zero-trust)
- Host-mounted NAS (NFS) exposed to pods via `hostPath` (pattern used by Plex) (001-immich-zero-trust)

## Project Structure

```text
clusters/
apps/
ansible/
docs/
```

## Commands

kustomize build clusters/home
git grep -n "hont.ro" -- .

## Code Style

YAML/Kustomize: keep manifests minimal, consistent with existing `apps/**` patterns

## Recent Changes
- 001-immich-zero-trust: Added FluxCD + Kustomize + cloudflared (Cloudflare Tunnel) context

<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->
