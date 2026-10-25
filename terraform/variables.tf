variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "aws_profile" {
  description = "AWS CLI profile"
  type        = string
  default     = "devops-lab"
}

variable "cluster_endpoint_allowed_cidrs" {
  description = "Public IPv4 /32 CIDRs allowed to reach the EKS Kubernetes API endpoint. Set to your current public IP before planning."
  type        = list(string)

  validation {
    condition = length(var.cluster_endpoint_allowed_cidrs) > 0 && alltrue([
      for cidr in var.cluster_endpoint_allowed_cidrs : can(cidrnetmask(cidr)) && endswith(cidr, "/32")
    ])
    error_message = "Set at least one trusted IPv4 address in /32 notation for the EKS API endpoint."
  }
}

variable "enable_external_elasticsearch" {
  description = "Create the optional standalone Elasticsearch EC2 lab host. It is public and incurs additional cost."
  type        = bool
  default     = false
}

variable "elasticsearch_allowed_cidr" {
  description = "Single IPv4 CIDR allowed to reach the optional Elasticsearch host. Set this to your current public IP /32 before enabling the host."
  type        = string
  default     = "127.0.0.1/32"

  validation {
    condition     = can(cidrnetmask(var.elasticsearch_allowed_cidr)) && endswith(var.elasticsearch_allowed_cidr, "/32")
    error_message = "elasticsearch_allowed_cidr must be one IPv4 address in /32 notation."
  }
}

variable "elasticsearch_key_name" {
  description = "Existing EC2 key pair name for the optional Elasticsearch host. Leave null unless the host is enabled."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition     = var.elasticsearch_key_name == null || trimspace(var.elasticsearch_key_name) != ""
    error_message = "elasticsearch_key_name must be an existing key pair name or null."
  }
}

variable "s3_test_bucket_name" {
  description = "Name of an existing disposable S3 bucket for the optional Pod Identity lab. Leave empty to skip creating its IAM role and association."
  type        = string
  default     = ""
}
