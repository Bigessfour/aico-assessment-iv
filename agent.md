# Agent instructions — Assessment IV

Repo: `Bigessfour/aico-assessment-iv` (private)  
Upstream brief: [docs/assessment-brief.md](docs/assessment-brief.md)  
Working log: [History.md](History.md)  
Machine: MacBook Pro (Apple Silicon). Cluster workers are **linux/amd64**.

## Mission

Ship a **demoable internal ML platform** that a grader can reproduce from the README.

Score the **required rubric first**. Bonuses are stretch after the required vertical is green. A late or incomplete required slice costs more than a missing bonus.

Scenario (locked): **Scenario 1 — ML Platform**  
Teams: Fraud (`aico-iv-fraud`) · Recommendations (`aico-iv-recs`) · Forecasting (`aico-iv-forecast`)

AWS: profile `codeplatoon`, account `388691194728`, region `us-east-1`, cluster `k8s-training-cluster` (class-shared EKS).

---

## Ground truth (do not invent a greener state)

### `main` (as of 2026-09-08, post PR #2 merge)

- Three team slices on disk: `fraud` / `recommendations` / `forecasting` FastAPI + `k8s/<team>/` (ns, ConfigMap, Secret example, probes, quota/LimitRange, ClusterIP).
- Live cluster (when last verified): all three namespaces Ready with isolated `ENDPOINT_NAME` values.
- `terraform/main.tf` is still the upstream **skeleton** (provider + variables + two outputs). No remote state, no K8s provider, no real resources.
- `.github/workflows/deploy.yml`: replaced on branch `feature/real-deploy-workflow` — real matrix build → GHCR → apply → verify. Until that PR merges, `main` may still have the old template.
- `.github/workflows/ci.yml` syntax-checks all three services + manifest trees.
- `dashboard/` is the upstream React + Vite **shell** (hardcoded Example Service, one-shot fetch, no Tailwind/MUI).
- README is still a starter blurb. No architecture diagram, no teardown runbook.

### Naming

- Namespaces in manifests are `fraud` / `recommendations` / `forecasting` (not `aico-iv-*`).
- `aico-iv-*` are **SageMaker endpoint names** only. Do not rename namespaces unless updating every apply/verify command.

Mark a checklist item done only after it exists on the branch you are working and is recorded in `History.md`.

---

## Hard constraints (shared class account)

