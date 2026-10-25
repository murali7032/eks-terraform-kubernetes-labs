# ELK / EFK logging on EKS

> Ship Kubernetes container logs into **Elasticsearch**, explore them in **Kibana**. This lab uses **Filebeat** (not Logstash) as the collector — often called **EFK**: Elasticsearch, Filebeat, Kibana.

## Introduction

The classic **ELK** stack is Elasticsearch + Logstash + Kibana. On Kubernetes it is common to replace Logstash with a lightweight shipper:


| Component         | Role in this lab                                                   |
| ----------------- | ------------------------------------------------------------------ |
| **Elasticsearch** | Stores and indexes documents / logs                                |
| **Filebeat**      | DaemonSet on each node; reads container log files and ships to ES  |
| **Kibana**        | UI for Discover, data views, and dashboards                        |
| **Logstash**      | Optional pipeline (input → filter → output); **not deployed here** |


You practiced:

1. `gp3-csi` StorageClass for Elasticsearch data
2. Single-node Elasticsearch 8.15.3 in namespace `elk`
3. Kibana pointed at the ES Service
4. Manual index `devops-test` + Kibana data view
5. Filebeat DaemonSet in `logging` → `filebeat-*` indices
6. A `log-test` Pod to prove the live pipeline

Security is **disabled** (`xpack.security.enabled=false`) for a small lab cluster only — never do that in production.

## Explanation

### Elasticsearch

- Search and analytics engine. HTTP API on **9200**, node transport on **9300**.
- This lab: StatefulSet `replicas: 1`, `discovery.type=single-node`, 10 Gi PVC on `gp3-csi`.
- Headless Service (`clusterIP: None`) gives stable DNS: `elasticsearch.elk.svc.cluster.local`.

### Kibana

- Connects with `ELASTICSEARCH_HOSTS` to the Elasticsearch Service.
- **Data views** (e.g. `devops-`*, `filebeat-`*) tell Discover which indices to query.

### Filebeat on Kubernetes

