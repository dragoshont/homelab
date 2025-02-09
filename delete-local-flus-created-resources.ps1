# Step 1: Pause reconciliation
# This command suspends the kustomization, stopping Flux from managing the resources temporarily.
Write-Output "Suspending kustomization to stop Flux from managing the resources temporarily..."
flux suspend kustomization media-apps-media-apps-kustomization --namespace media

# Step 2: Delete the resources in each referenced directory
# These commands delete the resources managed by the kustomization in the specified directories.
Write-Output "Deleting resources in the 'namespaces' directory..."
kubectl delete -k C:\Repos\homelab\infrastructure\namespaces

Write-Output "Deleting resources in the 'smb-csi' directory..."
kubectl delete -k C:\Repos\homelab\infrastructure\smb-csi

Write-Output "Deleting resources in the 'nfs-provisioner' directory..."
kubectl delete -k C:\Repos\homelab\infrastructure\nfs-provisioner

Write-Output "Deleting resources in the 'storage' directory..."
kubectl delete -k C:\Repos\homelab\infrastructure\storage

Write-Output "Deleting resources in the 'networking/traefik' directory..."
kubectl delete -k C:\Repos\homelab\infrastructure\networking\traefik

Write-Output "Deleting resources in the 'apps/media/sonarr' directory..."
kubectl delete -k C:\Repos\homelab\apps\media\sonarr

Write-Output "Deleting resources in the 'apps/media/radarr' directory..."
kubectl delete -k C:\Repos\homelab\apps\media\radarr

Write-Output "Deleting resources in the 'apps/media/prowlarr' directory..."
kubectl delete -k C:\Repos\homelab\apps\media\prowlarr

Write-Output "Deleting resources in the 'apps/media/qbittorrent' directory..."
kubectl delete -k C:\Repos\homelab\apps\media\qbittorrent

# Step 3: Resume the kustomization to let Flux recreate the resources
# This command resumes the kustomization, allowing Flux to manage the resources again.
Write-Output "Resuming kustomization to let Flux recreate the resources..."
flux resume kustomization media-apps-media-apps-kustomization --namespace media

# Step 4: Force reconciliation to ensure that Flux applies the latest changes
# This command forces a reconciliation, ensuring that Flux applies the latest changes to the resources.
Write-Output "Forcing reconciliation to ensure that Flux applies the latest changes..."
flux reconcile kustomization media-apps-media-apps-kustomization --namespace media --with-source --verbose

Write-Output "Reconciliation process completed."