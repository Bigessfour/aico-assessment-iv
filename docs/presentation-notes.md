# Presentation notes — Assessment IV (Scenario 1)

5–8 minute talking track. Be honest about what is a label vs a real multi-model setup.

## One-liner

Internal ops platform: three team FastAPI wrappers on class EKS, each pinned to its own SageMaker endpoint, with Actions deploy, Terraform for namespaces/ConfigMaps/RBAC, a gateway, and a React dashboard.

## Demo order (live)

1. **Dashboard** — `kubectl -n platform port-forward svc/ops-dashboard 3000:80` → http://localhost:3000  
   Show live poll, owner, version, test-predict (endpoint + variant in JSON).
2. **Isolation** — `./scripts/verify.sh` or point at Actions logs: each pod’s `ENDPOINT_NAME` matches its team.
3. **Failure (optional, always restore)** — `./scripts/demo-failure.sh quota` (FailedCreate / pods=4) or `ready` (empty `ENDPOINT_NAME` → Ready=False, `/ready` 503). Trap restores.
4. **Teardown story** — Destroy workflow / `terraform destroy` only **our** resources; never the class cluster.

## Architecture in one breath

GitHub Actions builds `linux/amd64` → GHCR → applies `k8s/{fraud,recommendations,forecasting,platform}` → pins SHA → verifies. Gateway aggregates health and proxies `POST /predict/{team}`. Terraform owns namespaces + ConfigMaps + platform read RBAC + remote state; Deployments stay YAML/Actions.

## Design decisions / Q&A

| Question | Answer |
|----------|--------|
| Why ClusterIP? | Shared class cluster; no LoadBalancer tax; demos via port-forward. |
| Why 1 replica? | Quota headroom; failure demos scale temporarily then restore. |
| What is A/B? | ConfigMap `WEIGHT_A` → response `variant` label. **Not** two SageMaker model variants. |
| Why empty `ENDPOINT_NAME` for ready demo? | `/ready` only checks “set + client constructable”; a wrong name still returns 200. |
| Who owns the cluster? | Class `k8s-training-cluster`. We data-source it; we do not create/destroy it. |
| Secrets? | Actions creates AWS + GHCR secrets at deploy time; never commit live Secret YAML. |
| Apple Silicon? | Always `--platform linux/amd64` or ImagePullBackOff. |

## Rubric map (say if asked)

- **K8s 30%** — three ns, ConfigMaps/Secrets, three probes, quota/LimitRange; bonus failure scripts.
- **SageMaker 25%** — three wrappers, isolation, 502/timeout path; gateway + A/B label.
- **Actions 15%** — real deploy + verify; bonuses: rollback, lint, destroy-workloads, CI chain, `git_ref`.
- **Terraform 10%** — vars/outputs/lifecycle + remote state + K8s provider.
- **UI 10%** — React + Tailwind CDN; poll, version, test-predict.
- **Docs 10%** — README mermaid, History.md, these notes.

## Do not claim

- Dual SageMaker model versions for A/B.
- That Terraform manages Deployments or the EKS cluster.
- That README/dashboard are still starters (they are not on current `main`).

## Backup if AWS is flaky

- Screenshots / Actions run links in History.md.
- Port-forward may fail if session expired — `export AWS_PROFILE=codeplatoon` and refresh kubeconfig.
