# EKS Pod Identity (workload AWS access)

> Associate an IAM role with a Kubernetes **ServiceAccount** so Pods get temporary AWS credentials—without embedding keys. This lab uses **EKS Pod Identity** (preferred over classic IRSA for many new workloads).

## Introduction

[EKS Pod Identity](https://docs.aws.amazon.com/eks/latest/userguide/pod-identities.html) maps a ServiceAccount to an IAM role. The Pod Identity Agent on each node provides credentials to Pods that use that ServiceAccount. The AWS SDK default credential chain picks them up automatically.

> **Note:** The filename `IRSA_PodIdentity.md` reflects history; this lab focuses on **Pod Identity**. IRSA (OIDC + `eks.amazonaws.com/role-arn` annotation) is a related but separate mechanism.

## Explanation

| Piece | Role |
|-------|------|
| Kubernetes ServiceAccount | Workload identity inside the cluster |
| IAM role + policy | Permissions in AWS |
| Pod Identity association | EKS API link between SA and IAM role |
| Pod Identity Agent | DaemonSet that hands credentials to Pods on the node |

Terraform for this lab: `terraform/s3_test_pod_identity.tf`. The IAM role and association are skipped by default. Set `s3_test_bucket_name` to an existing disposable bucket name in `terraform/terraform.tfvars`, then run `terraform apply` to create the least-privilege role association. The bucket itself is not created by Terraform.

## Architecture / flow

```text
Application in Pod
       |
       | AWS SDK requests credentials
       v
Container credential provider
       |
       v
EKS Pod Identity Agent (on the node)
       |
       v
EKS Pod Identity service
       |
       v
Temporary credentials for the associated IAM role
       |
       v
AWS API call (e.g. S3)
```

## Official references

- [EKS Pod Identities](https://docs.aws.amazon.com/eks/latest/userguide/pod-identities.html) (AWS)
- [Set up the Amazon EKS Pod Identity Agent](https://docs.aws.amazon.com/eks/latest/userguide/pod-id-agent-setup.html) (AWS)
- [IAM roles for service accounts (IRSA)](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html) (AWS — related)

## Lab setup

From the **repo root**. Create an empty disposable bucket with a globally unique name and set `s3_test_bucket_name` to that same name in Terraform before applying. Replace `<cluster-name>`, `<region>`, `<profile>`, `<your-test-bucket>`.

```powershell
kubectl get pods -n kube-system -l app.kubernetes.io/name=eks-pod-identity-agent

aws s3 mb s3://<your-test-bucket> --region <region> --profile <profile>

cd terraform
terraform plan -out=tfplan
terraform apply tfplan
cd ..

aws eks list-pod-identity-associations `
  --cluster-name <cluster-name> --region <region> --profile <profile>

kubectl create serviceaccount s3-test -n default
kubectl get serviceaccount s3-test -n default

@'
apiVersion: v1
kind: Pod
metadata:
  name: s3-test-client
  namespace: default
spec:
  serviceAccountName: s3-test
  restartPolicy: Never
  containers:
    - name: aws-cli
      image: amazon/aws-cli:latest
      command: ["sh", "-c", "sleep 3600"]
'@ | kubectl apply -f -

kubectl get pod s3-test-client
kubectl exec s3-test-client -- aws sts get-caller-identity
kubectl exec s3-test-client -- sh -c "echo 'Hello from EKS Pod Identity' > /tmp/hello.txt"
kubectl exec s3-test-client -- aws s3 cp /tmp/hello.txt s3://<your-test-bucket>/hello.txt
kubectl exec s3-test-client -- aws s3 ls s3://<your-test-bucket>
kubectl exec s3-test-client -- aws s3 cp s3://<your-test-bucket>/hello.txt -
```

Ensure the Pod Identity association targets ServiceAccount `s3-test` in `default` (see Terraform module).

## Cleanup

```powershell
kubectl exec s3-test-client -- aws s3 rm s3://<your-test-bucket>/hello.txt
kubectl delete pod s3-test-client --ignore-not-found
kubectl delete serviceaccount s3-test -n default --ignore-not-found

cd terraform
# Remove s3_test_bucket_name from terraform.tfvars, then remove only this lab's role/association.
terraform plan -out=tfplan
terraform apply tfplan
cd ..

aws s3 rb s3://<your-test-bucket> --region <region> --profile <profile>
```

Removing `s3_test_bucket_name` disables the optional association in future plans.
