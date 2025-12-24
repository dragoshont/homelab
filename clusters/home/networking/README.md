# Networking notes

This repository currently does **not** deploy an Ingress controller as part of the reconciled `clusters/home` kustomization.

## Accessing services (home network)

Services are intended to be accessed from your home LAN using **NodePort**:

- `http://<server-lan-ip>:<nodeport>`

The NodePorts are defined per app in `apps/**/service.yaml`.

## DNS

If you want friendly hostnames (e.g., `home.hont.ro`) for LAN access, see:

- [clusters/home/networking/dns/README.md](dns/README.md)
