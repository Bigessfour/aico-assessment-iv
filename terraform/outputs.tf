# Outputs for graders / CI / talking points.

output "region" {
  description = "AWS region this stack targets."
  value       = var.aws_region
}

output "project_name" {
  description = "Project name tag."
  value       = var.project_name
}

output "eks_cluster_name" {
  description = "Class EKS cluster we reference (not created by this stack)."
  value       = data.aws_eks_cluster.class.name
}

output "eks_cluster_endpoint" {
  description = "API server endpoint for the class cluster."
  value       = data.aws_eks_cluster.class.endpoint
}

output "managed_namespaces" {
  description = "Namespaces owned by Terraform (teams + platform)."
  value = concat(
    [for ns in kubernetes_namespace.team : ns.metadata[0].name],
    [kubernetes_namespace.platform.metadata[0].name],
  )
}

output "team_endpoints" {
  description = "Intended SageMaker endpoint names (wired at deploy via k8s ConfigMaps)."
  value       = { for k, v in var.teams : k => v.endpoint }
}

output "teardown_note" {
  description = "Reminder for destroy scope."
  value       = "terraform destroy removes ONLY namespaces/RBAC in this state — never the class EKS cluster. ConfigMaps/Deployments are Actions/YAML-owned."
}
