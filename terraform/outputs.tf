output "elasticsearch_public_ip" {
  description = "Public IP of Elasticsearch EC2"
  value       = try(aws_instance.elasticsearch[0].public_ip, null)
}

output "efs_file_system_id" {
  description = "EFS file system ID used by the static EFS PV lab"
  value       = aws_efs_file_system.devops_lab.id
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "aws_region" {
  description = "AWS region used by this Terraform configuration"
  value       = var.aws_region
}

output "aws_profile" {
  description = "AWS CLI profile used by this Terraform configuration"
  value       = var.aws_profile
}

