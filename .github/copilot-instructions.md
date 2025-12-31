# GitHub Copilot Instructions for Homelab Repository

## Repository Structure

This repository follows a Flux GitOps pattern for managing Kubernetes workloads in a homelab environment.

### Expected Directory Layout

```
homelab/
├── clusters/              # Flux cluster configurations
│   ├── production/        # Production cluster (primary homelab)
│   └── staging/           # Optional staging/test cluster
├── apps/                  # Application definitions
│   ├── base/             # Base configurations (shared across clusters)
│   └── overlays/         # Environment-specific overlays
├── infrastructure/        # Infrastructure components (ingress, cert-manager, etc.)
└── .github/              # GitHub configuration and workflows
```

### Adding New Applications

When adding a new application:

1. Create a directory under `apps/base/<app-name>/`
2. Add the base Kubernetes manifests or HelmRelease
3. If environment-specific config is needed, create overlays in `apps/overlays/<cluster>/<app-name>/`
4. Reference the app in the appropriate cluster's `kustomization.yaml` under `clusters/<cluster>/`

Example structure for a new app:
```
apps/
├── base/
│   └── my-app/
│       ├── kustomization.yaml
│       ├── namespace.yaml
│       ├── deployment.yaml
│       └── service.yaml
└── overlays/
    └── production/
        └── my-app/
            ├── kustomization.yaml
            └── patch-deployment.yaml
```

## Preferred Patterns

### Manifest Types (Priority Order)

1. **HelmRelease (Preferred for complex apps)**: Use Flux's HelmRelease CRD for applications with existing Helm charts
   ```yaml
   apiVersion: helm.toolkit.fluxcd.io/v2beta1
   kind: HelmRelease
   metadata:
     name: my-app
     namespace: my-app
   spec:
     chart:
       spec:
         chart: my-app
         sourceRef:
           kind: HelmRepository
           name: my-repo
   ```

2. **Kustomize (Preferred for custom apps)**: Use Kustomize for organizing and patching custom manifests
   - Always include a `kustomization.yaml` in each directory
   - Use `commonLabels` and `commonAnnotations` for consistency
   - Use patches for environment-specific changes

3. **Raw Manifests**: Acceptable for simple, one-off resources
   - Always include proper labels and annotations
   - Must still be referenced in a `kustomization.yaml`

### Resource Organization

- One namespace per application (except for shared infrastructure)
- Use consistent naming: `<app-name>-<resource-type>` (e.g., `nginx-deployment`)
- Always specify resource requests and limits
- Include health checks (readiness and liveness probes) for all deployments

## Secrets Handling

**CRITICAL: Never commit real secrets to this repository.**

### Secrets Management Strategy

1. **Placeholder Secrets**: For initial setup or examples, use placeholder secrets with documentation
   ```yaml
   apiVersion: v1
   kind: Secret
   metadata:
     name: my-app-secret
   stringData:
     # PLACEHOLDER: Replace with actual values using SOPS or SealedSecrets
     # Required keys:
     # - API_KEY: Application API key
     # - DB_PASSWORD: Database password
     API_KEY: "CHANGEME"
     DB_PASSWORD: "CHANGEME"
   ```

2. **Secret Encryption**: If SOPS or SealedSecrets is configured:
   - Follow existing patterns in the repository
   - Encrypt secrets before committing
   - Document the encryption method in comments

3. **External Secrets**: If ExternalSecrets Operator is used:
   - Use ExternalSecret CRDs referencing the external secret store
   - Document required secret keys in comments

4. **Secret Documentation**: Always document:
   - Required secret keys
   - Expected format/type
   - How to create/populate the secret in production

## PR Hygiene

### Commit Guidelines

- **Small, focused changes**: Each PR should address one concern
- **Descriptive commits**: Use conventional commit format
  - `feat: add nginx ingress controller`
  - `fix: correct replica count for postgres`
  - `docs: update README with new app instructions`
  - `chore: update helm chart version`
- **Reference issues**: Include `Closes #X` or `Fixes #X` in PR description

### PR Description Requirements

Every PR must include:
1. **What**: What changes are being made
2. **Why**: Why these changes are necessary
3. **Validation**: Steps taken to validate the changes (see below)
4. **Breaking changes**: Any breaking changes or manual steps required

### Pre-PR Checklist

Before opening a PR:
- [ ] Changes are minimal and focused
- [ ] No real secrets are committed
- [ ] All validation steps pass (see Validation section)
- [ ] Documentation is updated if needed
- [ ] Commit messages are clear and descriptive

## Validation Steps

Run the following validation steps before submitting a PR:

### 1. Kustomize Build Validation

