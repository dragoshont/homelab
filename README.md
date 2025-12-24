# Homelab (FluxCD)

This repository manages a Kubernetes homelab using FluxCD + Kustomize. Flux reconciles the cluster state from Git.

## Runbook (Ubuntu host)

For setting up or reinstalling the bare-metal Ubuntu LTS machine (packages, full `apt upgrade`, NFS mount to the NAS, and operational troubleshooting), use:

- [docs/ubuntu-lts-runbook.md](docs/ubuntu-lts-runbook.md)

## Repository structure

```text
.
├── clusters/                 # Cluster entrypoints (Flux sync, cluster kustomizations)
│   └── home/                 # Home cluster (Flux reconciles ./clusters/home)
├── apps/                     # App manifests (Deployments/Services/Kustomizations)
├── ansible/                  # Ubuntu bootstrap (deps + apt upgrade + NAS mount)
├── docs/                     # Operational docs and runbooks
└── troubleshooting.md        # Quick pointers (see docs runbook)
```

Key entrypoint:

- [clusters/home/kustomization.yaml](clusters/home/kustomization.yaml)

## Accessing apps on your home network (no ingress)

This repo exposes most UIs using **NodePort** Services. Access pattern:

- `http://<server-lan-ip>:<nodeport>`

The exact ports are defined in each app’s `service.yaml`. The runbook lists the common ones.

## Storage model

Storage is currently based on local `hostPath` directories (and PVs backed by `hostPath`). The host is expected to provide directories like:

- `/mnt/internal_drive/config`
- `/mnt/internal_drive/downloads`
- `/mnt/internal_drive/transcode`
- `/media/external_drive/complete`

Additionally, the NAS share is mounted on the host at:

- `/media/nas` (mounted from `nas.hont.ro:/complete`)

## Secrets

Avoid committing secrets in plaintext. Flux Git authentication (SSH deploy key secret) and app secrets should be created out-of-band, or managed using an encrypted-secrets approach (e.g., SOPS) if/when adopted.

## Updates (how things stay current)

There are two separate update loops:

- **Kubernetes apps/config**: Flux reconciles the cluster from Git. Push changes to the branch Flux watches (see `clusters/home/flux-system/gotk-sync.yaml`) and Flux applies them.
- **Ubuntu host OS/dependencies**: updated by running the Ansible bootstrap manually. It performs `apt update` + full `apt upgrade`, installs required packages (incl. `nfs-common`), and ensures the NAS mount exists. Reboots are manual-only.

Ansible entrypoint:

- `ansible/playbooks/bootstrap-ubuntu.yml`

CI note:

- GitHub Actions in this repo only runs lint/syntax checks for Ansible; it does not connect to or update your server.
