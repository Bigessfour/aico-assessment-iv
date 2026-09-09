# =============================================================================
# Terraform — Assessment IV platform (OUR resources only)
# =============================================================================
# Talking points:
#   - Does NOT create/destroy the class EKS cluster (data-source only).
#   - Owns namespaces + ConfigMaps (+ platform read Role) via Kubernetes provider.
#   - Deployments/Services stay as kubectl YAML so we do not fight two owners.
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
