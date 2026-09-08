# Assessment IV — Internal ML Platform

Private working repo for Code Platoon Assessment IV.

**Upstream brief:** [codeplatoon-devops/aico-assessment-iv](https://github.com/codeplatoon-devops/aico-assessment-iv)  
**Full rubric / scenarios:** [docs/assessment-brief.md](docs/assessment-brief.md)  
**Bootstrap guide:** [getting_started.md](getting_started.md)
**Agent / stretch goals:** [agent.md](agent.md) — pursue all rubric bonuses

## Starter layout (from upstream `resources/`)

- `services/example/` — FastAPI with `/health`, `/ready`, `/predict`
- `dashboard/` — React + Vite shell
- `terraform/main.tf` — provider + variable skeleton
- `k8s/example/` — namespace, ConfigMap, Deployment, Service
- `.github/workflows/deploy.yml` — CI/CD template
- `start.sh` — creates `.env` / `.env.secrets`

Scenario (locked): **Scenario 1 — ML Platform** (Fraud / Recommendations / Forecasting).

## Quick start

```bash
./start.sh
# then follow getting_started.md
```
