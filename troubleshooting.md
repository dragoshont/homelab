
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
mount | grep /media_nas/complete || true
sudo mount -a
ls -la /media_nas/complete
```

### Flux not applying changes

- Ensure the cluster is pointed at `./clusters/home` and the intended branch.
- Check Flux controllers and reconciliation status:

```bash
kubectl -n flux-system get all
kubectl -n flux-system get kustomizations,gitrepositories
kubectl -n flux-system logs deploy/kustomize-controller --tail=200
```
