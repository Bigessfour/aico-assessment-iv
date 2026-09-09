# AWS + Kubernetes providers.
# Kubernetes auth uses the EKS data sources (short-lived token) — no static kubeconfig in git.

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
      Assessment  = "aico-iv"
    }
  }
}

# Read-only look up of the SHARED class cluster (hard constraint: do not own it).
data "aws_eks_cluster" "class" {
  name = var.cluster_name
}

data "aws_eks_cluster_auth" "class" {
  name = var.cluster_name
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.class.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.class.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.class.token
}