1. **Do not** create, modify, or `terraform destroy` the class EKS cluster, VPC, node groups, or other students' namespaces.
2. Terraform may **reference / data-source** `k8s-training-cluster`. It must not try to own it.
3. Never commit `.env`, `.env.secrets`, live Secret YAML, AWS keys, or `GHCR_TOKEN`.
4. Prefer `AWS_PROFILE=codeplatoon` (Keychain) over `aws login` for deploy loops — login grants expire mid-session (see History.md #5).
5. Images: `docker build --platform linux/amd64` then push GHCR. Arm64 images cause `ImagePullBackOff` (History.md #4).
6. Do not add curl to every image just for demos; verify with `kubectl port-forward` from the laptop (History.md #6).
7. Keep Services **ClusterIP** unless a LoadBalancer is required for the dashboard/gateway demo. Class clusters fill up with leftover LBs.
8. Quotas are tight. Stay at **1 replica** unless a failure demo needs a second pod, then scale back.
9. After a controlled-failure demo, **restore** the healthy state before leaving the session.
10. Do not rewrite working fraud/recs/forecast apps into a monorepo framework. Duplicate-and-specialize is the class pattern.

---

## Rubric priority (weight → work)

| Weight | Section | Required bar | Bonus (only after required) |
|--------|---------|--------------|-----------------------------|
| 30% | K8s | 3 namespaces, ConfigMaps, Secrets, 3 probes, ResourceQuota + LimitRange | One **reversible** controlled failure with script + History.md evidence |
| 25% | SageMaker | 3 FastAPI wrappers, isolated routing, `/health` `/ready` `/predict`, one failure path (timeout/502 already in fraud app) | Gateway proxy + simple A/B or version label |
| 15% | Actions | Real `deploy.yml`: build → GHCR → kubeconfig → apply → verify | Rollback job, branch targeting, chained workflows, destroy/lint/test workflows |
| 10% | Terraform | Variables, outputs, documented `init/plan/apply/destroy` for **our** resources | S3+DynamoDB backend if we can create them; K8s provider for ns/RBAC/ConfigMaps |
| 10% | UI | Multi-team health + owner; **at least two of**: live polling, version, request counts, test-request | Keep React; add Tailwind or MUI |
| 10% | Docs | Repro README, architecture diagram, teardown, presentable talking points | Helper scripts; present early (human — prepare slides/notes now) |

---

## Required baseline checklist

- [x] Fraud FastAPI + EKS slice with probes, ConfigMap, Secrets, quota (on `main`)
- [x] Recommendations + forecasting slices (PR #2 merged to `main`)
- [x] Routing isolation evidence: each pod `ENDPOINT_NAME` matches its team (recorded in History.md)
- [ ] Terraform lifecycle documented for whatever we actually manage (even if that is only tags/S3 state/K8s objects — not the cluster)
- [x] Real `deploy.yml` (merged; Actions green on main)
- [x] Ops dashboard with three teams + live poll + version + test-predict (branch `feature/gateway-and-dashboard`)
- [ ] Architecture diagram + teardown docs in README or `docs/`

---

## Bonus checklist (pursue after required is demoable)

### 1. Terraform

| Bonus | Status | Done when |
|-------|--------|-----------|
| Remote state S3 + DynamoDB lock | pending | Unique bucket/table names (`aico-iv-steve-*` or similar); backend block in code; no creds in git; `History.md` records init. If IAM denies bucket create, document the denial and keep local state — do not block the rest of the project. |
| K8s provider manages ns / RBAC / ConfigMaps | pending | Terraform apply creates the three namespaces + a platform Role/RoleBinding + ConfigMaps. Deployments may stay as YAML to avoid a big rewrite. Do not fight kubectl vs Terraform for the same object. |

### 2. Kubernetes

| Bonus | Status | Done when |
|-------|--------|-----------|
| Controlled failure | pending | `scripts/demo-failure.sh` that (pick one, implement fully): readiness-gated traffic (break `/ready`, show Service endpoints empty, restore) **or** quota rejection (apply an oversized pod, show `Forbidden`, delete). Capture `kubectl` output in History.md. Always restore. |

### 3. SageMaker / platform routing

| Bonus | Status | Done when |
|-------|--------|-----------|
| Gateway | done (this PR) | `services/gateway` FastAPI: `POST /predict/{team}` and aggregate `GET /health`. In-cluster DNS. Demo: `kubectl -n platform port-forward svc/gateway-api 18080:80`. |
| Model versioning / A/B | done (this PR) | ConfigMap `WEIGHT_A` on gateway; responses labeled `variant` A\|B. No extra SageMaker endpoints. |

### 4. GitHub Actions

| Bonus | Status | Done when |
|-------|--------|-----------|
| Rollback | pending | `workflow_dispatch` input `rollback` or `image_tag`; `kubectl set image` / rollout undo + verify. |
| Branch targeting | pending | `main` → deploy namespaces; `feature/*` → plan/CI only, or a `preview` namespace if quota allows. |
| Chained workflows | pending | `ci.yml` success gates `deploy.yml` via `workflow_run` **or** a reusable workflow. Avoid double-deploy on every push. |
| Extra workflows | partial | Keep `ci.yml`. Add `lint-manifests.yml` (`kubeconform` or `kubectl --dry-run=client`). Optional `destroy-workloads.yml` that deletes **only** our three namespaces — never the cluster. |

### 5. Ops UI

| Bonus | Status | Done when |
|-------|--------|-----------|
| React framework | **satisfied by starter** | Do not replace with Flask/Streamlit. Enhance in place. |
| Clean styling | done (this PR) | Tailwind CDN + IBM Plex; slate/teal ops theme. |
| Features | done (this PR) | Live poll (~7s) + version field + test-request form against gateway. |

### 6. Docs / presentation

| Bonus | Status | Done when |
|-------|--------|-----------|
| Present early | human | Operator prepares 5-minute talk from README + History.md + diagram. Agent prepares speaker notes in `docs/presentation-notes.md`. |
| Helper scripts | partial | `start.sh` exists. Add `scripts/apply-secrets.sh` (reads local env, applies Secret YAML from example), `scripts/bootstrap-kube.sh`, `scripts/verify.sh` (port-forward + curl three `/health` + `/ready`). |

---

## Execution order (required-first)

0. Land PR #2. Confirm three namespaces Ready on the cluster. Update History.md. Keep CI green.
1. Real `deploy.yml` + verification steps (unlocks CI/CD required + most Actions bonuses).
2. Gateway + dashboard talking to gateway (SageMaker bonus + UI required).
3. Terraform: document lifecycle; add remote state **if permitted**; optionally move namespaces/ConfigMaps to the K8s provider.
4. `scripts/demo-failure.sh` + History.md evidence.
5. A/B weights on gateway; dashboard control.
6. Rollback / branch targeting / lint / namespaced destroy workflows.
7. README + architecture diagram + teardown + presentation notes + helper scripts.

Do not start Terraform remote-state yak-shaving while `deploy.yml` is still a template or the dashboard still lists Example Service.

---

## Implementation notes (so the agent does not wander)

### FastAPI services
- Keep `/health` cheap (no AWS). Keep `/ready` as “config + client constructable”.
- Keep invoke timeouts and HTTP 502 on SageMaker failure (already satisfies the required failure path).
- Tag responses with `service`, `team`, `endpoint`, `version` so the dashboard and routing demo are obvious.

### Gateway
- ClusterIP in namespace `platform` (create it) or `fraud` if you want fewer namespaces.
- Env: `FRAUD_URL=http://fraud-api.fraud.svc.cluster.local`, same for recs/forecast.
- CORS enabled for the dashboard origin.

### Dashboard
- Poll `/health` (or gateway aggregate) every few seconds.
- Show team owner, version, last check time, green/red.
- Test-request panel: pick team, POST sample JSON, render prediction + endpoint name (proves isolation).

### Terraform
- Files: `terraform/backend.tf` (commented if unused), `variables.tf`, `outputs.tf`, `eks_data.tf` (`data.aws_eks_cluster`), optional `k8s.tf`.
- Document in README:

```text
cd terraform
terraform init
terraform plan
terraform apply
terraform destroy   # destroys ONLY resources in this state, never the class cluster
```

### Actions
- `EKS_CLUSTER: k8s-training-cluster`
- `docker/build-push-action` with `platforms: linux/amd64`
- After apply: `kubectl rollout status` per deployment and a `kubectl get pods -n fraud,recommendations,forecasting`

### Docs graders will open
- README: scenario, architecture (mermaid is fine), setup, deploy, verify curls, teardown.
- History.md: every real failure + fix (already a good start).
- `docs/architecture.md` if README gets long.

---

## Working conventions

1. Small PRs; keep `ci.yml` green.
2. Record failures and restores in History.md the same day.
3. Talking-point comments in code are fine; do not novelize every YAML line.
4. After a meaningful chunk, open or update a PR rather than stacking unbounded local commits.
5. If AWS IAM blocks a bonus (S3 backend, extra endpoints), capture the error, mark bonus “blocked / documented”, and move on.
6. Cursor on this Mac: follow https://cursor.com/docs for IDE operations. Use the `codeplatoon` profile in integrated terminals that talk to AWS.
