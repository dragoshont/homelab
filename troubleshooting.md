# Troubleshooting AKS Edge Essentials Connectivity Issues

## Steps to Resolve `kubectl get pvc` Connection Refused Error

1. **Verify AKS Edge Essentials is running**:
   Ensure your AKS Edge Essentials cluster is up and running using the management tools.

2. **Check `kubectl` configuration**:
   ```sh
   kubectl config get-contexts
   kubectl config use-context <your-cluster-context>
   ```

3. **Restart AKS Edge Essentials**:
   Use the AKS Edge Essentials management tools to restart the cluster if it is not running.

4. **Check network connectivity**:
   Verify there are no network issues preventing `kubectl` from connecting to the cluster.

5. **Verify `kubectl` version**:
   ```sh
   kubectl version --client
   ```

If the issue persists, check the AKS Edge Essentials logs for further troubleshooting.
