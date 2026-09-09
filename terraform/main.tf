# Legacy skeleton entrypoint kept so `terraform/` still has a clear main file.
# Real logic lives in versions.tf / providers.tf / aws.tf / k8s.tf / variables.tf / outputs.tf.
#
# Prefer: terraform init && terraform plan && terraform apply
# See README.md in this directory for import + teardown notes.

locals {
  stack_summary = "Assessment IV Terraform manages SSM catalog, CloudWatch log group, namespaces, platform RBAC, and the platform-metadata ConfigMap"

  # Parameter Store / CloudWatch naming. Single place to change the prefix.
  ssm_prefix       = "/${var.project_name}/${var.environment}"
  log_group_prefix = "/${var.project_name}/${var.environment}"
}
