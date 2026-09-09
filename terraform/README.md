# Terraform — Assessment IV

## What this stack owns

| Owns (Terraform) | Does NOT own |
|------------------|--------------|
| Namespaces: `fraud`, `recommendations`, `forecasting`, `platform` | Class EKS cluster `k8s-training-cluster` |
| Platform `Role` / `RoleBinding` (read-only) | ConfigMaps (YAML + Actions — single writer) |
| Remote state in S3 + DynamoDB lock | Deployments / Services / Secrets / ResourceQuotas |
| | Other students' namespaces / VPC / node groups |

ConfigMaps (`ENDPOINT_NAME`, `WEIGHT_A`) are applied from `k8s/*/configmap.yml` so deploy and `demo-failure.sh` do not fight Terraform.

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

```bash
cd terraform
terraform import 'kubernetes_namespace.team["fraud"]' fraud
terraform import 'kubernetes_namespace.team["recommendations"]' recommendations
terraform import 'kubernetes_namespace.team["forecasting"]' forecasting
terraform import kubernetes_namespace.platform platform
terraform apply
```

## Dropping legacy ConfigMap resources from state

If an older apply still tracks ConfigMaps in remote state, remove them from state **without** deleting the live objects (Actions owns them now):

```bash
cd terraform
terraform state rm 'kubernetes_config_map.team["fraud"]' \
  'kubernetes_config_map.team["recommendations"]' \
  'kubernetes_config_map.team["forecasting"]' \
  kubernetes_config_map.gateway
terraform plan   # should show no ConfigMap destroys
```

## Change A/B weight

Edit `k8s/platform/configmap.yml` (`WEIGHT_A`), apply via Actions or:

```bash
kubectl apply -f k8s/platform/configmap.yml
kubectl -n platform rollout restart deployment/gateway-api
```
