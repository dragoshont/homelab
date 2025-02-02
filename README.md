# Homelab GitOps Repository

## Overview
This repository manages a Kubernetes homelab using FluxCD for GitOps automation. It is structured to clearly separate concerns between cluster configuration, infrastructure components, and application deployments. This approach ensures that changes are automatically reconciled by Flux while keeping each domain of configuration isolated.

## Folder Structure
Below is the folder structure of the repository:

 ```
homelab-gitops/
├── clusters/             # Cluster-specific overlays for Flux (e.g., k3s cluster settings, Flux bootstrap files)
├── infrastructure/       # Manifests for infrastructure components (storage, networking, CSI drivers, and Lens)
│   ├── storage/          # PersistentVolume and PersistentVolumeClaim definitions, secrets, etc.
│   ├── networking/       # Networking configuration and reverse proxy settings (e.g., Traefik)
│   │   └── traefik/      # Traefik Helm chart repository and release definitions
│   ├── smb-csi/          # HelmRelease for SMB CSI driver management
├── apps/                 # Application deployments (media applications like Sonarr, Radarr, Prowlarr, qBittorrent)
│   └── media/            # Media apps grouped together
│       ├── sonarr/       # Sonarr manifests (deployment, service, ingress, kustomization)
│       ├── radarr/       # Radarr manifests (deployment, service, ingress, kustomization)
│       ├── prowlarr/     # Prowlarr manifests (deployment, service, ingress, kustomization)
│       └── qbittorrent/  # qBittorrent manifests (deployment, service, ingress, kustomization)
└── README.md             # Project documentation and rationale for the structure
```

## Reasoning Behind the Folder Structure

- **Clusters:**  
  Contains configurations that are specific to each Kubernetes cluster environment (e.g., k3s) and includes files required for bootstrapping Flux. This allows you to manage different cluster environments separately.

- **Infrastructure:**  
  Houses all the low-level components that are essential for cluster operations, such as storage configurations (PersistentVolumes, PersistentVolumeClaims, secrets), networking settings (reverse proxy with Traefik), and monitoring tools (Lens). This separation helps to manage and update infrastructure services independently from application code.

- **Apps:**  
  Contains the deployment manifests for your applications. Grouping the media applications (Sonarr, Radarr, Prowlarr, qBittorrent) under a single directory makes it easier to manage their configurations collectively, especially when they share common storage resources.

- **GitOps Approach:**  
  The entire structure is designed to be reconciled by Flux, ensuring that any changes committed to the repository are automatically applied to the cluster. This clear separation aids in troubleshooting, maintenance, and scalability of the homelab.

Enjoy managing your homelab using this GitOps repository structure!
