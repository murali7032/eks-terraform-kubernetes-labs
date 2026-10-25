# Kubernetes workloads and Services

> Learn how Pods, Deployments, ReplicaSets, labels, and Services fit together before moving to the focused labs.

## Core objects

- **Pod:** the smallest schedulable unit; one or more closely coupled containers share networking and volumes.
- **Deployment:** declares a desired number of interchangeable Pods and manages rollout/rollback through ReplicaSets.
- **Service:** gives a changing set of Pods a stable virtual IP and DNS name, selected by labels.
- **Namespace:** scopes names and many policies; it is not a strong security boundary by itself.

```text
Deployment ──owns──▶ ReplicaSet ──creates──▶ Pods
                                                ▲
Service ──selects matching labels───────────────┘
```

## Lab

From the repository root:

```powershell
kubectl create namespace workloads-lab
kubectl create deployment web --image=nginx:1.27 --replicas=2 -n workloads-lab
kubectl expose deployment web --port=80 --target-port=80 -n workloads-lab
kubectl get deploy,rs,pods,svc -n workloads-lab -o wide
kubectl get endpointslices -n workloads-lab
kubectl run client --image=curlimages/curl:8.10.1 --restart=Never -n workloads-lab -- curl -sS http://web
kubectl wait --for=jsonpath='{.status.phase}'=Succeeded pod/client -n workloads-lab --timeout=120s
kubectl logs client -n workloads-lab
```

Inspect the selectors and labels:

```powershell
kubectl get service web -n workloads-lab -o yaml
kubectl get pods -n workloads-lab --show-labels
kubectl describe service web -n workloads-lab
```

Change the image and observe a rolling update, then undo it:

```powershell
kubectl set image deployment/web nginx=nginx:1.26 -n workloads-lab
kubectl rollout status deployment/web -n workloads-lab
kubectl rollout history deployment/web -n workloads-lab
kubectl rollout undo deployment/web -n workloads-lab
```

## Expected result

The Deployment should reach two ready replicas. The Service should have endpoints, and the temporary client should receive the default NGINX page. If endpoints are empty, compare the Service selector with Pod labels.

## Cleanup

```powershell
kubectl delete namespace workloads-lab
```

## References

- [Pods](https://kubernetes.io/docs/concepts/workloads/pods/)
- [Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- [Services](https://kubernetes.io/docs/concepts/services-networking/service/)
