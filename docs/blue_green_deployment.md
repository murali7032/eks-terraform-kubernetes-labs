# Blue / green deployment (Service selector switch)

> Run two versions side by side; flip a Service selector to move **all** traffic from blue to green (or back).

## Introduction

Blue/green keeps an old (“blue”) and new (“green”) stack available. Traffic shifts by changing routing—here, a Kubernetes [Service](https://kubernetes.io/docs/concepts/services-networking/service/) `selector`—instead of a gradual rollout. This is a teaching pattern; production also needs readiness, data compatibility, and a rollback plan.

## Explanation

- Two Deployments share an app label family but differ on `version=blue|green`.
- The Service selects one version at a time.
- Patching the Service selector cuts over traffic atomically (from the Service’s point of view).
- Related official rollout tooling: [Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/) rolling updates (different strategy).

## Architecture / flow

```text
              Client
                |
             Service
                |
       selector: version=blue
                |
       +--------+--------+
       |                 |
   Blue Pods         Green Pods
   (live)            (standby)
```

## Official references

- [Service](https://kubernetes.io/docs/concepts/services-networking/service/) (Kubernetes)
- [Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/) (Kubernetes)
- [Performing a Rolling Update](https://kubernetes.io/docs/tutorials/kubernetes-basics/update/update-intro/) (Kubernetes)

## Lab setup

From the **repo root**:

```powershell
kubectl apply -f manifests/blue-green.yaml
kubectl rollout status deployment/app-blue
kubectl rollout status deployment/app-green

kubectl port-forward service/app-service 8080:80
# Browse or curl http://localhost:8080

kubectl get endpointslice -l kubernetes.io/service-name=app-service
```

To switch colors, patch the Service selector from `blue` to `green` (inspect the Service in the manifest for exact labels).

## Cleanup

```powershell
kubectl delete -f manifests/blue-green.yaml
```