```bash
# Validate each cluster configuration builds successfully
kustomize build clusters/production/ > /dev/null && echo "✓ Production cluster valid" || echo "✗ Production cluster failed"
kustomize build clusters/staging/ > /dev/null && echo "✓ Staging cluster valid" || echo "✗ Staging cluster failed"

# Validate specific app overlays
kustomize build apps/overlays/production/my-app/ > /dev/null && echo "✓ App overlay valid" || echo "✗ App overlay failed"

# Or to see the output for debugging
kustomize build clusters/production/
```

### 2. YAML Linting (if yamllint is available)

```bash
# Lint all YAML files
yamllint -c .yamllint.yaml .

# Or lint specific files
yamllint clusters/ apps/ infrastructure/
```

### 3. Kubernetes Schema Validation (if kubeconform is available)

```bash
# Validate generated manifests against Kubernetes schemas
kustomize build clusters/production/ | kubeconform -strict -ignore-missing-schemas

# Or using kubeval (alternative)
kustomize build clusters/production/ | kubeval --strict --ignore-missing-schemas
```

### 4. Helm Linting (for HelmRelease resources)

```bash
# If adding or modifying a helm chart
helm lint charts/my-chart/

# Dry-run to validate
helm template my-release charts/my-chart/ --values values.yaml
```

### 5. Flux Validation (if Flux CLI is available)

```bash
# Validate Flux resources
flux check

# Check if kustomization would reconcile
flux diff kustomization flux-system --path=clusters/production/
```

### 6. Manual Verification

- Review all changes with `git diff`
- Verify no secrets are exposed: `git diff | grep -iE "password|secret|token|key|api[-_]?key"`
  - Note: For comprehensive secret detection, consider tools like `git-secrets` or `truffleHog`
  - Check for base64-encoded secrets: `git diff | grep -E "[A-Za-z0-9+/]{20,}={0,2}"`
- Check for debugging artifacts or temporary changes

## Cloudflare Tunnel Ingress

If this homelab uses Cloudflare Tunnel for ingress:

### Adding a New Ingress Route

1. **Create Kubernetes Ingress resource**:
   ```yaml
   apiVersion: networking.k8s.io/v1
   kind: Ingress
   metadata:
     name: my-app
     annotations:
       # Note: alpha annotation may change in future ExternalDNS versions
       external-dns.alpha.kubernetes.io/cloudflare-proxied: "true"
   spec:
     ingressClassName: cloudflare-tunnel
     rules:
     - host: my-app.example.com
       http:
         paths:
         - path: /
           pathType: Prefix
           backend:
             service:
               name: my-app
               port:
                 number: 80
   ```

2. **Cloudflare Tunnel Configuration**:
   - If using cloudflared ingress controller, the tunnel mapping is automatic
   - If manual configuration is needed, update the Cloudflare Tunnel config in `infrastructure/cloudflare/` or via Cloudflare dashboard

3. **DNS Configuration**:
   - If ExternalDNS is configured, DNS records are managed automatically
   - Otherwise, manually add CNAME record pointing to the tunnel

### Verification

- Confirm the ingress resource is created: `kubectl get ingress -n <namespace>`
- Check cloudflared logs for tunnel connections
- Test external access: `curl https://my-app.example.com`

## General Best Practices

### Kubernetes Resources

- **Namespaces**: Create dedicated namespaces for logical separation
- **Labels**: Use consistent labels for all resources:
  ```yaml
  labels:
    app.kubernetes.io/name: my-app
    app.kubernetes.io/instance: my-app-production
    app.kubernetes.io/component: backend
    app.kubernetes.io/managed-by: flux
  ```
- **Resource Limits**: Always define requests and limits
- **Security**: Run containers as non-root when possible
- **Health Checks**: Include readiness and liveness probes

### Flux/GitOps

- Keep Flux system resources in `clusters/<cluster>/flux-system/`
- Use Flux's `dependsOn` field for resource ordering
- Set appropriate `interval` for Kustomization and HelmRelease reconciliation
- Use `prune: true` to remove deleted resources
- Tag sensitive resources with `sops.toolkit.fluxcd.io/managed: "true"` if using SOPS

### Documentation

- Update README.md when adding major components
- Document any manual steps required for new applications
- Keep this copilot-instructions.md file updated as patterns evolve

## Common Operations

### Updating a Helm Chart Version

```yaml
# In HelmRelease spec
spec:
  chart:
    spec:
      version: "1.2.3"  # Update this version
```

### Adding a ConfigMap

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: my-app-config
  namespace: my-app
data:
  config.yaml: |
    # Your configuration here
```

### Scaling a Deployment

```yaml
# In deployment spec or as a patch
spec:
  replicas: 3
```

## Questions or Issues?

- Check existing apps for patterns and examples
- Review Flux documentation: https://fluxcd.io/docs/
- Consult Kubernetes documentation for resource specifications
- Open an issue for questions about repository structure or conventions
