module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = "devops-lab"
  kubernetes_version = "1.35"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  enable_cluster_creator_admin_permissions = true

  endpoint_public_access         = true
  endpoint_public_access_cidrs = var.cluster_endpoint_allowed_cidrs

  node_security_group_tags = {
    "karpenter.sh/discovery" = "devops-lab"
  }

  addons = {
    coredns = {
      most_recent = true
    }

    kube-proxy = {
      most_recent = true
    }

    vpc-cni = {
      most_recent    = true
      before_compute = true
    }
    aws-ebs-csi-driver = {
      addon_version = "v1.66.0-eksbuild.1"
    }
    eks-pod-identity-agent = {
      most_recent = true
    }
    aws-efs-csi-driver = {
      most_recent = true
    }
  }

  eks_managed_node_groups = {
    worker-ng = {
      name = "worker-ng"

      instance_types = ["t3.small"]

      min_size     = 1
      max_size     = 3
      desired_size = 3

      capacity_type = "ON_DEMAND"

      disk_size = 20
    }
  }

  node_security_group_additional_rules = {
    ingress_http_from_nodes = {
      description = "Allow HTTP between EKS worker nodes"
      protocol    = "tcp"
      from_port   = 80
      to_port     = 80
      type        = "ingress"
      self        = true
    }
  }

  tags = {
    Environment = "dev"
    Project     = "eks-terraform-lab"
  }
}



module "ebs_csi_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "~> 2.0"

  name = "devops-lab-ebs-csi"

  attach_aws_ebs_csi_policy = true

  associations = {
    ebs_csi = {
      cluster_name    = module.eks.cluster_name
      namespace       = "kube-system"
      service_account = "ebs-csi-controller-sa"
    }
  }
}

# resource "aws_efs_file_system" "devops_lab" {
#   creation_token = "devops-lab-efs"
#   encrypted      = true

#   tags = {
#     Name        = "devops-lab-efs"
#     Environment = "dev"
#     Project     = "eks-terraform-lab"
#   }
# }

# resource "aws_security_group" "efs" {
#   name        = "devops-lab-efs"
#   description = "Allow NFS from EKS worker nodes"
#   vpc_id      = module.vpc.vpc_id

#   ingress {
#     description     = "NFS from EKS worker nodes"
#     from_port       = 2049
#     to_port         = 2049
#     protocol        = "tcp"
#     security_groups = [module.eks.node_security_group_id]
#   }

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   tags = {
#     Name    = "devops-lab-efs"
#     Project = "eks-terraform-lab"
#   }
# }

# resource "aws_efs_mount_target" "devops_lab" {
#   for_each = {
#     for index, subnet_id in module.vpc.private_subnets : index => subnet_id
#   }

#   file_system_id  = aws_efs_file_system.devops_lab.id
#   subnet_id       = each.value
#   security_groups = [aws_security_group.efs.id]
# }

# module "efs_csi_pod_identity" {
#   source  = "terraform-aws-modules/eks-pod-identity/aws"
#   version = "~> 2.0"

#   name                      = "devops-lab-efs-csi"
#   attach_aws_efs_csi_policy = true

#   associations = {
#     efs_csi = {
#       cluster_name    = module.eks.cluster_name
#       namespace       = "kube-system"
#       service_account = "efs-csi-controller-sa"
#     }
#   }
# }
