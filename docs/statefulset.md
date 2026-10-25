# StatefulSet

> Stable network identity (`web-0`, `web-1`, …), ordered deploy/scale, and (usually) per-Pod storage. This lab mounts a **shared EFS PVC** to demonstrate RWX.

## Introduction

A [StatefulSet](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/) manages stateful applications. It requires a governing [headless Service](https://kubernetes.io/docs/concepts/services-networking/service/#headless-services) (`clusterIP: None`) referenced by `spec.serviceName`.

## Explanation

- Ordinal Pod names and stable DNS: `web-0.web.default.svc.cluster.local`.
- Production apps often use `volumeClaimTemplates` for one PVC per Pod.
- This lab shares `efs-pvc` (see [storage.md](storage.md)) instead of per-Pod EBS claims.

## Architecture / flow

```text
Client / peer
      |
      v
Headless Service (web)
      |
  web-0   web-1
      \     /
       efs-pvc (ReadWriteMany)
```

## Official references

- [StatefulSets](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/) (Kubernetes)
- [Headless Services](https://kubernetes.io/docs/concepts/services-networking/service/#headless-services) (Kubernetes)

## Lab setup

Prerequisites: the cluster's EFS CSI add-on and EFS PV/PVC bound ([storage.md](storage.md)). The Terraform setup in this repository provisions EFS and its mount targets; substitute its output into the PV manifest before applying it.

From the **repo root**:

```powershell
kubectl apply -f manifests/efs-pv.yaml
kubectl apply -f manifests/efs-pvc.yaml
kubectl get pvc efs-pvc

@'
apiVersion: v1
kind: Service
metadata:
  name: web
spec:
  clusterIP: None
  selector:
    app: nginx
  ports:
    - port: 80
      name: http
'@ | kubectl apply -f -

kubectl apply -f manifests/statefulset.yaml
kubectl get statefulset web
kubectl get pods -l app=nginx -o wide

kubectl exec web-0 -- sh -c "echo hello-from-web-0 > /shared/note.txt"
kubectl exec web-1 -- cat /shared/note.txt
```

## Cleanup

```powershell
kubectl delete -f manifests/statefulset.yaml --ignore-not-found
kubectl delete svc web --ignore-not-found
# Delete EFS PVC/PV only if no other lab needs them
```
