# k8s-homelab Project

This project sets up a Kubernetes homelab environment using Traefik as the Ingress controller. It includes configurations for deploying Traefik, obtaining SSL certificates from Let's Encrypt, and exposing services like qBittorrent through Ingress resources.

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

1. **Install Kubernetes**: Ensure you have a Kubernetes cluster running. You can use Minikube, Kind, or any other Kubernetes setup.

2. **Install Kustomize**: Make sure you have Kustomize installed to manage the Kubernetes manifests.

3. **Deploy Traefik**:
   - Navigate to the `traefik` directory.
   - Run the following command to apply the Kustomization:
     ```
     kubectl apply -k .
     ```

4. **Configure DNS**:
   - Follow the instructions in the `dns/README.md` file to set up a local DNS solution or configure your `/etc/hosts` file for domain resolution.

5. **Access Services**:
   - Once Traefik is deployed, you can access your services through the configured Ingress resources.

## Additional Notes

- This project uses Let's Encrypt in staging mode for testing purposes. Make sure to switch to production mode for live deployments.
- Ensure that your Kubernetes cluster has access to the internet for certificate issuance.

For more detailed instructions on each component, refer to the respective files in the `traefik` directory.