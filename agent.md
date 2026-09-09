# Agent instructions — Assessment IV

Repo: [`Bigessfour/aico-assessment-iv`](https://github.com/Bigessfour/aico-assessment-iv) (private)  
Upstream brief: [docs/assessment-brief.md](docs/assessment-brief.md)  
Working log: [History.md](History.md)  
Machine: MacBook Pro (Apple Silicon). Cluster workers are **linux/amd64**.

## Mission

Ship a **demoable internal ML platform** that a grader can reproduce from the README.

Score the **required rubric first**. Bonuses are stretch after the required vertical is green. A late or incomplete required slice costs more than a missing bonus.

**Current risk is low for required slices.** Speaker notes added. Optional: prune merged remote branches.

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

## Honest rubric read

If you presented tomorrow as-is: live platform + README carry **K8s / SageMaker / Actions required / UI / Docs**. Terraform is strong once PR #5 merges. Missing: controlled-failure bonus, Actions stretch, speaker notes.

| Section | Weight | Estimate | Why |
|---------|--------|----------|-----|
| Kubernetes | 30% | Strong | Three ns, probes, quotas, ClusterIP. Missing controlled-failure **bonus** |
| SageMaker | 25% | Strong | Three wrappers, isolation in Actions, 502/timeout path, gateway + variant **label** |
| Actions | 15% | Good required, thin bonus | Real deploy green on `main`. No rollback / `workflow_run` / lint / namespaced destroy |
| UI | 10% | Met | React + Tailwind; polling + version + test-request |
| Terraform | 10% | Strong on PR #5 | Remote state + K8s provider; do not own `k8s-training-cluster` |
| Docs | 10% | Good | README + mermaid + teardown; speaker notes still open |

### Walkthrough gaps that will show

1. **Terraform** — claim only after PR #5 is on `main`; never own the class cluster.
2. **A/B is a label, not two models** — do not claim two SageMaker variants.
3. **Actions bonuses** cheapest remaining stretch: rollback, `ci`→`deploy` via `workflow_run`, dry-run lint, destroy only our namespaces.
4. **Controlled failure** still needed for K8s bonus: break `/ready` or trip quota, capture in History.md, restore.
5. **Speaker notes** — `docs/presentation-notes.md`.

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
- [x] Terraform lifecycle for namespaces/ConfigMaps/RBAC + remote state (merged PR #5)
- [x] Architecture diagram + teardown in README (mermaid + teardown section)
- [x] `docs/presentation-notes.md`

### Bonuses still open

- [x] `docs/presentation-notes.md` + leftover remote branch cleanup

### Bonuses done (say accurately)

- [x] Gateway single entry point
- [x] A/B **label** via `WEIGHT_A` (not dual SageMaker endpoints)
- [x] React ops UI + Tailwind styling + live poll + version + test-predict
- [x] Terraform remote state S3 + DynamoDB lock + K8s provider (ns/ConfigMaps/RBAC)
- [x] `scripts/verify.sh` + `scripts/demo-failure.sh` (quota + ready) with History.md evidence + restore
- [x] Actions: rollback, lint dry-run, namespaced destroy, deploy→verify chain, `git_ref` targeting
- [x] Code-review cleanup: ConfigMap single owner, deploy→verify.sh, drop example seed

---

## Execution order (updated — docs first)

The live platform slice is standing. Prioritize grader-facing clarity, then close Terraform on `main`, then cheap bonuses.

1. Optional: delete leftover merged remote feature branches.
2. Keep `agent.md` ground truth honest after each merge (this file).

Remote state: S3 `aico-iv-steve-tfstate`, DynamoDB `aico-iv-steve-tflock`. K8s provider manages ns/ConfigMaps/RBAC; Deployments stay YAML.

---

## Implementation notes (so the agent does not wander)

### FastAPI team services
- `/health` cheap (no AWS). `/ready` = config + client constructable.
- Keep invoke timeouts and HTTP 502 on SageMaker failure.
- Tag responses with `service`, `team`, `endpoint`, `version`.

### Gateway
- Namespace `platform`. Env URLs use `*.svc.cluster.local`.
- `WEIGHT_A` is a weighted label only — presentation honesty required.
- Demo: port-forward `gateway-api` or use dashboard `/api`.

### Dashboard
- Poll gateway aggregate `/health` every few seconds.
- Show owner, version, last check, green/red.
- Test-request: `POST /predict/{team}` and show `endpoint` + `variant` in JSON.
- In-cluster: nginx proxies `/api` → `gateway-api.platform.svc.cluster.local`.

### Terraform (PR #5)
- Owns: namespaces, platform read Role/RoleBinding, remote state backend resources (bootstrap script).
- Does not own: ConfigMaps (YAML/Actions), Deployments/Services/Secrets/quotas, or the class cluster.
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
