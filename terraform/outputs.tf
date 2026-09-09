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

output "ssm_endpoint_parameters" {
  description = "Parameter Store names holding the authoritative endpoint catalog."
  value       = { for k, p in aws_ssm_parameter.team_endpoint : k => p.name }
}

output "platform_log_group" {
  description = "CloudWatch log group created for platform-level logs."
  value       = aws_cloudwatch_log_group.platform.name
}

output "platform_metadata_configmap" {
  description = "Terraform-owned ConfigMap publishing infra facts into the cluster."
  value       = "${kubernetes_config_map.platform_metadata.metadata[0].namespace}/${kubernetes_config_map.platform_metadata.metadata[0].name}"
}

output "teardown_note" {
  description = "Reminder for destroy scope."
  value       = "terraform destroy removes ONLY this state: SSM parameters, the platform log group, namespaces, platform RBAC, and platform-metadata. Never the class EKS cluster. App ConfigMaps/Deployments are Actions/YAML-owned."
}
