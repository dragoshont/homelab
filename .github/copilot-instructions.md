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

## Managing Homelab Dependencies

When adding or updating tools and dependencies required for the homelab environment, use platform-specific automation:

### Linux Machines

Use **Ansible** to manage dependencies and configuration:

1. Create or update Ansible playbooks in an `ansible/` directory
2. Organize playbooks by function (e.g., `bootstrap.yml`, `kubernetes.yml`, `monitoring.yml`)
3. Use roles for reusable components
4. Document required variables in the playbook or a `README.md`

Example structure:
```
ansible/
├── inventory/
│   ├── hosts.yml
│   └── group_vars/
├── playbooks/
│   ├── bootstrap.yml
│   ├── kubernetes-setup.yml
│   └── install-dependencies.yml
├── roles/
│   ├── docker/
│   ├── kubectl/
│   └── flux/
└── ansible.cfg
```

Example playbook task:
```yaml
- name: Install kubectl
  ansible.builtin.get_url:
    url: https://dl.k8s.io/release/v1.28.0/bin/linux/amd64/kubectl
    dest: /usr/local/bin/kubectl
    mode: '0755'
  # Alternative: Use package manager with appropriate repository
  # ansible.builtin.package:
  #   name: kubectl
  #   state: present
```

### Windows Machines

Use **PowerShell Desired State Configuration (DSC)** or **PowerShell scripts** to manage dependencies:

1. **Preferred: PowerShell DSC** for declarative configuration
   - Create DSC configurations in a `dsc/` directory
   - Use built-in or community DSC resources
   - Document prerequisites and how to apply configurations

2. **Alternative: PowerShell scripts** for imperative setup
   - Create PowerShell scripts in a `scripts/windows/` directory
   - Use `Install-Module` for PowerShell modules
   - Use `winget install` or `choco install` for package management (prefer winget when available)
   - Include error handling and idempotency checks

Example structure:
```
scripts/
├── windows/
│   ├── Install-HomelabDependencies.ps1
│   ├── Install-KubernetesTools.ps1
│   └── README.md
└── dsc/
    ├── HomelabConfig.ps1
    └── README.md
```

Example PowerShell script:
```powershell
# Install-HomelabDependencies.ps1
#Requires -RunAsAdministrator

# Check if winget is available (Windows 11 or Windows 10 with App Installer)
if (Get-Command winget -ErrorAction SilentlyContinue) {
    # Install dependencies using winget
    winget install --id Kubernetes.kubectl --exact --accept-source-agreements --accept-package-agreements
    winget install --id FluxCD.Flux --exact --accept-source-agreements --accept-package-agreements
}
else {
    Write-Warning "winget not found. Install 'App Installer' from Microsoft Store or use Chocolatey as fallback."
    # Fallback to Chocolatey if needed
    if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Host "Installing Chocolatey..."
        Set-ExecutionPolicy RemoteSigned -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-RestMethod -Uri 'https://community.chocolatey.org/install.ps1' -UseBasicParsing | Invoke-Expression
    }
    choco install -y kubernetes-cli flux
}
```

### General Guidelines

- **Document dependencies**: Maintain a list of required tools and versions in the repository README or a dedicated `DEPENDENCIES.md` file
- **Version pinning**: Pin specific versions in automation scripts to ensure reproducibility
- **Idempotency**: Ensure scripts can be run multiple times safely without causing issues
- **Testing**: Test automation scripts in a clean environment before committing
- **Cross-platform note**: If a tool is needed on both platforms, document installation for both

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

**CRITICAL: Never commit real secrets, credentials, or sensitive endpoints to this repository.**

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
   - **Critical for endpoints**: Never hardcode application endpoints, API URLs, or connection strings in YAML files
   - Store sensitive configuration in GitHub Secrets or other secret stores:
     - Application API endpoints
     - Database connection strings
     - External service URLs
     - Webhook endpoints
     - OAuth callback URLs
   
   Example ExternalSecret referencing GitHub secret:
   ```yaml
   apiVersion: external-secrets.io/v1beta1
   kind: ExternalSecret
   metadata:
     name: app-endpoints
     namespace: my-app
   spec:
     refreshInterval: 1h
     secretStoreRef:
       name: github-secret-store
       kind: SecretStore
     target:
       name: app-endpoints-secret
     data:
     - secretKey: API_ENDPOINT
       remoteRef:
         key: MY_APP_API_ENDPOINT
     - secretKey: WEBHOOK_URL
       remoteRef:
         key: MY_APP_WEBHOOK_URL
   ```

4. **Secret Documentation**: Always document:
   - Required secret keys
   - Expected format/type
   - How to create/populate the secret in production
   - Which GitHub Secrets need to be configured

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
  - Note: For comprehensive secret detection, consider tools like:
    - `git-secrets`: https://github.com/awslabs/git-secrets
    - `TruffleHog`: https://github.com/trufflesecurity/trufflehog
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
       # Note: This annotation is in alpha. Verify current annotation format in ExternalDNS docs
       # ExternalDNS: https://github.com/kubernetes-sigs/external-dns
       # Cloudflare provider: https://github.com/kubernetes-sigs/external-dns/blob/master/docs/tutorials/cloudflare.md
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
