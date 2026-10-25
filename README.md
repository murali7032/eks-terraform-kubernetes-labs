# EKS Terraform Lab

Hands-on Kubernetes labs on Amazon EKS. Provision a cluster with Terraform, then follow architecture-first walkthroughs under `docs/` and apply the matching YAML under `manifests/`.

This repo is a learning project in progress. The labs focus on understanding Kubernetes behavior and AWS integrations through observable exercises. Some topics are still notes rather than complete walkthroughs.

## Prerequisites

- AWS account and CLI configured
- Terraform `>= 1.13`
- `kubectl`, `helm`
- PowerShell-friendly commands in the docs (adapt if you use bash)

## Quick start

1. Provision the AWS foundation. Review [Terraform setup and cost guidance](terraform/README.md) first:

```powershell
cd terraform
Copy-Item terraform.tfvars.example terraform.tfvars
# Edit aws_region / aws_profile and set cluster_endpoint_allowed_cidrs to your public IP /32.
terraform init
terraform fmt -check
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
cd ..
```

2. Point kubectl at the cluster ([docs/kubeconfig.md](docs/kubeconfig.md)).

3. Run all `kubectl` / `helm` commands from the **repo root** so paths like `manifests/...` resolve.

## Layout

| Path | Purpose |
|------|---------|
| [terraform/](terraform/) | VPC + EKS + EBS/EFS CSI + EFS + Karpenter IAM; optional Elasticsearch EC2 lab |
| [manifests/](manifests/) | Lab YAML (and Helm values / addon JSON used by docs) |
| [docs/](docs/) | Topic walkthroughs (Markdown) |
| [aws/](aws/) | Sample IAM JSON for AWS Load Balancer Controller |

## Doc format

Most lab walkthroughs under `docs/` include:

1. **Title** + highlight callout  
2. **Introduction**  
3. **Explanation**  
4. **Architecture / flow**  
5. **Official references** (Kubernetes / AWS / project docs)  
6. **Lab setup, verification, and cleanup**

The `rca_template.md` and `rca_checklist.md` files are incident review aids rather than lab walkthroughs.

## Curriculum

Work through the foundations first, then choose a topic area. Each lab should be run against a disposable cluster and cleaned up afterward.

### 1. Cluster setup

| Topic | Doc | Files |
|-------|-----|-------|
| Provision EKS | [Terraform setup](terraform/README.md) | [terraform/](terraform/) |
| kubeconfig | [docs/kubeconfig.md](docs/kubeconfig.md) | — |
| Common issues and diagnostics | [docs/troubleshooting.md](docs/troubleshooting.md) | `kubectl describe`, events, logs |
| Architecture: control plane and nodes | [docs/k8s_architecture.md](docs/k8s_architecture.md) | `kubectl` observations |
| Pods, Deployments, Services | [docs/k8s_workloads.md](docs/k8s_workloads.md) | `kubectl` exercises |

### 2. Core Kubernetes

| Topic | Doc | Files |
|-------|-----|-------|
| DNS | [docs/k8s_dns.md](docs/k8s_dns.md) | ad-hoc `kubectl run` |
| NetworkPolicy | [docs/network_policy.md](docs/network_policy.md) | [manifests/deny-server-ingress.yaml](manifests/deny-server-ingress.yaml), [allow-client-to-server.yaml](manifests/allow-client-to-server.yaml), [egress-lab.yaml](manifests/egress-lab.yaml), [deny-client-egress.yaml](manifests/deny-client-egress.yaml), [allow-client-to-destination.yaml](manifests/allow-client-to-destination.yaml), [allow-client-dns.yaml](manifests/allow-client-dns.yaml), [np-client-same.yaml](manifests/np-client-same.yaml), [vpc-cni-config.json](manifests/vpc-cni-config.json) |
| RBAC | [docs/rbac.md](docs/rbac.md) | [manifests/rbac-reader.yaml](manifests/rbac-reader.yaml) |
| Init + sidecar | [docs/sidecar_init.md](docs/sidecar_init.md) | [manifests/init-demo.yaml](manifests/init-demo.yaml), [sidecar-demo.yaml](manifests/sidecar-demo.yaml) |
| Jobs / CronJobs | [docs/jobs_cron_jobs.md](docs/jobs_cron_jobs.md) | [manifests/hello-job.yaml](manifests/hello-job.yaml), [hello-cronjob.yaml](manifests/hello-cronjob.yaml), [job-retry.yaml](manifests/job-retry.yaml) |
| Affinity / topology | [docs/pod_affinity.md](docs/pod_affinity.md) | [manifests/pod-antiaffinity.yaml](manifests/pod-antiaffinity.yaml), [topology-spread.yaml](manifests/topology-spread.yaml) |
| PDB + drain | [docs/pdb_nodeDrain.md](docs/pdb_nodeDrain.md) | [manifests/pdb-demo.yaml](manifests/pdb-demo.yaml) |
| CPU requests/limits | [docs/cpu_resources.md](docs/cpu_resources.md) | [manifests/cpu-demo.yaml](manifests/cpu-demo.yaml) |
| ConfigMaps and Secrets | [docs/configmap_secrets.md](docs/configmap_secrets.md) | [manifests/config-secret-demo.yaml](manifests/config-secret-demo.yaml) |

### 3. AWS identity on EKS

| Topic | Doc | Files |
|-------|-----|-------|
| Pod Identity (S3) | [docs/IRSA_PodIdentity.md](docs/IRSA_PodIdentity.md) | [terraform/s3_test_pod_identity.tf](terraform/s3_test_pod_identity.tf) |

