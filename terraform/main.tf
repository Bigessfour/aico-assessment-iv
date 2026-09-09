# Legacy skeleton entrypoint kept so `terraform/` still has a clear main file.
# Real logic lives in versions.tf / providers.tf / k8s.tf / variables.tf / outputs.tf.
#
# Prefer: terraform init && terraform plan && terraform apply
# See README.md in this directory for import + teardown notes.

locals {
  stack_summary = "Assessment IV Terraform manages namespaces/ConfigMaps/RBAC only"
}
