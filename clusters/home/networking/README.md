# k8s-homelab Project

This project sets up a Kubernetes homelab environment using Traefik as the Ingress controller. It includes configurations for deploying Traefik, obtaining SSL certificates from Let's Encrypt, and exposing services like qBittorrent through Ingress resources.

## Prerequisites

1. **Kubernetes Cluster**: Ensure you have a Kubernetes cluster running (e.g., MicroK8s, Minikube, Kind, etc.).
2. **kubectl**: Install `kubectl` to interact with your Kubernetes cluster.
3. **Kustomize**: Install Kustomize to manage Kubernetes manifests.
4. **Helm**: Install Helm to deploy Cert-Manager and other Helm-based applications:
   - Download and install Helm from the [official Helm website](https://helm.sh/docs/intro/install/).
   - For Linux/macOS:
     ```bash
     curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
     ```
   - For Windows (using Chocolatey):
     ```bash
     choco install kubernetes-helm
     ```
   - Verify the installation:
     ```bash
     helm version
     ```
5. **Cert-Manager**: Deploy Cert-Manager in your cluster to handle SSL certificates:
   - Install Cert-Manager CRDs:
     ```bash
     kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.12.0/cert-manager.crds.yaml
     ```
   - Deploy Cert-Manager using Helm:
     ```bash
     helm repo add jetstack https://charts.jetstack.io
     helm repo update
     helm install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace --version v1.12.0
     ```
6. **DNS Configuration**: Set up a local DNS solution or configure your `/etc/hosts` file for domain resolution.

## Project Structure

```
k8s-homelab
├── traefik
│   ├── kustomization.yaml       # Kustomize configuration for Traefik
│   ├── deployment.yaml          # Traefik deployment configuration
│   ├── clusterissuer.yaml       # ClusterIssuer for Let's Encrypt
│   └── ingress-qbittorrent.yaml # Ingress resource for qBittorrent
├── README.md                    # Project documentation
└── dns
    └── README.md                # DNS management instructions
```

## Setup Instructions

1. **Deploy Traefik**:
   - Navigate to the `traefik` directory.
   - Run the following command to apply the Kustomization:
     ```bash
     kubectl apply -k .
     ```

2. **Configure DNS**:
   - Follow the instructions in the `dns/README.md` file to set up a local DNS solution or configure your `/etc/hosts` file for domain resolution.

3. **Access Services**:
   - Once Traefik is deployed, you can access your services through the configured Ingress resources.

## Additional Notes

- This project uses Let's Encrypt in staging mode for testing purposes. Make sure to switch to production mode for live deployments.
- Ensure that your Kubernetes cluster has access to the internet for certificate issuance.

For more detailed instructions on each component, refer to the respective files in the `traefik` directory.