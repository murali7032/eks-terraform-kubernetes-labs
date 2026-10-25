# Pod affinity, anti-affinity, and topology spread

> Control **where** Pods land relative to other Pods and topology domains (nodes, zones)—for HA and packing.

## Introduction

The scheduler supports [inter-pod affinity and anti-affinity](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#inter-pod-affinity-and-anti-affinity) and [topology spread constraints](https://kubernetes.io/docs/concepts/scheduling-eviction/topology-spread-constraints/). Anti-affinity keeps matching Pods apart; topology spread keeps replica counts even across domains.

## Explanation

### Pod anti-affinity

- `labelSelector` — which Pods to consider.
- `topologyKey` — domain boundary (e.g. `kubernetes.io/hostname` = node).
- `requiredDuringSchedulingIgnoredDuringExecution` — hard rule; Pods stay **Pending** if unmet.
- Soft rules use `preferredDuringSchedulingIgnoredDuringExecution`.

### Topology spread

- `maxSkew` — max allowed difference in matching Pod counts across domains.
- `whenUnsatisfiable`: `DoNotSchedule` (hard) or `ScheduleAnyway` (soft).
- `labelSelector` — which Pods count toward the skew.

## Architecture / flow

```text
Anti-affinity (hostname):
  Pod A on node-1  ⇒  matching Pod B prefers/requires another node

Topology spread (maxSkew=1, hostname):
  node-1: 2 Pods
  node-2: 2 Pods
  node-3: 1 Pod   ← next Pod prefers node-3
```

## Official references

- [Assigning Pods to Nodes](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/) (Kubernetes)
- [Pod Topology Spread Constraints](https://kubernetes.io/docs/concepts/scheduling-eviction/topology-spread-constraints/) (Kubernetes)

## Lab setup

From the **repo root**.

### Anti-affinity

```powershell
kubectl apply -f manifests/pod-antiaffinity.yaml
kubectl get pods -l app=spread-demo -o wide
kubectl get deployment spread-demo -o yaml
```

### Topology spread

```powershell
kubectl apply -f manifests/topology-spread.yaml
kubectl get pods -l app=topology-demo -o wide

kubectl scale deployment topology-demo --replicas=5
kubectl get pods -l app=topology-demo -o wide
```

## Cleanup

```powershell
kubectl delete -f manifests/topology-spread.yaml --ignore-not-found
kubectl delete -f manifests/pod-antiaffinity.yaml --ignore-not-found
```
