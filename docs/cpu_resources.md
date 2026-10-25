# CPU and memory requests / limits

> **Requests** drive scheduling; **limits** cap runtime usage. CPU is compressible (throttling); memory is not (OOMKill).

## Introduction

Kubernetes [resource management](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/) lets each container declare `resources.requests` and `resources.limits` for CPU and memory. The scheduler places Pods using **requests**. The kubelet (and cgroup) enforces **limits**.

## Explanation


| Field                              | Role                                            |
| ---------------------------------- | ----------------------------------------------- |
| `requests.cpu` / `requests.memory` | Minimum the scheduler reserves on a node        |
| `limits.cpu`                       | Max CPU; excess → throttling                    |
| `limits.memory`                    | Max memory; excess → container may be OOMKilled |


- Prefer setting **requests** for predictable packing.
- `kubectl top` needs [Metrics Server](https://kubernetes.io/docs/tasks/debug/debug-cluster/resource-metrics-pipeline/).

## Architecture / flow

```text
Pod
 └── container
      requests: cpu 100m, memory 64Mi  → scheduling
      limits:   cpu 200m, memory 128Mi → runtime cap
```

## Official references

- [Resource Management for Pods and Containers](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/) (Kubernetes)
- [Assign Memory Resources to Containers and Pods](https://kubernetes.io/docs/tasks/configure-pod-container/assign-memory-resource/) (Kubernetes)
- [Assign CPU Resources to Containers and Pods](https://kubernetes.io/docs/tasks/configure-pod-container/assign-cpu-resource/) (Kubernetes)

## Lab setup

From the **repo root**:

```powershell
kubectl apply -f manifests/cpu-demo.yaml
kubectl get pods -l app=cpu-demo -o wide
kubectl describe pod -l app=cpu-demo
kubectl top pod -l app=cpu-demo
```

Optional: edit `manifests/cpu-demo.yaml` to a busy CPU loop, re-apply, and compare `kubectl top` / events under the CPU limit.

## Cleanup

```powershell
kubectl delete -f manifests/cpu-demo.yaml
```