### 4. Releases

| Topic | Doc | Files |
|-------|-----|-------|
| Blue / green | [docs/blue_green_deployment.md](docs/blue_green_deployment.md) | [manifests/blue-green.yaml](manifests/blue-green.yaml) |
| Canary | [docs/canary_deployment.md](docs/canary_deployment.md) | [manifests/canary-lab.yaml](manifests/canary-lab.yaml) |

### 5. Storage and stateful workloads

| Topic | Doc | Files |
|-------|-----|-------|
| Storage (gp3 + EFS) | [docs/storage.md](docs/storage.md) | [manifests/gp3-storageclass.yaml](manifests/gp3-storageclass.yaml), [efs-pv.yaml](manifests/efs-pv.yaml), [efs-pvc.yaml](manifests/efs-pvc.yaml), [nginx-pvc.yaml](manifests/nginx-pvc.yaml); EFS in [terraform/eks.tf](terraform/eks.tf) |
| StatefulSet | [docs/statefulset.md](docs/statefulset.md) | [manifests/statefulset.yaml](manifests/statefulset.yaml) (needs EFS PVC) |

### 6. Ingress, autoscaling nodes, observability

| Topic | Doc | Files |
|-------|-----|-------|
| ALB Ingress | [docs/alb_ingress.md](docs/alb_ingress.md) | [manifests/nginx-deployment.yaml](manifests/nginx-deployment.yaml), [nginx-service.yaml](manifests/nginx-service.yaml), [nginx-ingress.yaml](manifests/nginx-ingress.yaml); IAM samples in [aws/](aws/) |
| Karpenter | [docs/karpenter.md](docs/karpenter.md) | [manifests/karpenter-ec2nodeclass.yaml](manifests/karpenter-ec2nodeclass.yaml), [karpenter-nodepool.yaml](manifests/karpenter-nodepool.yaml), [karpenter-test.yaml](manifests/karpenter-test.yaml); [terraform/karpenter.tf](terraform/karpenter.tf) |
| Prometheus stack | [docs/prometheus_stack.md](docs/prometheus_stack.md) | [manifests/monitoring-values.yaml](manifests/monitoring-values.yaml) |
| Horizontal Pod Autoscaler | [docs/hpa.md](docs/hpa.md) | Uses `cpu-demo` from [manifests/cpu-demo.yaml](manifests/cpu-demo.yaml) |
| Gateway API | [docs/gateway_api.md](docs/gateway_api.md) | [manifests/gatewayclass.yaml](manifests/gatewayclass.yaml), [gateway.yaml](manifests/gateway.yaml), [gateway-demo.yaml](manifests/gateway-demo.yaml), [httproute.yaml](manifests/httproute.yaml); IAM samples in [aws/](aws/) |
| Istio service mesh | [docs/istio_servicemesh.md](docs/istio_servicemesh.md) | [manifests/backend-v1.yaml](manifests/backend-v1.yaml), [backend-v2.yaml](manifests/backend-v2.yaml), [backend-service.yaml](manifests/backend-service.yaml), [backend-gateway.yaml](manifests/backend-gateway.yaml), [backend-destinationrule.yaml](manifests/backend-destinationrule.yaml), [backend-virtualservice.yaml](manifests/backend-virtualservice.yaml), [curl-client.yaml](manifests/curl-client.yaml), [mtls-strict.yaml](manifests/mtls-strict.yaml), [backend-authz.yaml](manifests/backend-authz.yaml) |
| ELK / EFK logging | [docs/elk_stack.md](docs/elk_stack.md) | [manifests/gp3-csi.yaml](manifests/gp3-csi.yaml), [elasticsearch.yaml](manifests/elasticsearch.yaml), [kibana.yaml](manifests/kibana.yaml), [filebeat.yaml](manifests/filebeat.yaml) |

### 7. Operational practice

| Topic | Doc | Files |
|-------|-----|-------|
| Incident review | [docs/rca_template.md](docs/rca_template.md), [docs/rca_checklist.md](docs/rca_checklist.md) | Templates |

## Cost note

EKS, nodes, ALB, EFS, and Karpenter-provisioned instances cost money. Tear down labs when finished (`kubectl delete ...`, then `terraform destroy` when you are done with the cluster).

## Lab conventions and safety

- Start with [Kubernetes architecture](docs/k8s_architecture.md), then [workloads and Services](docs/k8s_workloads.md).
- Unless a guide says otherwise, run commands from the repository root and use a disposable cluster.
- Check each lab's prerequisites before applying manifests. Remove created resources using that lab's cleanup steps.
- Never commit AWS credentials, `terraform.tfvars`, Terraform state/plan files, kubeconfig files, or real Kubernetes Secrets. Kubernetes Secret values are base64 encoded, not encrypted by that encoding.
- The optional standalone Elasticsearch host is disabled by default. If enabled, allow access only from your own public IP CIDR and remove it after the lab. See [Terraform setup](terraform/README.md).
- Terraform requires the EKS API endpoint allowlist to be set to your public IPv4 `/32` before planning; update it if your IP changes.
- Use `terraform destroy` when done with the cluster, then check for retained volumes or manually created AWS resources.

## Before publishing changes

Review staged files for credentials, account identifiers, local state, plan output, and generated vendor content. The `istio/` directory currently contains a full upstream Istio tree; the lab itself only needs its walkthrough and the repo-specific files in `manifests/`.

## License

MIT — see [LICENSE](LICENSE).
