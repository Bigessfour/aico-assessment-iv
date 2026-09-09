# Input variables — no hardcoded credentials (assessment requirement).

variable "aws_region" {
  type        = string
  description = "AWS region for the class account (Code Platoon uses us-east-1)."
  default     = "us-east-1"
}

variable "project_name" {
  type        = string
  description = "Short name used in tags / outputs for this assessment."
  default     = "ml-platform"
}

variable "environment" {
  type        = string
  description = "Environment label (dev/stage/prod). Class work stays on dev."
  default     = "dev"
}

variable "cluster_name" {
  type        = string
  description = "Existing class EKS cluster name. Referenced only — never created here."
  default     = "k8s-training-cluster"
}

variable "teams" {
  type = map(object({
    endpoint = string
    owner    = string
  }))
  description = "Team namespaces → SageMaker endpoint names (routing isolation catalog)."
  default = {
    fraud = {
      endpoint = "aico-iv-fraud"
      owner    = "Fraud Detection Team"
    }
    recommendations = {
      endpoint = "aico-iv-recs"
      owner    = "Recommendations Team"
    }
    forecasting = {
      endpoint = "aico-iv-forecast"
      owner    = "Forecasting Team"
    }
  }
}
