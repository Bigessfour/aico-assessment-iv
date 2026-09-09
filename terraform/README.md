# Terraform — Assessment IV

## What this stack owns

| Owns (Terraform) | Does NOT own |
|------------------|--------------|
| Namespaces: `fraud`, `recommendations`, `forecasting`, `platform` | Class EKS cluster `k8s-training-cluster` |
| Team ConfigMaps (`*-config`) + `gateway-config` | Deployments / Services / Secrets / ResourceQuotas (kubectl + Actions) |
| Platform `Role` / `RoleBinding` (read-only) | Other students' namespaces |
| Remote state in S3 + DynamoDB lock | VPC / node groups |

## Prerequisites

```bash
export AWS_PROFILE=codeplatoon
export AWS_REGION=us-east-1
aws eks update-kubeconfig --region us-east-1 --name k8s-training-cluster
./scripts/bootstrap-tf-backend.sh   # once: S3 bucket + DynamoDB lock table
```

## Lifecycle

```bash
cd terraform
terraform init
terraform plan
terraform apply
terraform destroy   # ONLY resources in this state — never the class cluster
```

## Import existing namespaces (first apply after kubectl created them)

If namespaces already exist, import before apply to avoid "already exists" errors:

```bash
cd terraform
terraform import 'kubernetes_namespace.team["fraud"]' fraud
terraform import 'kubernetes_namespace.team["recommendations"]' recommendations
terraform import 'kubernetes_namespace.team["forecasting"]' forecasting
terraform import kubernetes_namespace.platform platform
terraform apply
```

ConfigMaps with the same names will be adopted/updated on apply.

## Change A/B weight

```bash
terraform apply -var='gateway_weight_a=50'
kubectl -n platform rollout restart deployment/gateway-api
```
