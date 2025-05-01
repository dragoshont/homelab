#!/bin/bash
# Suspending Flux reconciliation (if applicable)
echo ">>> [1/3] Suspending Flux reconciliation (if applicable)"
flux suspend kustomization nitrox || echo "⚠️ Flux not installed or Kustomization 'nitrox' not found. Skipping."

# Scaling down the deployment to stop the game server
echo ">>> [2/3] Scaling down deployment to stop the game server"
kubectl -n default scale deployment nitrox-subnautica --replicas=0
echo "⏳ Waiting 10s for pods to terminate..."
sleep 10

# Scaling deployment back up
echo ">>> [3/3] Scaling deployment back up"
kubectl -n default scale deployment nitrox-subnautica --replicas=1

# Resuming Flux reconciliation (if suspended)
echo ">>> ✅ Resuming Flux reconciliation (if suspended)"
flux resume kustomization nitrox || echo "⚠️ Flux not installed or Kustomization 'nitrox' not found. Skipping."
