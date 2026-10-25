# Configure kubectl for Amazon EKS

> Point `kubectl` at your EKS cluster by writing a kubeconfig entry with `aws eks update-kubeconfig`.

## Introduction

After Terraform (or another tool) creates an EKS cluster, your local kubeconfig must trust the cluster API and authenticate with AWS IAM. The AWS CLI updates kubeconfig for you.

## Explanation

- `aws eks update-kubeconfig` merges a cluster, user, and context into `~/.kube/config` (or `KUBECONFIG`).
- Authentication uses your AWS credentials (`--profile` or environment) via the `aws` exec plugin.
- Verify with `kubectl get nodes` / `kubectl cluster-info`.

## Architecture / flow

```text
kubectl  →  kubeconfig context
                |
                v
         AWS CLI / IAM  →  EKS API endpoint
```

## Official references

- [Create a kubeconfig for Amazon EKS](https://docs.aws.amazon.com/eks/latest/userguide/create-kubeconfig.html) (AWS)
- [Organizing Cluster Access Using kubeconfig Files](https://kubernetes.io/docs/concepts/configuration/organize-cluster-access-kubeconfig/) (Kubernetes)

## Lab setup

Replace placeholders to match `terraform/terraform.tfvars` (or your cluster):

```powershell
aws eks update-kubeconfig `
  --region <region> `
  --name <cluster-name> `
  --profile <profile>

kubectl get nodes
kubectl cluster-info
```

## Cleanup

No cluster resources are created. To remove the local context later:

```powershell
kubectl config unset contexts.<context-name>
kubectl config unset clusters.<cluster-name>
kubectl config unset users.<user-name>
```
