# Horizontal Pod Autoscaler

> The HPA adjusts a workload's replica count from observed metrics. This lab uses CPU utilization and Metrics Server.

## How it works

The HPA controller periodically reads resource metrics, compares observed CPU usage with the configured target, and updates the Deployment's desired replica count. CPU utilization is measured relative to the container CPU request, so a request must be set. Metrics Server supplies resource metrics; Prometheus is a separate monitoring system.

## Prerequisites

- A connected EKS cluster and `kubectl` context.
- The `cpu-demo` Deployment in [manifests/cpu-demo.yaml](../manifests/cpu-demo.yaml). Its lab container intentionally consumes CPU and is capped at 200m.

## Lab

Install Metrics Server if the metrics API is not already available:

```powershell
kubectl get apiservice v1beta1.metrics.k8s.io
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo update
helm upgrade --install metrics-server metrics-server/metrics-server --namespace kube-system --wait
kubectl rollout status deployment/metrics-server -n kube-system --timeout=180s
kubectl top nodes
```

Run the CPU workload and create an HPA target:

```powershell
kubectl apply -f manifests/cpu-demo.yaml
kubectl autoscale deployment cpu-demo --cpu=50% --min=1 --max=3
kubectl get hpa cpu-demo -w
```

In another terminal, inspect observed usage and events:

```powershell
kubectl top pods -l app=cpu-demo
kubectl describe hpa cpu-demo
kubectl get deployment cpu-demo
```

Allow a few metrics collection cycles. The HPA may take time to scale, and cluster capacity or scheduling constraints can limit how many replicas become ready. `kubectl get hpa` showing `<unknown>` usually means metrics are not available yet.

## Cleanup

```powershell
kubectl delete hpa cpu-demo --ignore-not-found
kubectl delete -f manifests/cpu-demo.yaml --ignore-not-found
# Only if this lab installed Metrics Server and no other lab uses it:
helm uninstall metrics-server -n kube-system
```

## References

- [Horizontal Pod Autoscaling](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)
- [Resource metrics pipeline](https://kubernetes.io/docs/tasks/debug/debug-cluster/resource-metrics-pipeline/)
