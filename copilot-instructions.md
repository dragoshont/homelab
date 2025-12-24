# Copilot instructions (homelab repo)

These instructions describe the **default assumptions and constraints** for changes in this repository.

## Repo intent

- This repo manages a Kubernetes homelab using **FluxCD + Kustomize** (GitOps).
- Prefer GitOps changes (YAML in `apps/` + `clusters/`) over manual kubectl commands.
- Avoid adding complexity unless explicitly requested.

## Flux / GitOps constraints

- Flux reconciles the cluster from:
  - `clusters/home/`
- The branch currently used by Flux is:
  - `localdev-dhont-flux-linux`
- The Git URL referenced by Flux in this repo is:
  - `ssh://git@github.com/dhont/homelab`

When making changes that should be applied to the cluster, ensure they land on the branch/path that Flux actually reconciles.

## Networking / access model

- **No ingress** by default.
- Do not add Traefik / cert-manager / Ingress objects unless explicitly requested.
- LAN access is via **NodePort Services**. Prefer keeping this model.

## Storage model (hostPath-first)

- Many workloads use local host paths and/or PVs backed by host paths.
- Assume the Ubuntu host must provide these directories:
  - `/mnt/internal_drive/config`
  - `/mnt/internal_drive/downloads`
  - `/mnt/internal_drive/transcode`
  - `/media/external_drive/complete`

### NAS / NFS

- The NAS host is `nas.hont.ro` exporting `:/complete`.
- The NAS share is mounted on the Ubuntu host at:
  - `/media/nas`
- Security model: **IP-based** (AUTH_SYS / `sec=sys`). No Kerberos.
- Do not rename existing mountpoints unless explicitly requested.

## Plex specifics

- Plex runs as a Kubernetes Deployment and reads media from host paths.
- Plex should be able to see NAS content under `/media/nas` (mounted into the container).
- Do **not** commit `PLEX_CLAIM` or other secrets in manifests.

## Ubuntu bootstrap (Ansible)

- This repo includes an Ansible bootstrap role (`ansible/roles/ubuntu_bootstrap`) intended to support a future Ubuntu reinstall.
- Ubuntu 24.04+ uses PEP 668; prefer installing Ansible via `apt` on the host.
- The bootstrap should:
  - run `apt update` + full upgrade (manual reboot policy)
  - install base packages (including `nfs-common`)
  - ensure the NAS mount exists and is persisted via `/etc/fstab`
  - create the common hostPath directories listed above
  - avoid destructive actions by default (warn before removing conflicting `/etc/fstab` entries)

## Secrets

- Avoid committing secrets in plaintext.
- If a change needs secrets, prefer documenting the manual creation step or using an encrypted-secrets approach (only if explicitly requested).

## Change discipline

- Make minimal, focused changes.
- Keep manifests simple and consistent with existing patterns.
- If a requirement is ambiguous, choose the simplest interpretation and ask 1–3 clarifying questions.