Per [Elastic’s Filebeat on Kubernetes guide](https://www.elastic.co/docs/reference/beats/filebeat/running-on-kubernetes), Filebeat runs as a **DaemonSet** so every node has a collector. It mounts host paths such as `/var/log/containers` and ships events to Elasticsearch, often with Kubernetes metadata enrichment.

This repo’s Filebeat config uses:

- `filebeat.autodiscover` (Kubernetes provider)  
- `add_kubernetes_metadata`  
- `output.elasticsearch.hosts: http://elasticsearch.elk.svc.cluster.local:9200`

### StorageClass `gp3-csi`


| Setting                        | Why it matters                 |
| ------------------------------ | ------------------------------ |
| `provisioner: ebs.csi.aws.com` | EBS CSI driver                 |
| `type: gp3`                    | SSD-backed volume              |
| `encrypted: "true"`            | Encryption at rest             |
| `WaitForFirstConsumer`         | Volume created in the Pod’s AZ |
| `allowVolumeExpansion: true`   | PVC can grow later             |


Manifests:


| File                           | Purpose                        |
| ------------------------------ | ------------------------------ |
| `manifests/gp3-csi.yaml`       | StorageClass for ES data       |
| `manifests/elasticsearch.yaml` | Headless Service + StatefulSet |
| `manifests/kibana.yaml`        | Deployment + ClusterIP Service |
| `manifests/filebeat.yaml`      | SA, RBAC, ConfigMap, DaemonSet |


## Architecture / flow

### Classic ELK vs this lab (EFK)

```text
Classic ELK                          This lab (EFK)
─────────────                        ──────────────
Pod stdout                           Pod stdout
   │                                    │
   ▼                                    ▼
collector / agent                    node log files
   │                                 /var/log/containers
   ▼                                    │
Logstash (filter)                       ▼
   │                                 Filebeat DaemonSet
   ▼                                    │
Elasticsearch  ◄────────────────────────┘
   │
   ▼
Kibana
```

### End-to-end request / log path

```text
┌─────────────────────────────────────────────────────────┐
│  EKS worker node                                        │
│                                                         │
│   Pod (e.g. log-test)                                   │
│      stdout / stderr                                    │
│           │                                             │
│           ▼                                             │
│   kubelet → /var/log/pods/... → /var/log/containers/*.log│
│           │                                             │
│           ▼                                             │
│   Filebeat Pod (DaemonSet, ns: logging)                 │
│      mounts hostPath logs + ConfigMap                   │
└───────────────────────┬─────────────────────────────────┘
                        │ HTTP bulk index
                        ▼
          ┌──────────────────────────┐
          │  ns: elk                 │
          │                          │
          │  elasticsearch-0         │
          │  (StatefulSet + PVC)     │
          │       │                  │
          │       ▼                  │
          │  indices:                │
          │   filebeat-*             │
          │   devops-test            │
          │   .kibana-*              │
          │       │                  │
          │       ▼                  │
          │  Kibana :5601            │
          │  (Discover / data views) │
          └──────────────────────────┘
```

### Manual document path (before Filebeat)

```text
Your laptop
   │  kubectl cp + curl POST
   ▼
elasticsearch-0  →  index devops-test
   │
   ▼
Kibana data view devops-*  →  Discover
```

### Kubernetes objects

```text
logging                          elk
───────                          ───
ServiceAccount filebeat          Service elasticsearch (headless)
ClusterRole / Binding            StatefulSet elasticsearch
ConfigMap filebeat-config          └── PVC data-elasticsearch-0 (gp3-csi)
DaemonSet filebeat               Deployment kibana
                                 Service kibana (ClusterIP)
```

## Official references

- [Elasticsearch](https://www.elastic.co/guide/en/elasticsearch/reference/8.15/index.html) (8.15)
- [Kibana](https://www.elastic.co/guide/en/kibana/8.15/index.html) (8.15)
- [Run Filebeat on Kubernetes](https://www.elastic.co/docs/reference/beats/filebeat/running-on-kubernetes) (Elastic)
- [Filebeat autodiscover](https://www.elastic.co/guide/en/beats/filebeat/8.15/configuration-autodiscover.html) (Elastic)
- [Amazon EBS CSI driver](https://docs.aws.amazon.com/eks/latest/userguide/ebs-csi.html) (AWS)
- [Storage Classes](https://kubernetes.io/docs/concepts/storage/storage-classes/) (Kubernetes)
- [StatefulSets](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/) (Kubernetes)

## Lab setup

Run commands from the **repo root**. Ensure the EBS CSI driver is installed on the cluster (see Terraform / [docs/storage.md](storage.md)).

### 1. StorageClass

```powershell
kubectl apply -f gp3-csi.yaml
kubectl get storageclass gp3-csi
kubectl describe storageclass gp3-csi
```

### 2. Namespace and Elasticsearch

```powershell
kubectl create namespace elk
kubectl apply -f elasticsearch.yaml

kubectl get pods,svc,pvc -n elk
kubectl rollout status statefulset/elasticsearch -n elk --timeout=300s
```

Smoke-test the HTTP API inside the Pod:

```powershell
kubectl exec -n elk elasticsearch-0 -- curl -s http://localhost:9200
kubectl exec -n elk elasticsearch-0 -- curl -s "http://localhost:9200/_cluster/health?pretty"
kubectl exec -n elk elasticsearch-0 -- curl -s "http://localhost:9200/_cat/indices?v"
```

Healthy single-node lab often shows `"status" : "yellow"` until replica settings are adjusted (one node cannot allocate replicas).

Optional host access:

```powershell
kubectl port-forward -n elk pod/elasticsearch-0 9200:9200
# another terminal
curl.exe http://localhost:9200
```

Logs to check: `started`, `publish_address`, `bound_addresses`.

```powershell
kubectl logs -n elk elasticsearch-0 --tail=100
```

If the Pod restarts, inspect OOM / exit codes:

```powershell
kubectl describe pod elasticsearch-0 -n elk |
  Select-String -Pattern "State:|Reason:|Exit Code:|Restart Count:|OOMKilled" -Context 0,3
```

### 3. Kibana

```powershell
kubectl apply -f kibana.yaml
kubectl rollout status deployment/kibana -n elk --timeout=300s
kubectl get pods,svc -n elk
```

Verify Kibana can reach Elasticsearch:

```powershell
kubectl exec -n elk deployment/kibana -- `
  curl -s http://elasticsearch.elk.svc.cluster.local:9200
```

Open the UI:

```powershell
kubectl port-forward -n elk svc/kibana 5601:5601
```

Browse [http://localhost:5601](http://localhost:5601) and keep the port-forward running.

### 4. Manual index `devops-test`

```powershell
@'
{"service":"backend","environment":"lab","message":"ELK stack is working"}
'@ | Set-Content -Encoding utf8 .\test.json

kubectl cp .\test.json elk/elasticsearch-0:/tmp/test.json

kubectl exec -n elk elasticsearch-0 -- `
  curl -s -X POST "http://localhost:9200/devops-test/_doc/1" `
  -H "Content-Type: application/json" `
  --data-binary "@/tmp/test.json"

kubectl exec -n elk elasticsearch-0 -- `
  curl -s "http://localhost:9200/devops-test/_search?pretty"
```

Optional — set replicas to 0 so cluster health can go **green** on a single node:

```powershell
@'
{"index":{"number_of_replicas":0}}
'@ | Set-Content -Encoding utf8 .\settings.json

kubectl cp .\settings.json elk/elasticsearch-0:/tmp/settings.json

kubectl exec -n elk elasticsearch-0 -- `
  curl -s -X PUT "http://localhost:9200/devops-test/_settings" `
  -H "Content-Type: application/json" `
  --data-binary "@/tmp/settings.json"

kubectl exec -n elk elasticsearch-0 -- `
  curl -s "http://localhost:9200/_cluster/health?pretty"
```

In Kibana:

1. **Stack Management → Data Views → Create data view** → pattern `devops-`*
2. **Analytics → Discover** → select `devops-`*

### 5. Filebeat DaemonSet

```powershell
kubectl create namespace logging
kubectl apply -f filebeat.yaml
kubectl get pods -n logging -o wide
kubectl logs -n logging -l app=filebeat --tail=50
```

Confirm indices and sample docs:

```powershell
kubectl exec -n elk elasticsearch-0 -- curl -s "http://localhost:9200/_cat/indices?v"
kubectl exec -n elk elasticsearch-0 -- `
  curl -s "http://localhost:9200/filebeat-*/_search?size=3&pretty"
```

In Kibana create a data view `filebeat-*` (time field `@timestamp`) and open **Discover**.

### 6. Prove the live pipeline

```powershell
kubectl run log-test -n elk `
  --image=busybox:1.36 `
  --restart=Never `
  -- sh -c "while true; do echo 'ELK_PIPELINE_TEST backend logging is working'; sleep 5; done"

kubectl logs -n elk log-test --tail=5

kubectl exec -n elk elasticsearch-0 -- `
  curl -s "http://localhost:9200/filebeat-*/_search?q=message:ELK_PIPELINE_TEST&pretty"
```

Index cheat sheet:


| Pattern       | Meaning                  |
| ------------- | ------------------------ |
| `filebeat-*`  | Logs shipped by Filebeat |
| `devops-test` | Manual test documents    |
| `.kibana-*`   | Kibana saved objects     |


## Cleanup

Delete collectors and apps before volumes/namespaces so EBS PVCs can release cleanly.

```powershell
kubectl delete pod log-test -n elk --ignore-not-found

kubectl delete -f manifests/filebeat.yaml --ignore-not-found
kubectl delete namespace logging --ignore-not-found

kubectl delete -f manifests/kibana.yaml --ignore-not-found
kubectl delete -f manifests/elasticsearch.yaml --ignore-not-found

# StatefulSet PVC is often left behind — delete explicitly if present
kubectl delete pvc data-elasticsearch-0 -n elk --ignore-not-found
kubectl delete namespace elk --ignore-not-found

# Optional: keep gp3-csi if other labs use it
# kubectl delete -f manifests/gp3-csi.yaml

Remove-Item .\test.json,.\settings.json -ErrorAction SilentlyContinue
kubectl get pods -A
kubectl get storageclass
```

**Cost note:** the Elasticsearch PVC is an EBS volume. Delete the PVC (and confirm the volume is gone in AWS) when you are finished.