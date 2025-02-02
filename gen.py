import os
import shutil

# Define base directory
base_dir = "homelab-gitops"

# Define directory structure and file contents
structure = {
    "clusters/local-k3s": {
        "kustomization.yaml": """\
resources:
  - ../../infrastructure/lens
  - ../../infrastructure/smb-csi
  - ../../infrastructure/storage
  - ../../infrastructure/networking/traefik
  - ../../apps/media/sonarr
  - ../../apps/media/radarr
  - ../../apps/media/prowlarr
  - ../../apps/media/qbittorrent
""",
        "apps.yaml": "# (Cluster apps overlay)",
        "storage.yaml": "# (Cluster storage overlay)",
        "networking.yaml": "# (Cluster networking overlay)"
    },
    "infrastructure/storage": {
        "smb-secret.yaml": """\
apiVersion: v1
kind: Secret
metadata:
  name: smb-secret
  namespace: media
type: Opaque
stringData:
  username: shareuser
  password: a9Tp2R7K1vNxL6dYwZ3BqV0sH4JmP8Gc
""",
        "smb-pv.yaml": """\
apiVersion: v1
kind: PersistentVolume
metadata:
  name: smb-share-e
spec:
  capacity:
    storage: 500Gi
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  csi:
    driver: smb.csi.k8s.io
    volumeHandle: smb-share-e
    volumeAttributes:
      source: "//l2.hont.ro/E"
    nodeStageSecretRef:
      name: smb-secret
      namespace: media
""",
        "smb-pvc.yaml": """\
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: smb-pvc-e
  namespace: media
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 500Gi
  volumeName: smb-share-e
  storageClassName: ""
""",
        "nfs-pv.yaml": """\
apiVersion: v1
kind: PersistentVolume
metadata:
  name: nfs-media
spec:
  capacity:
    storage: 1Ti
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  nfs:
    server: nas.hont.ro
    path: "/complete"
""",
        "nfs-pvc.yaml": """\
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nfs-pvc
  namespace: media
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 1Ti
  volumeName: nfs-media
  storageClassName: ""
""",
        "kustomization.yaml": """\
resources:
  - smb-secret.yaml
  - smb-pv.yaml
  - smb-pvc.yaml
  - nfs-pv.yaml
  - nfs-pvc.yaml
"""
    },
    "infrastructure/smb-csi": {
        "helmrepository.yaml": """\
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: kubernetes-csi
  namespace: flux-system
spec:
  interval: 10m
  url: https://raw.githubusercontent.com/kubernetes-csi/csi-driver-smb/master/charts
""",
        "helmrelease.yaml": """\
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: csi-driver-smb
  namespace: kube-system
spec:
  interval: 10m
  chart:
    spec:
      chart: csi-driver-smb
      version: "latest"
      sourceRef:
        kind: HelmRepository
        name: kubernetes-csi
        namespace: flux-system
      interval: 5m
  install:
    remediation:
      retries: 3
  upgrade:
    remediation:
      retries: 3
""",
        "kustomization.yaml": """\
resources:
  - helmrepository.yaml
  - helmrelease.yaml
"""
    },
    "infrastructure/lens": {
        "helmrepository.yaml": """\
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: lens
  namespace: flux-system
spec:
  interval: 10m
  url: https://k8slens.dev
""",
        "helmrelease.yaml": """\
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: lens-metrics
  namespace: kube-system
spec:
  interval: 10m
  chart:
    spec:
      chart: lens-metrics
      version: "latest"
      sourceRef:
        kind: HelmRepository
        name: lens
        namespace: flux-system
      interval: 5m
  install:
    remediation:
      retries: 3
  upgrade:
    remediation:
      retries: 3
""",
        "configmap.yaml": """\
apiVersion: v1
kind: ConfigMap
metadata:
  name: lens-config
  namespace: kube-system
data:
  cluster-metrics: "true"
  dashboard: "enabled"
""",
        "kustomization.yaml": """\
resources:
  - helmrepository.yaml
  - helmrelease.yaml
  - configmap.yaml
"""
    },
    "infrastructure/networking/traefik": {
        "helmrepository.yaml": """\
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: traefik
  namespace: flux-system
spec:
  interval: 10m
  url: https://helm.traefik.io/traefik
""",
        "helmrelease.yaml": """\
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: traefik
  namespace: kube-system
spec:
  interval: 10m
  chart:
    spec:
      chart: traefik
      version: "10.3.2"
      sourceRef:
        kind: HelmRepository
        name: traefik
        namespace: flux-system
  values:
    deployment:
      podAnnotations:
        "prometheus.io/scrape": "true"
        "prometheus.io/port": "8082"
    ports:
      web:
        redirectTo: websecure
      websecure:
        tls:
          enabled: true
    providers:
      kubernetesCRD: {}
      kubernetesIngress: {}
    certificatesResolvers:
      letsencrypt:
        acme:
          email: your-email@example.com
          storage: /data/acme.json
          httpChallenge:
            entryPoint: web
""",
        "kustomization.yaml": """\
resources:
  - helmrepository.yaml
  - helmrelease.yaml
"""
    },
    "apps/media/sonarr": {
        "deployment.yaml": """\
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sonarr
  namespace: media
spec:
  replicas: 1
  selector:
    matchLabels:
      app: sonarr
  template:
    metadata:
      labels:
        app: sonarr
    spec:
      containers:
        - name: sonarr
          image: linuxserver/sonarr:latest
          ports:
            - containerPort: 8989
          volumeMounts:
            - mountPath: "/config"
              name: config
            - mountPath: "/data/nfs"
              name: nfs-storage
            - mountPath: "/data/smb-e"
              name: smb-storage-e
      volumes:
        - name: config
          emptyDir: {}
        - name: nfs-storage
          persistentVolumeClaim:
            claimName: nfs-pvc
        - name: smb-storage-e
          persistentVolumeClaim:
            claimName: smb-pvc-e
""",
        "service.yaml": """\
apiVersion: v1
kind: Service
metadata:
  name: sonarr
  namespace: media
spec:
  ports:
    - port: 80
      targetPort: 8989
      protocol: TCP
      name: http
  selector:
    app: sonarr
  type: ClusterIP
""",
        "ingress.yaml": """\
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: sonarr
  namespace: media
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
    traefik.ingress.kubernetes.io/router.tls: "true"
    traefik.ingress.kubernetes.io/router.tls.certresolver: letsencrypt
spec:
  rules:
    - host: sonarr.hont.ro
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: sonarr
                port:
                  number: 80
""",
        "kustomization.yaml": """\
resources:
  - deployment.yaml
  - service.yaml
  - ingress.yaml
"""
    },
    "apps/media/radarr": {
        "deployment.yaml": """\
apiVersion: apps/v1
kind: Deployment
metadata:
  name: radarr
  namespace: media
spec:
  replicas: 1
  selector:
    matchLabels:
      app: radarr
  template:
    metadata:
      labels:
        app: radarr
    spec:
      containers:
        - name: radarr
          image: linuxserver/radarr:latest
          ports:
            - containerPort: 7878
          volumeMounts:
            - mountPath: "/config"
              name: config
            - mountPath: "/data/nfs"
              name: nfs-storage
            - mountPath: "/data/smb-e"
              name: smb-storage-e
      volumes:
        - name: config
          emptyDir: {}
        - name: nfs-storage
          persistentVolumeClaim:
            claimName: nfs-pvc
        - name: smb-storage-e
          persistentVolumeClaim:
            claimName: smb-pvc-e
""",
        "service.yaml": """\
apiVersion: v1
kind: Service
metadata:
  name: radarr
  namespace: media
spec:
  ports:
    - port: 80
      targetPort: 7878
      protocol: TCP
      name: http
  selector:
    app: radarr
  type: ClusterIP
""",
        "ingress.yaml": """\
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: radarr
  namespace: media
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
    traefik.ingress.kubernetes.io/router.tls: "true"
    traefik.ingress.kubernetes.io/router.tls.certresolver: letsencrypt
spec:
  rules:
    - host: radarr.hont.ro
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: radarr
                port:
                  number: 80
""",
        "kustomization.yaml": """\
resources:
  - deployment.yaml
  - service.yaml
  - ingress.yaml
"""
    },
    "apps/media/prowlarr": {
        "deployment.yaml": """\
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prowlarr
  namespace: media
spec:
  replicas: 1
  selector:
    matchLabels:
      app: prowlarr
  template:
    metadata:
      labels:
        app: prowlarr
    spec:
      containers:
        - name: prowlarr
          image: linuxserver/prowlarr:latest
          ports:
            - containerPort: 9696
          volumeMounts:
            - mountPath: "/config"
              name: config
            - mountPath: "/data/nfs"
              name: nfs-storage
            - mountPath: "/data/smb-e"
              name: smb-storage-e
      volumes:
        - name: config
          emptyDir: {}
        - name: nfs-storage
          persistentVolumeClaim:
            claimName: nfs-pvc
        - name: smb-storage-e
          persistentVolumeClaim:
            claimName: smb-pvc-e
""",
        "service.yaml": """\
apiVersion: v1
kind: Service
metadata:
  name: prowlarr
  namespace: media
spec:
  ports:
    - port: 80
      targetPort: 9696
      protocol: TCP
      name: http
  selector:
    app: prowlarr
  type: ClusterIP
""",
        "ingress.yaml": """\
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: prowlarr
  namespace: media
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
    traefik.ingress.kubernetes.io/router.tls: "true"
    traefik.ingress.kubernetes.io/router.tls.certresolver: letsencrypt
spec:
  rules:
    - host: prowlarr.hont.ro
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: prowlarr
                port:
                  number: 80
""",
        "kustomization.yaml": """\
resources:
  - deployment.yaml
  - service.yaml
  - ingress.yaml
"""
    },
    "apps/media/qbittorrent": {
        "deployment.yaml": """\
apiVersion: apps/v1
kind: Deployment
metadata:
  name: qbittorrent
  namespace: media
spec:
  replicas: 1
  selector:
    matchLabels:
      app: qbittorrent
  template:
    metadata:
      labels:
        app: qbittorrent
    spec:
      containers:
        - name: qbittorrent
          image: linuxserver/qbittorrent:latest
          ports:
            - containerPort: 8080
          volumeMounts:
            - mountPath: "/config"
              name: config
            - mountPath: "/data/nfs"
              name: nfs-storage
            - mountPath: "/data/smb-e"
              name: smb-storage-e
      volumes:
        - name: config
          emptyDir: {}
        - name: nfs-storage
          persistentVolumeClaim:
            claimName: nfs-pvc
        - name: smb-storage-e
          persistentVolumeClaim:
            claimName: smb-pvc-e
""",
        "service.yaml": """\
apiVersion: v1
kind: Service
metadata:
  name: qbittorrent
  namespace: media
spec:
  ports:
    - port: 80
      targetPort: 8080
      protocol: TCP
      name: http
  selector:
    app: qbittorrent
  type: ClusterIP
""",
        "ingress.yaml": """\
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: qbittorrent
  namespace: media
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
    traefik.ingress.kubernetes.io/router.tls: "true"
    traefik.ingress.kubernetes.io/router.tls.certresolver: letsencrypt
spec:
  rules:
    - host: qbittorrent.hont.ro
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: qbittorrent
                port:
                  number: 80
""",
        "kustomization.yaml": """\
resources:
  - deployment.yaml
  - service.yaml
  - ingress.yaml
"""
    },
    "README.md": """\
# Homelab GitOps Repository

## Overview
This repository manages a Kubernetes homelab using FluxCD for GitOps automation. It deploys:

- **Media Applications:** Sonarr, Radarr, Prowlarr, and qBittorrent  
  Each application mounts persistent storage from:
  - **NFS** (nas.hont.ro/complete)
  - **SMB/Windows Share** (l2.hont.ro/E)

- **SMB CSI Driver:** Managed via a HelmRelease  
- **Traefik Reverse Proxy:** Routes HTTPS requests (with Let's Encrypt TLS) based on subdomains (e.g. `sonarr.hont.ro`)  
- **Lens:** For cluster monitoring and insights

**Note:**  
- The public domain **hont.ro** is not pointed to the homelab, but local DNS resolves subdomains such as `sonarr.hont.ro` to the cluster.  
- Traefik uses an ACME HTTP challenge to obtain valid certificates from Let's Encrypt. Ensure your challenge configuration is compatible with your network setup (or consider using a DNS challenge if needed).

## Folder Structure
