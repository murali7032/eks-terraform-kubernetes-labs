# Prometheus monitoring stack

> Install **Metrics Server** (for `kubectl top`) and **kube-prometheus-stack** (Prometheus + Grafana) to scrape metrics and explore PromQL—useful before increasing canary traffic.

## Introduction

[Prometheus](https://prometheus.io/docs/introduction/overview/) scrapes HTTP `/metrics` endpoints, stores time series, and queries them with PromQL. On Kubernetes, [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack) deploys Prometheus Operator, Prometheus, Grafana, and related components. [kube-state-metrics](https://github.com/kubernetes/kube-state-metrics) exposes object state (for example Deployment replica counts); container CPU/memory for `kubectl top` comes from the [Metrics Server](https://kubernetes.io/docs/tasks/debug/debug-cluster/resource-metrics-pipeline/).

## Explanation

- Prometheus scrapes **targets**; exporters or apps expose metrics.
- `up` — scrape success (1/0).
- Example PromQL: `count by (namespace) (kube_pod_info)`, compare `kube_deployment_spec_replicas` vs `kube_deployment_status_replicas_available`.
- Lab values file disables Alertmanager persistence extras: `manifests/monitoring-values.yaml`.

## Architecture / flow

```text
App / exporter / kubelet / kube-state-metrics
              |
         /metrics (HTTP scrape)
              v
         Prometheus
              |
           PromQL
              v
     Grafana / Alerts
```

## Official references

- [Prometheus overview](https://prometheus.io/docs/introduction/overview/) (Prometheus)
- [Resource metrics pipeline](https://kubernetes.io/docs/tasks/debug/debug-cluster/resource-metrics-pipeline/) (Kubernetes)
- [kube-prometheus-stack Helm chart](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack) (prometheus-community)
- [Metrics Server](https://github.com/kubernetes-sigs/metrics-server) (kubernetes-sigs)

## Lab setup

From the **repo root**.

### 1. Metrics Server

```powershell
kubectl get apiservice v1beta1.metrics.k8s.io

helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo update
helm upgrade --install metrics-server metrics-server/metrics-server `
  --namespace kube-system `
  --wait

kubectl rollout status deployment/metrics-server -n kube-system --timeout=180s
kubectl top nodes
kubectl top pods -A
```

### 2. kube-prometheus-stack

```powershell
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack `
  --namespace monitoring `
  --version 91.8.1 `
  --values manifests/monitoring-values.yaml

kubectl get pods -n monitoring
kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80
```

Grafana admin password (PowerShell):

```powershell
$encoded = kubectl get secret monitoring-grafana -n monitoring -o jsonpath="{.data.admin-password}"
[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($encoded))
```

Try PromQL in Grafana Explore: `up`, `count(kube_pod_info)`, `sum by (namespace) (kube_pod_status_phase{phase="Running"})`.

## Cleanup

```powershell
helm uninstall monitoring -n monitoring
kubectl delete namespace monitoring --ignore-not-found
# Optional: helm uninstall metrics-server -n kube-system
```
