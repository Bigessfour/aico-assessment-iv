# =============================================================================
# AWS resources created by this stack
# =============================================================================
# Why these two:
#   - SSM Parameter Store holds the team -> SageMaker endpoint catalog. Terraform
#     is the source of truth for those names; k8s ConfigMaps carry the same value
#     into the pods, and scripts/verify.sh can diff cluster reality against it.
#   - A CloudWatch log group gives the platform namespace a durable log sink that
#     is not tied to any single pod lifetime.
#
# Both are free-tier friendly and fully removed by terraform destroy. Nothing in
# this file touches the shared EKS cluster or the team SageMaker endpoints.
# =============================================================================

resource "aws_ssm_parameter" "team_endpoint" {
  for_each = var.teams

  name        = "${local.ssm_prefix}/${each.key}/endpoint_name"
  description = "SageMaker endpoint owned by the ${each.value.owner}."
  type        = "String"
  value       = each.value.endpoint
  tier        = "Standard"

  tags = {
    Team = each.key
  }
}

resource "aws_ssm_parameter" "team_owner" {
  for_each = var.teams

  name        = "${local.ssm_prefix}/${each.key}/owner"
  description = "Business unit accountable for the ${each.key} namespace."
  type        = "String"
  value       = each.value.owner

  tags = {
    Team = each.key
  }
}

resource "aws_cloudwatch_log_group" "platform" {
  name              = "${local.log_group_prefix}/platform"
  retention_in_days = var.log_retention_days
}
