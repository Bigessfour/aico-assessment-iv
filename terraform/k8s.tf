# =============================================================================
# Kubernetes objects managed by Terraform (bonus: Kubernetes provider)
# =============================================================================
# Ownership boundary:
#   Terraform → Namespace, ConfigMap, platform Role/RoleBinding
#   kubectl YAML / Actions → Deployments, Services, Secrets, ResourceQuota
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
      team                              = each.key
      "app.kubernetes.io/part-of"       = "ml-platform"
      "app.kubernetes.io/managed-by"    = "terraform"
      owner                             = replace(each.value.owner, " ", "-")
    }
  }

  # Soft guard: prefer import over accidental delete of a live team namespace mid-demo.
  lifecycle {
    prevent_destroy = false
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

# --- Per-team ConfigMaps (ENDPOINT_NAME routing isolation) ---
# Deployments still use envFrom → these keys; keep names stable.
resource "kubernetes_config_map" "team" {
  for_each = var.teams

  metadata {
    name      = "${each.key}-config"
    namespace = kubernetes_namespace.team[each.key].metadata[0].name
    labels = {
      team                           = each.key
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  data = {
    ENDPOINT_NAME           = each.value.endpoint
    AWS_REGION              = var.aws_region
    LOG_LEVEL               = "info"
    INVOKE_TIMEOUT_SECONDS  = "10"
  }
}

# --- Gateway ConfigMap (in-cluster DNS + A/B weight) ---
resource "kubernetes_config_map" "gateway" {
  metadata {
    name      = "gateway-config"
    namespace = kubernetes_namespace.platform.metadata[0].name
    labels = {
      team                           = "platform"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  data = {
    FRAUD_URL               = "http://fraud-api.fraud.svc.cluster.local"
    RECOMMENDATIONS_URL     = "http://recommendations-api.recommendations.svc.cluster.local"
    FORECASTING_URL         = "http://forecasting-api.forecasting.svc.cluster.local"
    WEIGHT_A                = var.gateway_weight_a
    HTTP_TIMEOUT_SECONDS    = "15"
    CORS_ORIGINS            = "*"
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
