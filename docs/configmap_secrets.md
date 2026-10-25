# ConfigMaps and Secrets

> Store non-sensitive configuration in ConfigMaps and sensitive values in Secrets, then observe how Pods consume each object.

## Concepts

- Environment variables sourced from either object are fixed when a container starts; restart the Pod to pick up changes.
- A ConfigMap or Secret mounted as a volume is eventually refreshed by kubelet (with propagation delay), unless mounted using `subPath`.
- Kubernetes Secrets are base64 encoded in API representations. Base64 is not encryption. Restrict RBAC access and enable encryption at rest for production clusters.
- Never commit real credentials or put them in command history. This exercise reads a disposable password from a local file that must not be committed.

## Lab

From the repository root, create the non-sensitive ConfigMap and a local secret file:

```powershell
kubectl create configmap app-config --from-literal=APP_ENV=dev --from-literal=LOG_LEVEL=info
New-Item -ItemType Directory -Force local-secrets | Out-Null
Read-Host "Enter a disposable lab password" | Set-Content -NoNewline local-secrets\db-password.txt
kubectl create secret generic app-secret --from-file=DB_PASSWORD=local-secrets\db-password.txt
kubectl apply -f manifests/config-secret-demo.yaml
kubectl get pod config-secret-demo -w
```

Inspect references and keys without printing the secret value:

```powershell
kubectl describe configmap app-config
kubectl describe secret app-secret
kubectl get pod config-secret-demo -o yaml
```

To demonstrate refresh behavior, update the ConfigMap and compare a running Pod's environment with a newly created Pod. Mounted files update after a short delay; environment variables do not update until the container restarts.

## Cleanup

```powershell
kubectl delete -f manifests/config-secret-demo.yaml --ignore-not-found
kubectl delete configmap app-config --ignore-not-found
kubectl delete secret app-secret --ignore-not-found
Remove-Item local-secrets\db-password.txt -ErrorAction SilentlyContinue
```

## References

- [ConfigMaps](https://kubernetes.io/docs/concepts/configuration/configmap/)
- [Secrets](https://kubernetes.io/docs/concepts/configuration/secret/)
- [Secret good practices](https://kubernetes.io/docs/concepts/security/secrets-good-practices/)
