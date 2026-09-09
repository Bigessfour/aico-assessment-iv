# History — Assessment IV build log (for submission / PR / presentation)

Record of issues hit while implementing the fraud vertical slice and how
we resolved them. Useful for the write-up and for answering “what went wrong?”

Repo: Bigessfour/aico-assessment-iv
Upstream brief: codeplatoon-devops/aico-assessment-iv
Cluster: k8s-training-cluster (us-east-1)
Account: 388691194728 (codeplatoon)

---

## 2026-09-08 — Bootstrap

### Done
- Seeded private repo from upstream `resources/`
- Ran `./start.sh` (`.env` / `.env.secrets`)
- Confirmed EKS nodes Ready and three SageMaker endpoints InService:
  - `aico-iv-fraud`
  - `aico-iv-recs`
  - `aico-iv-forecast`
- Local FastAPI smoke against `aico-iv-fraud`
- Set GitHub Actions secrets from macOS Keychain (values not committed):
  - `AWS_ACCESS_KEY_ID`
  - `AWS_SECRET_ACCESS_KEY`
  - `GHCR_TOKEN`

---

## Issues and resolutions

### 1. Local `/ready` failed: missing `botocore[crt]`
**Symptom:** `/health` OK; `/ready` returned 503 with
`Using the login credential provider requires ... pip install "botocore[crt]"`.

**Cause:** `aws login` uses a credential provider that needs the CRT extra.
`/ready` constructs a boto3 client, so it surfaced the missing dependency.
`/health` does not call AWS, so it stayed green.

**Fix:** Activate `.venv`, then `pip install "botocore[crt]"` (installs `awscrt`).
Restart uvicorn.

**Lesson:** Liveness ≠ readiness. Credential/client failures belong on `/ready`.

---

### 2. `pip install` hit `externally-managed-environment`
**Symptom:** Homebrew system Python refused `pip install`.

**Cause:** Ran pip outside the project virtualenv (no `(.venv)` on the prompt).

**Fix:** `source .venv/bin/activate` before pip. Path is `.venv/bin/activate`
(slash), not `.venv/bin.activate`.

---

### 3. Port 8000 already in use
**Symptom:** `ERROR: [Errno 48] address already in use` when starting uvicorn.

**Cause:** An earlier uvicorn process was still bound to 8000.

**Fix:** Ctrl+C the old server (or `lsof -i :8000` + `kill <pid>`), then restart.

---

### 4. ImagePullBackOff: `no match for platform in manifest`
**Symptom:** Pod stuck pulling `ghcr.io/bigessfour/fraud-detection:latest`.

**Cause:** Image built on Apple Silicon (arm64). EKS worker nodes are linux/amd64.

**Fix:**
```bash
docker build --platform linux/amd64 -t ghcr.io/bigessfour/fraud-detection:latest \
  services/fraud-detection
docker push ghcr.io/bigessfour/fraud-detection:latest
kubectl -n fraud delete pod -l app=fraud-api
```

**Lesson:** Always cross-build for the cluster architecture from an M-series Mac.

---

### 5. kubectl failed after image push: expired `aws login` grant
**Symptom:**
`CreateOAuth2Token ... authorization grant is invalid, expired, revoked...`
then `Unable to connect to the server`.

**Cause:** Default profile used `aws login` session tokens that expired mid-work.

**Fix:** Prefer the Keychain-backed static profile for long sessions:
```bash
export AWS_PROFILE=codeplatoon
aws eks update-kubeconfig --region us-east-1 --name k8s-training-cluster
```

**Lesson:** `aws login` is fine for interactive work; Keychain/`codeplatoon`
is more reliable for deploy loops.

---

### 6. `kubectl exec ... curl` failed inside the container
**Symptom:** `exec: "curl": executable file not found in $PATH`.

**Cause:** `python:3.9-slim` does not include curl.

**Fix:** Verify with port-forward from the laptop instead:
```bash
kubectl -n fraud port-forward svc/fraud-api 18000:80
curl http://127.0.0.1:18000/health
curl http://127.0.0.1:18000/ready
```

---

## Fraud vertical slice — end state (2026-09-08)

