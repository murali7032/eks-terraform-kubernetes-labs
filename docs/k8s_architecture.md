# Kubernetes architecture on Amazon EKS

> Start here to understand which Kubernetes components make decisions, which ones run Pods, and which parts Amazon EKS operates for you.

## Learning goals

By the end, you should be able to trace a Deployment from submitted YAML to a running Pod, identify the control-plane and node components involved, and inspect the state transitions with `kubectl`.

## Architecture

```text
                         AWS-managed EKS control plane
                  ┌──────────────────────────────────────┐
kubectl ──HTTPS──▶│ API server ──▶ etcd                  │
                  │    ▲             ▲                   │
                  │    │             │                   │
                  │ scheduler   controllers              │
                  └────┬─────────────────────────────────┘
                       │ watches / updates API objects
          ┌────────────┴────────────────────────────┐
          │ EKS worker nodes (EC2)                  │
          │ kubelet ── container runtime ── Pods    │
          │ VPC CNI │ kube-proxy │ CSI / add-ons    │
          └─────────────────────────────────────────┘
```

| Component | Responsibility | EKS lab observation |
|---|---|---|
| API server | Validates requests and exposes the Kubernetes API | `kubectl cluster-info`; every `kubectl apply` talks to it |
| etcd | Stores Kubernetes API state | Managed by EKS; do not access its storage directly |
| Scheduler | Selects a suitable node for unscheduled Pods | Compare Pod events before and after scheduling |
| Controller manager | Reconciles desired and observed state | Scale a Deployment and watch ReplicaSets/Pods appear |
| kubelet | Runs on each node and reports Pod status | `kubectl get nodes -o wide`; inspect node events |
| Container runtime | Pulls images and runs containers | Observe Pod events and container status |
| kube-proxy / VPC CNI | Implements service forwarding / Pod networking (EKS configuration varies) | Inspect `kube-system` DaemonSets and Pod IPs |
| CoreDNS | Resolves in-cluster Service names | Follow [the DNS lab](k8s_dns.md) |

EKS operates the Kubernetes control plane, including its API server and etcd. You operate the worker capacity, Kubernetes objects, add-ons, IAM access, and AWS networking around the cluster. EKS exposes the control-plane API, but not its hosts or etcd disks.

## Trace a Deployment

Prerequisite: a cluster created with [the Terraform setup](../terraform/README.md) and a configured kubeconfig.

```powershell
kubectl create namespace architecture-lab
kubectl create deployment web --image=nginx:1.27 --replicas=2 -n architecture-lab
kubectl get deployment,replicaset,pods -n architecture-lab -o wide
kubectl describe deployment web -n architecture-lab
kubectl get events -n architecture-lab --sort-by=.lastTimestamp
```

The Deployment records desired state. Its controller creates a ReplicaSet; the ReplicaSet controller creates Pods; the scheduler assigns each Pod to a node; the node kubelet starts the containers and reports status to the API server. Try scaling and observe the reconciliation:

```powershell
kubectl scale deployment web --replicas=3 -n architecture-lab
kubectl get deployment,replicaset,pods -n architecture-lab -w
```

## Verify and clean up

```powershell
kubectl rollout status deployment/web -n architecture-lab
kubectl delete namespace architecture-lab
```

## Next labs

Continue with [workloads and Services](k8s_workloads.md), then DNS, [RBAC](rbac.md), [network policy](network_policy.md), and scheduling labs.

## References

- [Kubernetes components](https://kubernetes.io/docs/concepts/overview/components/)
- [EKS architecture](https://docs.aws.amazon.com/eks/latest/userguide/cluster-architecture.html)
- [Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
