# Ubuntu LTS runbook (home.hont.ro)

This document is a practical setup + troubleshooting guide for (re)installing the bare-metal Ubuntu LTS host used by this repo.

## Assumptions

- Target host: `home.hont.ro` (Ubuntu LTS, bare metal)
- NAS: `nas.hont.ro` exports `:/complete`
- NAS mountpoint on host: `/media_nas/complete`
- Kubernetes manifests are applied by FluxCD (GitOps). This repo does **not** include scripts that install Kubernetes.

## 0) Pre-flight checklist

- You know the server’s LAN IP (you will use this to access services via NodePorts).
- SSH access works (`openssh-server` installed, firewall allows port 22 from your LAN).
- Your NAS exports are restricted by IP/subnet (AUTH_SYS / “IP based security”).

## 1) Fresh Ubuntu LTS base setup

1. Install Ubuntu LTS and create a user (example user: `ubuntu`) with sudo.
2. Enable SSH:

   ```bash
   sudo apt update
   sudo apt install -y openssh-server
   sudo systemctl enable --now ssh
   ```

3. (Recommended) Set a static DHCP lease for the server in your router.

## 2) Get the repository on the host

Install Git and clone the repo:

```bash
sudo apt update
sudo apt install -y git

# choose a location
mkdir -p ~/src
cd ~/src

# clone via HTTPS (simplest)
git clone https://github.com/dragoshont/homelab.git
cd homelab

# optional: check out your working branch
# git checkout localdev-dhont-flux-linux
```

## 3) Run Ansible bootstrap (packages + full apt upgrade + NAS mount)

This repo contains an Ansible bootstrap that:

- Runs `apt update` + full `apt upgrade` (no automatic reboot)
- Installs baseline packages including `nfs-common`
- Mounts `nas.hont.ro:/complete` at `/media_nas/complete` and persists it via `/etc/fstab`

### Option A: Run Ansible locally on the host (simplest)

```bash
cd ~/src/homelab/ansible

# install ansible
sudo apt update
sudo apt install -y python3-pip
python3 -m pip install --user ansible

# ensure ~/.local/bin is on PATH for your shell session
export PATH="$HOME/.local/bin:$PATH"

# install required collections
ansible-galaxy collection install -r requirements.yml

# run against the local machine
ansible-playbook playbooks/bootstrap-ubuntu.yml \
  -i inventories/home/hosts.yml \
  -l home.hont.ro \
  --connection=local \
  --become
```

### Option B: Run Ansible from your workstation over SSH

1. Ensure the inventory user matches your server username (see `ansible/inventories/home/hosts.yml`).
2. From your workstation:

```bash
cd ansible
ansible-galaxy collection install -r requirements.yml
ansible-playbook playbooks/bootstrap-ubuntu.yml -i inventories/home/hosts.yml --ask-become-pass
```

### Verify the NAS mount

```bash
mount | grep /media_nas/complete || true
ls -la /media_nas/complete
```

## 4) Kubernetes + Flux notes

This repo expects Flux to reconcile manifests under `clusters/home/`.

- Flux manifests live under `clusters/home/flux-system/`.
- You still need Kubernetes installed on the host.

### 4.1 Install Kubernetes (k3s – recommended for bare metal)

1. Install k3s:

```bash
curl -sfL https://get.k3s.io | sh -
```

1. Make `kubectl` usable for your user:

```bash
sudo mkdir -p $HOME/.kube
sudo cp /etc/rancher/k3s/k3s.yaml $HOME/.kube/config
sudo chown -R $USER:$USER $HOME/.kube

# optional sanity check
kubectl get nodes
```

1. (Optional) Allow your user to read the system kubeconfig without copying it:

```bash
sudo usermod -aG k3s $USER 2>/dev/null || true
```

### 4.2 Bootstrap Flux (use existing manifests in this repo)

Flux needs Git access. The manifests reference a secret named `flux-system`.

1. Install the Flux CLI on the host:

```bash
curl -s https://fluxcd.io/install.sh | sudo bash
flux --version
```

1. Generate an SSH deploy key for Flux (do **not** commit it):

```bash
ssh-keygen -t ed25519 -N '' -f ./flux_deploy_key
```

1. Add the **public** key (`./flux_deploy_key.pub`) as a Deploy Key in GitHub:

- Repo: `dragoshont/homelab`
- Settings → Deploy keys → Add deploy key
- Enable **Allow write access** if you plan to use Flux image automation later.

1. Create the `flux-system` secret in the cluster (private key stays local):

```bash
kubectl create namespace flux-system --dry-run=client -o yaml | kubectl apply -f -

kubectl -n flux-system create secret generic flux-system \
  --from-file=identity=./flux_deploy_key \
  --from-file=identity.pub=./flux_deploy_key.pub \
  --from-literal=known_hosts="$(ssh-keyscan github.com 2>/dev/null)" \
  --dry-run=client -o yaml | kubectl apply -f -
```