| Piece                                                  | Status                                                    |
| ------------------------------------------------------ | --------------------------------------------------------- |
| Namespace `fraud`                                      | Created                                                   |
| ConfigMap `fraud-config` → `aico-iv-fraud`             | Applied                                                   |
| Secret `fraud-aws-creds` + `ghcr-secret`               | Applied (not in git)                                      |
| Deployment `fraud-api` with startup/readiness/liveness | 1/1 Ready                                                 |
| Service `fraud-api` ClusterIP                          | Serving                                                   |
| ResourceQuota + LimitRange                             | Applied                                                   |
| Image                                                  | `ghcr.io/bigessfour/fraud-detection:latest` (linux/amd64) |
| Health checks                                          | `/health` + `/ready` OK via port-forward                  |

---

## Recommendations + Forecasting teams — end state (2026-09-08)

Starter-guide approach: duplicate the proven fraud vertical slice per team
with team-specific namespaces, ConfigMaps, and SageMaker endpoint names.

| Team | Namespace | Image | Endpoint | Pod |
|------|-----------|-------|----------|-----|
| Fraud | `fraud` | `ghcr.io/bigessfour/fraud-detection:latest` | `aico-iv-fraud` | 1/1 Ready |
| Recommendations | `recommendations` | `ghcr.io/bigessfour/recommendations:latest` | `aico-iv-recs` | 1/1 Ready |
| Forecasting | `forecasting` | `ghcr.io/bigessfour/forecasting:latest` | `aico-iv-forecast` | 1/1 Ready |

**Routing isolation verified** (pod env `ENDPOINT_NAME`):

- fraud → `aico-iv-fraud`
- recommendations → `aico-iv-recs`
- forecasting → `aico-iv-forecast`

Both new services used `--platform linux/amd64` from the start (lesson from fraud ImagePullBackOff).

---

## PR #2 merged (2026-09-08)

Merged `feature/teams-recommendations-forecasting` to `main`. Revised `agent.md` to required-first order with honest baseline and shared-cluster guards.

## Real `deploy.yml` (in progress)

Replacing the upstream template with:

- Matrix build/push for `fraud-detection`, `recommendations`, `forecasting` (`linux/amd64`)
- `EKS_CLUSTER: k8s-training-cluster` (no placeholder)
- Create AWS + GHCR secrets from Actions secrets (never apply `secret.example.yml`)
- Apply ns/quota/configmap/deployment/service per team
- Pin image to `${{ github.sha }}`
- Verify rollout + `ENDPOINT_NAME` isolation + in-cluster `/health` + `/ready`

Does **not** create or destroy the class EKS cluster.

## Gateway + ops dashboard (2026-09-08)

Added platform namespace with:

- `services/gateway` — aggregate `/health`, `POST /predict/{team}`, A/B `WEIGHT_A` labeling
- React ops dashboard (Tailwind) — live poll, version, test-predict; nginx `/api` → gateway
- Images: `ghcr.io/bigessfour/gateway:latest`, `ghcr.io/bigessfour/ops-dashboard:latest` (linux/amd64)
- Deploy path extended in `deploy.yml` for gateway + dashboard

Verified aggregate health shows all three teams healthy with correct SageMaker endpoint names.

### Demo

```bash
kubectl -n platform port-forward svc/ops-dashboard 3000:80
# open http://localhost:3000
# or gateway only:
kubectl -n platform port-forward svc/gateway-api 18080:80
curl http://127.0.0.1:18080/health
```

## README rewrite (2026-09-08)

Replaced the starter README with grader-facing docs: Scenario 1, mermaid architecture, real repo layout, deploy/verify/teardown, dashboard demo, Terraform caveats, presentation honesty on A/B labels.

## Terraform platform stack (2026-09-08)

- Remote state: S3 `aico-iv-steve-tfstate` + DynamoDB `aico-iv-steve-tflock` (bootstrap script)
- Kubernetes provider manages namespaces, team/gateway ConfigMaps, platform read Role/RoleBinding
- Class cluster is **data-source only** (`k8s-training-cluster`)
- First apply: imported existing namespaces/ConfigMaps, then `Apply complete! Resources: 0 added, 4 changed, 0 destroyed`
- Docs: `terraform/README.md` with init/plan/apply/destroy + import notes

Deprecation note: Terraform warns `dynamodb_table` → prefer `use_lockfile` later; DynamoDB lock still works for the rubric.

## Still to do (platform)

- Controlled failure demo script + verify helper
- Actions bonuses (rollback, branch targeting, lint/destroy-workloads)
- Presentation notes + leftover branch cleanup
