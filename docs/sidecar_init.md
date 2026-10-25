# Init containers and sidecars

> **Init containers** run to completion before app containers start. **Sidecars** run alongside the main app in the same Pod (shared network and volumes).

## Introduction

A Pod can define [init containers](https://kubernetes.io/docs/concepts/workloads/pods/init-containers/) that run sequentially before application containers. Sidecar-style containers (logging, proxies, agents) share the Pod’s network namespace (`localhost`) and can share volumes. Kubernetes also documents [native sidecar containers](https://kubernetes.io/docs/concepts/workloads/pods/sidecar-containers/) (restartable init containers) in recent versions; this lab uses a classic multi-container Pod pattern.

## Explanation

- Init containers must **succeed** before the next init (or app) container starts.
- Useful for: wait-for-dependency, schema setup, seeding files.
- Sidecars are normal containers in `spec.containers` that support the main process.
- Containers in one Pod share the same IP and can use `localhost`.

## Architecture / flow

```text
Pod
 ├── Init: setup              (must complete)
 │       ↓
 ├── Init: wait for dependency (must complete)
 │       ↓
 └── App containers start
      ├── Main application
      └── Sidecar (parallel)
```

## Official references

- [Init Containers](https://kubernetes.io/docs/concepts/workloads/pods/init-containers/) (Kubernetes)
- [Sidecar Containers](https://kubernetes.io/docs/concepts/workloads/pods/sidecar-containers/) (Kubernetes)
- [Pods](https://kubernetes.io/docs/concepts/workloads/pods/) (Kubernetes)

## Lab setup

From the **repo root**.

### Init demo

```powershell
kubectl apply -f manifests/init-demo.yaml
kubectl get pod init-demo
kubectl port-forward pod/init-demo 8080:80
# In another terminal:
curl.exe http://localhost:8080
kubectl exec init-demo -c app -- cat /usr/share/nginx/html/index.html
```

### Sidecar demo

```powershell
kubectl apply -f manifests/sidecar-demo.yaml
kubectl get pod sidecar-demo
```

## Cleanup

```powershell
kubectl delete -f manifests/sidecar-demo.yaml --ignore-not-found
kubectl delete -f manifests/init-demo.yaml --ignore-not-found
```
