terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "project_name" {
  type    = string
  default = "ml-platform"
}

variable "environment" {
  type    = string
  default = "dev"
}

output "region" {
  value = var.aws_region
}

output "project_name" {
  value = var.project_name
}
