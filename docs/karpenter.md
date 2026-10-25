# Karpenter

> Karpenter launches right-sized EC2 nodes for **unschedulable** Pods using a **NodePool** plus an AWS **EC2NodeClass**.

## Introduction

[Karpenter](https://karpenter.sh/docs/) is a node provisioning project. Unlike Cluster Autoscaler (which scales ASGs), Karpenter directly creates instances that match pending Pod requirements, then consolidates when capacity is unused.

IAM / Pod Identity pieces in this repo: `terraform/karpenter.tf`. Install the Karpenter controller (Helm) if it is not already running.

## Explanation

| Resource | Purpose |
|----------|---------|
| `EC2NodeClass` | AMI, subnets, security groups, node IAM `role` |
| `NodePool` | Constraints (arch, OS, instance types, capacity type), limits, disruption |

Edit `manifests/karpenter-ec2nodeclass.yaml`: set `spec.role` to your Karpenter node role; keep `karpenter.sh/discovery` tags aligned with the cluster.

## Architecture / flow

```text
Unschedulable Pods
        |
        v
   Karpenter controller
        |
   NodePool + EC2NodeClass
        |
        v
   New EC2 node joins
        |
        v
   Pending Pods schedule
```

## Official references

- [Karpenter docs](https://karpenter.sh/docs/) (project)
- [NodePools](https://karpenter.sh/docs/concepts/nodepools/) (Karpenter)
- [NodeClasses (EC2NodeClass)](https://karpenter.sh/docs/concepts/nodeclasses/) (Karpenter)
- [Amazon EKS and Karpenter](https://docs.aws.amazon.com/eks/latest/userguide/karpenter.html) (AWS)

## Lab setup

From the **repo root**:

```powershell
kubectl get pods -n kube-system -l app.kubernetes.io/name=karpenter

kubectl apply -f manifests/karpenter-ec2nodeclass.yaml
kubectl apply -f manifests/karpenter-nodepool.yaml
kubectl get ec2nodeclass
kubectl get nodepool

# 13 replicas × 500m CPU to force capacity
kubectl apply -f manifests/karpenter-test.yaml
kubectl get pods -l app=karpenter-test -o wide
kubectl get nodes -l karpenter.sh/nodepool

kubectl logs -n kube-system -l app.kubernetes.io/name=karpenter --tail=50
```

## Cleanup

```powershell
kubectl delete -f manifests/karpenter-test.yaml --ignore-not-found
# Wait for consolidation (see NodePool consolidateAfter) or drain/delete Karpenter nodes
kubectl delete -f manifests/karpenter-nodepool.yaml --ignore-not-found
kubectl delete -f manifests/karpenter-ec2nodeclass.yaml --ignore-not-found
```
