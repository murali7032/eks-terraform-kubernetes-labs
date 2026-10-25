# Provision the EKS lab

This configuration creates a VPC, an EKS cluster and managed node group, EBS/EFS CSI support, EFS mount targets, and Karpenter IAM integration. The optional standalone Elasticsearch EC2 host is disabled by default.

## Requirements

- An AWS account with permission to create EKS, EC2, VPC, IAM, EFS, and related resources.
- AWS CLI credentials for the selected profile.
- Terraform `>= 1.13`, `kubectl`, and (for addon labs) Helm.
- Quota and regional availability for the configured EKS version, instance types, and resources.

## Create the cluster

Run commands from this directory:

```powershell
Copy-Item terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars to select an AWS region and configured CLI profile.
# Set cluster_endpoint_allowed_cidrs to your current public IPv4 address in /32 notation.
terraform init
terraform fmt -check
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

Review the plan before applying. Keep `terraform.tfvars`, state files, and plan files private; they can contain account-specific or sensitive values. The repository ignores these local artifacts.

After apply, configure kubectl using the actual cluster name and selected profile:

```powershell
$region = terraform output -raw aws_region
$clusterName = terraform output -raw cluster_name
$profile = terraform output -raw aws_profile
aws eks update-kubeconfig --region $region --name $clusterName --profile $profile
kubectl get nodes
```

The Kubernetes API endpoint is public and Terraform requires one or more trusted IPv4 `/32` CIDRs before it can plan. Update the allowed address if your public IP changes.

## Optional standalone Elasticsearch host

The host is disabled by default. It costs extra and runs a lab configuration with Elasticsearch security disabled. If you choose to enable it, first set the following in `terraform.tfvars`:

```hcl
enable_external_elasticsearch = true
elasticsearch_allowed_cidr    = "YOUR.PUBLIC.IP.ADDRESS/32"
elasticsearch_key_name        = "YOUR_EXISTING_EC2_KEY_PAIR"
```

Never use `0.0.0.0/0` for this lab. Disable the variable and apply or destroy the host as soon as the exercise is finished.

## Costs and cleanup

EKS control plane, EC2 worker nodes, NAT Gateway, EFS storage/mount targets, EBS volumes, load balancers, and optional Elasticsearch host can incur charges. Delete Kubernetes lab resources and load balancers, then from this directory run:

```powershell
terraform destroy
```

Check the AWS console for retained EBS volumes and other manually created resources after destroy. Back up any data you want to keep first; Terraform destroy removes the infrastructure.
