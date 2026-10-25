module "s3_test_pod_identity" {
  count   = var.s3_test_bucket_name == "" ? 0 : 1
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "~> 2.0"

  name        = "devops-lab-s3-test"
  description = "Limited S3 access for the s3-test Kubernetes ServiceAccount"

  attach_custom_policy = true

  policy_statements = [
    {
      sid       = "ListTestBucket"
      effect    = "Allow"
      actions   = ["s3:ListBucket"]
      resources = ["arn:aws:s3:::${var.s3_test_bucket_name}"]
    },
    {
      sid    = "ReadWriteTestBucketObjects"
      effect = "Allow"
      actions = [
        "s3:GetObject",
        "s3:PutObject"
      ]
      resources = ["arn:aws:s3:::${var.s3_test_bucket_name}/*"]
    }
  ]

  associations = {
    s3_test = {
      cluster_name    = module.eks.cluster_name
      namespace       = "default"
      service_account = "s3-test"
    }
  }
}
