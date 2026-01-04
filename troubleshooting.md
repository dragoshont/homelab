
# Troubleshooting

Start here:

- [docs/ubuntu-lts-runbook.md](docs/ubuntu-lts-runbook.md)

## Common checks

### Can’t access a web UI from the home network

- Confirm the app Service is `type: NodePort` and note the `nodePort`.
- Access pattern: `http://<server-lan-ip>:<nodeport>`.
- If it works on the server but not from another LAN device, check host firewall (UFW) and Wi‑Fi client isolation.

### NAS content not visible

On `home.hont.ro`:

```bash
mount | grep /media/nas || true
sudo mount -a
ls -la /media/nas
```

### Immich: external vs internal access

This feature uses two paths:

- **Internal (LAN/VPN)**: `http://NODE_LAN_IP:30082` (NodePort)
- **External (Internet)**: `https://IMMICH_FQDN` (Cloudflare Access → tunnel → origin proxy)

DNS split-horizon checks:

- From a LAN/VPN client: `nslookup IMMICH_FQDN` should return `NODE_LAN_IP`
- From a non-LAN network: `nslookup IMMICH_FQDN` should return the Cloudflare public record

If internal access is broken:

- Confirm the Service is NodePort 30082: `kubectl -n default get svc immich -o wide`
- Confirm pods are running: `kubectl -n default get pods -l app=immich`
- If pods are stuck in init: check the NAS marker guard: `kubectl -n default logs deploy/immich -c verify-nas --tail=50`

If external access is broken:

- Check tunnel pod logs: `kubectl -n default logs deploy/cloudflared --tail=200`
- Check origin proxy logs: `kubectl -n default logs deploy/immich-origin-proxy --tail=200`
- Confirm origin proxy is ClusterIP-only: `kubectl -n default get svc immich-origin-proxy -o wide`

### Flux not applying changes

- Ensure the cluster is pointed at `./clusters/home` and the intended branch.
- Check Flux controllers and reconciliation status:

```bash
kubectl -n flux-system get all
kubectl -n flux-system get kustomizations,gitrepositories
kubectl -n flux-system logs deploy/kustomize-controller --tail=200
```
