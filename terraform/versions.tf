# =============================================================================
# Terraform — Assessment IV platform (OUR resources only)
# =============================================================================
# Talking points:
#   - Does NOT create/destroy the class EKS cluster (data-source only).
#   - Owns the SSM endpoint catalog + platform CloudWatch log group in AWS.
#   - Owns namespaces, platform read Role, and the platform-metadata ConfigMap.
#   - Deployments/Services/app ConfigMaps stay kubectl YAML — one owner each.
#   - Remote state: S3 + DynamoDB (see backend.tf + scripts/bootstrap-tf-backend.sh)
#
# Lifecycle:
#   cd terraform
#   terraform init
#   terraform plan
#   terraform apply
#   terraform destroy   # ONLY objects in this state — never the class cluster
# =============================================================================

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.29"
    }
  }
}
