# =============================================================================
# Kubernetes objects managed by Terraform (bonus: Kubernetes provider)
# =============================================================================
# Ownership boundary (single owner — no dual-write):
#   Terraform → Namespace, platform Role/RoleBinding, platform-metadata ConfigMap
#   kubectl YAML / Actions → app ConfigMaps, Deployments, Services, Secrets, quotas
#
# App ConfigMaps (ENDPOINT_NAME, WEIGHT_A) live in k8s/*/configmap.yml so deploy
# and demo-failure.sh are their only writers. platform-metadata is different: it
# carries infrastructure facts only Terraform knows, and no workflow applies it.
#
# If namespaces already exist from earlier kubectl apply, import them once:
#   terraform import 'kubernetes_namespace.team["fraud"]' fraud
#   terraform import 'kubernetes_namespace.team["recommendations"]' recommendations
#   terraform import 'kubernetes_namespace.team["forecasting"]' forecasting
#   terraform import kubernetes_namespace.platform platform
# =============================================================================

# --- Team namespaces (fraud / recommendations / forecasting) ---
resource "kubernetes_namespace" "team" {
  for_each = var.teams

  metadata {
    name = each.key
    labels = {
      team                           = each.key
      "app.kubernetes.io/part-of"    = "ml-platform"
      "app.kubernetes.io/managed-by" = "terraform"
      owner                          = replace(each.value.owner, " ", "-")
    }
  }
}

# --- Platform namespace (gateway + dashboard) ---
resource "kubernetes_namespace" "platform" {
  metadata {
    name = "platform"
    labels = {
      team                           = "platform"
      "app.kubernetes.io/part-of"    = "ml-platform"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

# --- Minimal RBAC: platform read-only Role for demo / future dashboard SA ---
resource "kubernetes_role" "platform_read" {
  metadata {
    name      = "platform-read"
    namespace = kubernetes_namespace.platform.metadata[0].name
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "services", "configmaps"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["apps"]
    resources  = ["deployments"]
    verbs      = ["get", "list", "watch"]
  }
}

# --- Infrastructure facts published into the cluster (Terraform is sole writer) ---
resource "kubernetes_config_map" "platform_metadata" {
  metadata {
    name      = "platform-metadata"
    namespace = kubernetes_namespace.platform.metadata[0].name
    labels = {
      "app.kubernetes.io/part-of"    = "ml-platform"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  data = {
    CLUSTER_NAME       = data.aws_eks_cluster.class.name
    AWS_REGION         = var.aws_region
    ENVIRONMENT        = var.environment
    SSM_PREFIX         = local.ssm_prefix
    PLATFORM_LOG_GROUP = aws_cloudwatch_log_group.platform.name
    ENDPOINT_CATALOG   = jsonencode({ for k, v in var.teams : k => v.endpoint })
  }
}

resource "kubernetes_role_binding" "platform_read" {
  metadata {
    name      = "platform-read"
    namespace = kubernetes_namespace.platform.metadata[0].name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.platform_read.metadata[0].name
  }

  # Bind to the default SA for a simple demo; tighten later if needed.
  subject {
    kind      = "ServiceAccount"
    name      = "default"
    namespace = kubernetes_namespace.platform.metadata[0].name
  }
}
