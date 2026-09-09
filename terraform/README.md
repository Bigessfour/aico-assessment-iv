# Terraform — Assessment IV

## What this stack owns

| Owns (Terraform) | Does NOT own |
|------------------|--------------|
| SSM parameters: `/ml-platform/dev/<team>/{endpoint_name,owner}` | Class EKS cluster `k8s-training-cluster` |
| CloudWatch log group `/ml-platform/dev/platform` | App ConfigMaps (YAML + Actions — single writer) |
| Namespaces: `fraud`, `recommendations`, `forecasting`, `platform` | Deployments / Services / Secrets / ResourceQuotas |
| Platform `Role` / `RoleBinding` (read-only) | SageMaker endpoints and models |
| ConfigMap `platform/platform-metadata` (infra facts) | Other students' namespaces / VPC / node groups |
| Remote state in S3 + DynamoDB lock | |

Two kinds of ConfigMap, one writer each:

- **App config** (`ENDPOINT_NAME`, `MODEL_VERSION`, `WEIGHT_A`) comes from `k8s/*/configmap.yml`, applied by Actions and edited by `demo-failure.sh`. Terraform never touches it.
- **`platform-metadata`** carries facts only Terraform knows — cluster name, SSM prefix, log group, endpoint catalog. No workflow applies it.

Parameter Store is the authoritative endpoint catalog. `scripts/verify.sh` diffs each namespace's live ConfigMap against it and fails on drift (and skips quietly if the parameters are not readable).

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

Or run it from CI: **Actions → Terraform → Run workflow** with `action = plan | apply | destroy`. Pull requests that touch `terraform/` get an automatic `fmt`, `validate`, and `plan`. Destroy additionally requires typing `destroy-my-infra`.

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
