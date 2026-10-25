# Canary deployment

> Send a **small fraction** of traffic to a new version first; increase only if error rate, latency, and logs look healthy.

## Introduction

Unlike blue/green (all-or-nothing cutover), canary releases expose a subset of users to v2. A plain Kubernetes Service load-balances across matching endpoints roughly by Pod count—it does **not** guarantee precise 90/10 weights. Production canaries often use Gateway API, Ingress controllers, or a service mesh with weighted routing.

## Explanation

Signals to check before increasing canary traffic:

- **Error rate** — more 5xx on canary?
- **Latency** — slower than stable?
- **Logs** — exceptions filtered by canary labels

Interview takeaway: Pod `Running`/`Ready` does not prove the release is healthy for users. Pair this lab with [Prometheus](prometheus_stack.md).

## Architecture / flow

```text
Client traffic
      |
 Routing / Service
   /        \
 ~90%       ~10%
  |          |
Stable      Canary
  v1         v2
```

## Official references

- [Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/) (Kubernetes)
- [Service](https://kubernetes.io/docs/concepts/services-networking/service/) (Kubernetes)
- [Gateway API](https://gateway-api.sigs.k8s.io/) (weighted routes — advanced)

## Lab setup

From the **repo root**:

```powershell
kubectl get nodes
kubectl get deployments,services

kubectl apply -f manifests/canary-lab.yaml
kubectl rollout status deployment/app-stable
kubectl rollout status deployment/app-canary
kubectl get pods -l app=canary-demo --show-labels
kubectl get endpoints canary-demo

kubectl run canary-client --image=curlimages/curl:8.12.1 --restart=Never --command -- sleep 3600
kubectl wait --for=condition=Ready pod/canary-client --timeout=90s

$results = 1..20 | ForEach-Object {
  kubectl exec canary-client -- curl -s http://canary-demo
}
$results | Group-Object | Select-Object Name, Count

kubectl scale deployment app-canary --replicas=2
kubectl rollout status deployment/app-canary
kubectl get pods -l app=canary-demo --show-labels
```

## Cleanup

```powershell
kubectl delete -f manifests/canary-lab.yaml --ignore-not-found
kubectl delete pod canary-client --ignore-not-found
kubectl get deployments,services,pods
```
