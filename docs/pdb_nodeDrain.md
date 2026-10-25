# PodDisruptionBudget and node drain

> A **PDB** limits how many Pods of an app can be down at once during **voluntary** disruptions (for example `kubectl drain`). It does not protect against node crashes.

## Introduction

[PodDisruptionBudgets](https://kubernetes.io/docs/concepts/workloads/pods/disruptions/) work with the Eviction API. Tools like [`kubectl drain`](https://kubernetes.io/docs/reference/kubectl/generated/kubectl_drain/) cordon a node and try to **evict** Pods while respecting PDBs.

## Explanation

- Set either `minAvailable` or `maxUnavailable` (not both).
- Values may be counts or percentages.
- PDBs apply to **voluntary** disruptions; involuntary failures (hardware death) are not blocked by a PDB.
- Drain may also fail on local-storage Pods unless you allow deleting emptyDir data.

## Architecture / flow

```text
kubectl drain <node>
      |
      v
 Cordon node (NoSchedule)
      |
      v
 Eviction API per Pod
      |
      +--> PDB allows?  → terminate Pod, reschedule elsewhere
      |
      +--> PDB blocks?  → drain waits / fails (timeout)
```

## Official references

- [Disruptions](https://kubernetes.io/docs/concepts/workloads/pods/disruptions/) (Kubernetes)
- [Specifying a Disruption Budget](https://kubernetes.io/docs/tasks/run-application/configure-pdb/) (Kubernetes)
- [Safely Drain a Node](https://kubernetes.io/docs/tasks/administer-cluster/safely-drain-node/) (Kubernetes)

## Lab setup

From the **repo root**:

```powershell
kubectl apply -f manifests/pdb-demo.yaml
kubectl get pods -l app=pdb-demo -o wide
kubectl get pdb pdb-demo

# Choose a node that hosts a pdb-demo Pod
kubectl get pods -l app=pdb-demo -o wide
kubectl drain <node-name> --ignore-daemonsets --timeout=3m
kubectl uncordon <node-name>

# Tighten budget so voluntary eviction is blocked
kubectl patch pdb pdb-demo --type merge -p '{"spec":{"minAvailable":3}}'
kubectl get pdb pdb-demo

kubectl drain <node-name> --ignore-daemonsets --pod-selector=app=pdb-demo --timeout=30s
kubectl uncordon <node-name>
```

## Cleanup

```powershell
kubectl delete deployment pdb-demo --ignore-not-found
kubectl delete pdb pdb-demo --ignore-not-found
kubectl get nodes
```