1. Install Flux controllers (from the repo manifest) and apply the sync config:

```bash
kubectl apply -f ~/src/homelab/clusters/home/flux-system/gotk-components.yaml
kubectl apply -f ~/src/homelab/clusters/home/flux-system/gotk-sync.yaml

# watch reconciliation
kubectl -n flux-system get pods
kubectl -n flux-system get kustomizations,gitrepositories
```

Notes:

- If `gotk-sync.yaml` points to a different Git URL/branch than you intend, update it in Git and let Flux reconcile, or apply a corrected `GitRepository`/`Kustomization` manually.

### 4.3 Confirm Flux is applying the cluster entrypoint

The cluster entrypoint is:

- `clusters/home/kustomization.yaml`

It should apply apps + storage for the `home` cluster.

## 5) How to access services from your home network (no ingress)

This repo primarily exposes web UIs via **NodePort** Services.

Pattern:

- `http://<server-lan-ip>:<nodeport>`

Examples (as defined in the Service manifests):

- Plex: `http://<server-lan-ip>:32400`
- Sonarr: `http://<server-lan-ip>:30089`
- Radarr: `http://<server-lan-ip>:30078`
- Prowlarr: `http://<server-lan-ip>:30096`
- qBittorrent: `http://<server-lan-ip>:30080`
- Scrypted: `http://<server-lan-ip>:31080`

## 6) Plex first-time setup (claim token)

This repo no longer commits `PLEX_CLAIM`.

- First-time claim is done manually via the Plex UI.
- Plex keeps its state under the host path mounted to `/config`, so you typically only do this once.

## Troubleshooting

### NAS mount fails

1. Check the export exists and is reachable:

```bash
# from home.hont.ro
showmount -e nas.hont.ro || true
```

1. Confirm the NAS export allows your server IP/subnet.
1. Check fstab entry and try a remount:

```bash
sudo findmnt /media_nas/complete || true
sudo mount -a
```

1. Inspect logs:

```bash
journalctl -u rpcbind --no-pager | tail -n 200 || true
journalctl --no-pager | tail -n 200
```

### Ansible says “reboot required”

The bootstrap playbook will never reboot automatically.

- Reboot when convenient:

```bash
sudo reboot
```

### Pods can’t see hostPath folders

Many workloads use host paths (or PVs backed by host paths). If the directories don’t exist, Kubernetes may fail to mount them.

Common required directories include:

- `/mnt/internal_drive/config`
- `/mnt/internal_drive/downloads`
- `/mnt/internal_drive/transcode`
- `/media/external_drive/complete`
- `/media_nas/complete`

Create missing directories and ensure permissions are correct.

### Service reachable only from the node

If you can reach `http://127.0.0.1:<nodeport>` on the host but not from another LAN machine:

- Check your host firewall (UFW) and allow the required NodePort range or specific ports.
- Verify your router is not isolating clients (guest Wi-Fi / client isolation).

### Reinstall checklist (quick)

1. Install Ubuntu LTS + SSH
2. Clone repo
3. Run Ansible bootstrap (packages + mounts)
4. Install Kubernetes distro
5. Bootstrap Flux to `./clusters/home`
6. Verify UIs via NodePorts

## Post-reinstall verification (recommended)

Run these checks after a reinstall or major change.

### Kubernetes / k3s

```bash
kubectl get nodes -o wide
kubectl get namespaces
```

### Flux

```bash
kubectl -n flux-system get pods
kubectl -n flux-system get kustomizations,gitrepositories
kubectl -n flux-system logs deploy/kustomize-controller --tail=200
```

Expected:

- `GitRepository/flux-system` shows `Ready=True`
- `Kustomization/flux-system` shows `Ready=True`

### Workloads

```bash
kubectl get pods -A
kubectl get deploy -A
kubectl get svc -A
```

If something is crashing, pull logs:

```bash
kubectl -n <namespace> logs deploy/<name> --tail=200
```

### Host storage and NAS mount

On `home.hont.ro`:

```bash
mount | grep /media_nas/complete || true
ls -la /media_nas/complete | head
```

### LAN access (NodePorts)

From another machine on your home network:

- `http://<server-lan-ip>:32400` (Plex)
- `http://<server-lan-ip>:30089` (Sonarr)
- `http://<server-lan-ip>:30078` (Radarr)
- `http://<server-lan-ip>:30096` (Prowlarr)
- `http://<server-lan-ip>:30080` (qBittorrent)
- `http://<server-lan-ip>:31080` (Scrypted)

## Suggested future improvements

- Consider adopting an encrypted-secrets workflow (e.g., SOPS) for application secrets.
- Consider documenting (or automating) Kubernetes installation (k3s/microk8s) if you want a one-command reinstall path.
