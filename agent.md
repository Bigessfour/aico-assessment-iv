# Agent instructions — Assessment IV

## Primary goal

**Complete all stretch / bonus tasks** from the Assessment IV rubric, not only the required minimums. Prefer a working demo of each bonus over partial stubs.

Upstream brief: [docs/assessment-brief.md](docs/assessment-brief.md)  
Working log: [History.md](History.md)

Scenario (locked): **Scenario 1 — ML Platform** (Fraud / Recommendations / Forecasting).

AWS: profile `codeplatoon`, account `388691194728`, region `us-east-1`, cluster `k8s-training-cluster`.

---

## Bonus checklist (must pursue all)

### 1. Terraform (10% section)

| Bonus | Status | Notes |
|-------|--------|-------|
| Remote state with S3 + DynamoDB locking | pending | No credentials in git |
| Terraform-managed K8s resources via Kubernetes provider (namespaces, RBAC, ConfigMaps) | pending | Prefer IaC for what we currently apply with kubectl |

### 2. Kubernetes orchestration (30% section)

| Bonus | Status | Notes |
|-------|--------|-------|
| Controlled failure scenario (probe restart, quota rejection, or readiness-gated traffic) | pending | Document + reproduce in History.md / demo script |

### 3. Multi-endpoint SageMaker (25% section)

| Bonus | Status | Notes |
|-------|--------|-------|
| Gateway service — single entry point proxying to each team service | pending | Consumers should not need three URLs |
| Model versioning and A/B routing | pending | e.g. weighted routes or version labels between model variants |

### 4. GitHub Actions CI/CD (15% section)

| Bonus | Status | Notes |
|-------|--------|-------|
| Rollback steps | pending | |
| Branch-based targeting | pending | |
| Multiple workflows chained together | pending | |
| Additional workflows (destroy infra, run tests, lint manifests) | partial | `ci.yml` validates; still need deploy/destroy/lint depth |

### 5. Internal ops UI (10% section)

| Bonus | Status | Notes |
|-------|--------|-------|
| Framework (React already in starter — keep/enhance) | pending | Starter dashboard exists; make it real |
| Clean styling (Tailwind, MUI, or similar) | pending | |

Required UI features (also finish): live polling, version display, request counts, and/or test-request interface — hit **at least two**; prefer more for stretch quality.

### 6. Documentation & presentation (10% section)

| Bonus | Status | Notes |
|-------|--------|-------|
| Present early | pending | Operator / student |
| Helper scripts (secrets config, env scaffolding, local bootstrap) | partial | `start.sh` exists; add secrets/apply helpers |

---

## Required baseline (track, but bonuses are the stretch target)

- [x] Three team FastAPI services + EKS namespaces with probes, ConfigMaps, Secrets, quotas
- [x] Routing isolation (`aico-iv-fraud` / `aico-iv-recs` / `aico-iv-forecast`)
- [ ] Terraform lifecycle documented (`init` / `plan` / `apply` / `destroy`)
- [ ] Real `deploy.yml` (build → registry → EKS → verify)
- [ ] Ops dashboard with multi-team visibility
- [ ] Architecture diagram + teardown docs

---

## Working conventions for the agent

1. Prefer **linux/amd64** image builds (`docker build --platform linux/amd64`).
2. Prefer `AWS_PROFILE=codeplatoon` (Keychain) over short-lived `aws login` for deploy loops.
3. Never commit real Secrets, `.env`, or `.env.secrets`.
4. Record failures and fixes in `History.md` for the submission PR / presentation.
5. Ship bonuses as **demoable** artifacts (scripts, workflows, UI toggles) with short talking-point comments in code.
6. After meaningful chunks, open a PR; keep CI green.

## Suggested execution order (bonus-aware)

1. Terraform + remote state + k8s provider (covers two Terraform bonuses)
2. Gateway service + A/B routing (SageMaker bonuses)
3. Full deploy.yml + rollback / branch targeting / destroy+lint workflows (Actions bonuses)
4. Controlled failure demo script (K8s bonus)
5. React dashboard + styling (UI bonuses)
6. Helper scripts + docs/diagram; present early (docs bonuses)
