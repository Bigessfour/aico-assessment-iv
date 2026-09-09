# Agent instructions — Assessment IV

Repo: [`Bigessfour/aico-assessment-iv`](https://github.com/Bigessfour/aico-assessment-iv) (private)  
Upstream brief: [docs/assessment-brief.md](docs/assessment-brief.md)  
Working log: [History.md](History.md)  
Machine: MacBook Pro (Apple Silicon). Cluster workers are **linux/amd64**.

## Mission

Ship a **demoable internal ML platform** that a grader can reproduce from the README.

Score the **required rubric first**. Bonuses are stretch after the required vertical is green. A late or incomplete required slice costs more than a missing bonus.

**All required rubric items and every listed bonus are implemented on `main`.** Remaining work is the presentation itself (rehearsal, demo order, Q&A) plus optional branch cleanup.

Scenario (locked): **Scenario 1 — ML Platform**  
Teams / SageMaker endpoints:

| Team namespace | SageMaker `ENDPOINT_NAME` |
|----------------|---------------------------|
| `fraud` | `aico-iv-fraud` |
| `recommendations` | `aico-iv-recs` |
| `forecasting` | `aico-iv-forecast` |

AWS: profile `codeplatoon`, account `388691194728`, region `us-east-1`, cluster `k8s-training-cluster` (class-shared EKS).

---

## Ground truth (do not invent a greener state)

As of **2026-09-08**. `main` tip: **`712c6a7`** (merge of PR #6 README).  
Latest **CI** and **Build and Deploy** on `main` succeeded ([deploy run](https://github.com/Bigessfour/aico-assessment-iv/actions/runs/34294222918)).

### Done on `main` (PRs #1–#6; Terraform via PR #5 when merged)

| Slice | Status | Evidence |
|-------|--------|----------|
| Three team FastAPI + EKS | **Done** | PR #2. Namespaces `fraud` / `recommendations` / `forecasting`. Isolated `ENDPOINT_NAME` verified in Actions |
| Probes, ConfigMaps, Secrets, quota | **Done** | Per-team manifests; deploy job creates AWS/GHCR secrets from Actions secrets (never apply `secret.example.yml`) |
| Real `deploy.yml` | **Done** | PR #3 + #4. Matrix `linux/amd64` → GHCR (`:latest` + SHA) → apply → pin → rollout + isolation + in-cluster `/health` `/ready` |
| Gateway | **Done** | `services/gateway` + `k8s/platform`. Aggregate `/health`, `POST /predict/{team}`, ClusterIP |
| A/B | **Done enough to talk** | ConfigMap `WEIGHT_A=80`; responses labeled `variant` A/B. **Not** two SageMaker model variants — say that out loud |
| Ops UI | **Done** | React + Tailwind (CDN): live poll, version, owner, test-predict via nginx `/api` → gateway |
| README + architecture | **Done** | PR #6. Mermaid + setup/deploy/verify/teardown |
| Terraform | **This PR #5** | Remote state + K8s provider for ns/ConfigMaps/platform RBAC; cluster data-source only |
| `History.md` | **Good** | Failures + fixes recorded |

### Not on `main` yet / behind

| Slice | Status | Notes |
|-------|--------|-------|
| Controlled failure demo | **Done** | `scripts/demo-failure.sh` + `verify.sh`; History evidence; always restore |
| Actions bonuses | **Done** | rollback, lint, destroy-workloads, chain-after-deploy, deploy `git_ref` |
| Presentation notes | **Done** | `docs/presentation-notes.md` |
| Leftover remote branches | Cleanup | Delete merged feature branch leftovers |

### What is actually on `main` (plus this PR for terraform/)

```text
services/   fraud-detection, recommendations, forecasting, gateway
k8s/        fraud, recommendations, forecasting, platform
dashboard/  React ops UI (Tailwind via CDN — package.json has no tailwind dep)
.github/    ci.yml (syntax + manifest presence) + deploy.yml (real path)
terraform/  full stack on PR #5 (remote state + k8s provider); skeleton only until merge
docs/       assessment-brief.md (presentation-notes still TODO)
README.md   grader-facing (PR #6)
```

### Demo path (verified)

```bash
export AWS_PROFILE=codeplatoon
kubectl -n platform port-forward svc/ops-dashboard 3000:80
# http://localhost:3000
```

### Naming (do not confuse)

- **Namespaces:** `fraud` / `recommendations` / `forecasting` / `platform`
- **SageMaker endpoint names:** `aico-iv-*` (ConfigMap `ENDPOINT_NAME` only)
- Do not rename namespaces unless every apply/verify/docs command is updated

Mark a checklist item **done** only after it exists on the branch you are working **and** is recorded in `History.md`. Prefer “done on `main`” language for grader-facing claims.

---

## Honest rubric read (2026-09-09, after the bonus sweep)

| Section | Weight | Estimate | Why |
|---------|--------|----------|-----|
| Kubernetes | 30% | Strong | Three ns + platform, three probes each, ResourceQuota + LimitRange everywhere, reversible failure demos |
| SageMaker | 25% | Strong | Three wrappers, isolation proven in Actions, 502/504 paths, gateway, weighted variant split with counters |
| Actions | 15% | Strong | deploy, CI (validate + pytest + dashboard build), terraform, lint, rollback, destroy-workloads, chained verify |
| UI | 10% | Strong | React + Tailwind; polling, service + model version, request counts, test-request (4 of 4 options) |
| Terraform | 10% | Strong | Real AWS resources (SSM catalog + log group), K8s namespaces/RBAC/metadata ConfigMap, S3 + DynamoDB state |
| Docs | 10% | Good | README + mermaid + teardown + History narrative; presentation rehearsal outstanding |

### Things to say out loud before a grader asks

1. **A/B is a gateway-side split, not two SageMaker production variants.** Weighted labels `baseline` / `candidate`, forwarded as `X-Model-Variant`, counted on `/stats`.
2. **Gateway counters are process-local** and reset on pod restart. Deliberate: an ops demo, not Prometheus.
3. **Terraform never owns the class cluster** — data source only. It owns SSM parameters, the platform log group, our namespaces, platform RBAC, and `platform-metadata`.
4. **Two ConfigMap owners by design, never for the same object.** App config is Actions/YAML; infra facts are Terraform.

---

## Hard constraints (shared class account)

1. **Do not** create, modify, or `terraform destroy` the class EKS cluster, VPC, node groups, or other students' namespaces.
2. Terraform may **reference / data-source** `k8s-training-cluster`. It must not try to own it.
3. Never commit `.env`, `.env.secrets`, live Secret YAML, AWS keys, or `GHCR_TOKEN`.
4. Prefer `AWS_PROFILE=codeplatoon` (Keychain) over `aws login` for deploy loops — login grants expire mid-session (see History.md).
5. Images: `docker build --platform linux/amd64` then push GHCR. Arm64 → `ImagePullBackOff`.
6. Prefer `kubectl port-forward` for demos; do not add curl to every image just for checks.
7. Keep Services **ClusterIP** unless an LB is truly required. Class clusters fill up with leftover LBs.
8. Quotas are tight. Stay at **1 replica** unless a failure demo needs a second pod, then scale back.
9. After a controlled-failure demo, **restore** the healthy state before leaving the session.
10. Do not rewrite working team apps into a monorepo framework. Duplicate-and-specialize is the class pattern.
11. Destroy workflows may delete **only** `fraud` / `recommendations` / `forecasting` / `platform` — never the cluster.

---

## Rubric priority (weight → work)

| Weight | Section | Required bar | Bonus (only after required) |
|--------|---------|--------------|-----------------------------|
| 30% | K8s | 3 namespaces, ConfigMaps, Secrets, 3 probes, ResourceQuota + LimitRange | Reversible controlled failure + History.md evidence |
| 25% | SageMaker | 3 FastAPI wrappers, isolated routing, `/health` `/ready` `/predict`, one failure path | Gateway (done) + A/B label (done — not two endpoints) |
| 15% | Actions | Real `deploy.yml`: build → GHCR → apply → verify (done on `main`) | Rollback, branch targeting, chained workflows, lint/destroy |
| 10% | Terraform | Vars/outputs + documented lifecycle for **our** resources | Remote state + K8s provider (implemented on PR #5; merge then update README) |
| 10% | UI | Multi-team health + owner; ≥2 of poll / version / counts / test-request | React (done) + Tailwind (done via CDN) |
| 10% | Docs | Repro README, architecture diagram, teardown, talking points | Helper scripts; present early (human) |

---

## Checklist

### Required / platform (grader-facing)

- [x] Fraud + recommendations + forecasting FastAPI/EKS slices on `main`
- [x] Routing isolation evidence (Actions + History.md)
- [x] Real `deploy.yml` green on `main`
- [x] Gateway + ops dashboard on `main`
- [x] **Rewrite README** (scenario, mermaid, setup, deploy, verify, teardown) — merged via PR #6
- [x] Terraform provisions real AWS resources (SSM catalog + CloudWatch log group) + namespaces/RBAC + remote state
- [x] Architecture diagram + teardown in README (mermaid + teardown section)
- [x] `docs/presentation-notes.md`

### Bonuses done (say accurately)

- [x] Gateway single entry point
- [x] Weighted A/B split (`baseline` / `candidate`) + `X-Model-Variant` passthrough + per-variant counters — **one** SageMaker production variant behind both
- [x] `MODEL_VERSION` per team ConfigMap, surfaced on the dashboard
- [x] React ops UI + Tailwind: live poll, service + model version, request counts, test-predict (4 of 4 optional features)
- [x] Terraform remote state S3 + DynamoDB lock + K8s provider (namespaces, RBAC, `platform-metadata` ConfigMap)
- [x] `scripts/verify.sh` (now including ConfigMap↔SSM drift) + `scripts/demo-failure.sh` (quota + ready) with History.md evidence + restore
- [x] Actions: rollback, kubeconform lint, namespaced destroy, terraform plan/apply/destroy, deploy→verify chain, `git_ref` targeting
- [x] Actions "run tests": 18 pytest contract tests + dashboard `npm ci && npm run build` on every PR
- [x] Code-review cleanup: ConfigMap single owner, deploy→verify.sh, drop example seed

### Still open

- [ ] Presentation rehearsal / demo track (next work item)
- [ ] Optional: delete leftover merged remote feature branches

---

## Execution order (updated — presentation next)

Required slices and bonuses are all on `main`. What remains:

1. Run `Actions → Terraform → apply` so the SSM catalog and log group exist before the demo, then `scripts/verify.sh` to confirm no drift.
2. Presentation: rehearse the demo order in `docs/presentation-notes.md`, refresh it for counters / SSM / tests.
3. Re-check SageMaker endpoints are `InService` shortly before presenting — the class cost-guard has reaped them before.
4. Optional: delete leftover merged remote feature branches.
5. Keep `agent.md` ground truth honest after each merge (this file).

Remote state: S3 `aico-iv-steve-tfstate`, DynamoDB `aico-iv-steve-tflock`.

---

## Implementation notes (so the agent does not wander)

### FastAPI team services
- `/health` cheap (no AWS). `/ready` = config + client constructable.
- Keep invoke timeouts and HTTP 502 on SageMaker failure.
- Tag responses with `service`, `team`, `endpoint`, `version`.

### Gateway
- Namespace `platform`. Env URLs use `*.svc.cluster.local`.
- `WEIGHT_A` splits between `VARIANT_A_LABEL` / `VARIANT_B_LABEL`, forwarded as `X-Model-Variant`. One SageMaker variant behind both — presentation honesty required.
- Counters are in-process: `/stats` and the `requests` block inside `/health`. They reset on restart.
- Demo: port-forward `gateway-api` or use dashboard `/api`.

### Dashboard
- Poll gateway aggregate `/health` every few seconds.
- Show owner, service version, model version, request count, last check, green/red, plus total/failed/variant counter cards.
- Test-request: `POST /predict/{team}` and show `endpoint` + `variant` in JSON.
- In-cluster: nginx proxies `/api` → `gateway-api.platform.svc.cluster.local`.

### Terraform
- Owns: SSM parameters (`/ml-platform/dev/<team>/…`), platform CloudWatch log group, namespaces, platform read Role/RoleBinding, `platform-metadata` ConfigMap. Backend bucket/table come from the bootstrap script.
- Does not own: app ConfigMaps (YAML/Actions), Deployments/Services/Secrets/quotas, SageMaker endpoints, or the class cluster.
- CI path: PRs touching `terraform/` auto-plan; `Actions → Terraform` dispatches apply/destroy (destroy needs `destroy-my-infra`).
- Lifecycle:

```text
./scripts/bootstrap-tf-backend.sh   # once
cd terraform
terraform init
terraform plan
terraform apply
terraform destroy   # ONLY objects in this state
```

### Actions
- `EKS_CLUSTER: k8s-training-cluster`
- `platforms: linux/amd64`
- Verify: rollout status + `ENDPOINT_NAME` isolation + in-cluster curl jobs

### Docs graders will open
- README first (must match reality).
- History.md for failure narrative.
- `docs/architecture.md` / presentation notes as needed.

---

## Working conventions

1. Small PRs; keep `ci.yml` green.
2. Record failures and restores in History.md the same day.
3. Talking-point comments in code are fine; do not novelize every YAML line.
4. After a meaningful chunk, open or update a PR rather than stacking unbounded local commits.
5. If AWS IAM blocks a bonus, capture the error, mark “blocked / documented”, and move on.
6. Prefer `AWS_PROFILE=codeplatoon` in terminals that talk to AWS.
7. Update this ground-truth section whenever `main` moves — do not leave stale “PR unmerged / dashboard is a shell” claims.
