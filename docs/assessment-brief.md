# Assessment IV - Internal ML Platform Delivery with Kubernetes, SageMaker & CI/CD

---

## **Overview**

This assessment evaluates your ability to deliver internal platform tooling that orchestrates multiple machine learning endpoints using Kubernetes.  You've spent the last four weeks building SageMaker models, wrapping them in FastAPI services, containerizing those services and deploying them to Kubernetes.  Now you'll be combining all of the above with everything you've learned in the previous modules to put together a single cohesive system, demonstrating all you've learned about AWS, Terraform, Github Actions, Sagemaker and Kubernetes.

## **Context**
You are building internal tooling that a platform engineering team would actually deliver to support multiple business units running different ML workloads.  The system should feel like a real internal surface — something a team lead could open in a browser and immediately understand which models are running, which teams own them, and whether anything needs attention.

To do this, you'll need to bring together Kubernetes orchestration on EKS, SageMaker endpoint management, Terraform infrastructure provisioning, GitHub Actions CI/CD, and a lightweight React dashboard that ties the whole thing together with operational visibility.

---

## **Objectives**

The core goal is to demonstrate end-to-end platform delivery: from infrastructure provisioning to automated deployment to live, multi-team ML orchestration with a user-facing component.  To do this, you must meet these objectives:

1. Provision repeatable infrastructure with Terraform
2. Orchestrate atleast two SageMaker endpoints using Kubernetes with proper configuration, security, and health management
3. Automate the full release path using GitHub Actions 
4. Expose a lightweight internal UI that gives operational visibility into the platform's state 

We can outline these objectives to give you an idea of what will be scored.

## **Exam Outline**

**1. Terraform Infrastructure as Code (10%)**

1. Provision cloud resources through Terraform
2. Use variables, outputs, and proper state management — no hardcoded credentials
3. Document the lifecycle: `terraform init`, `plan`, `apply`, `destroy`
4. Bonus: Remote state with S3/DynamoDB locking
5. Bonus: Terraform-managed Kubernetes resources (namespaces, RBAC, ConfigMaps) via the Kubernetes provider

**2. Kubernetes Orchestration Quality (30%)**

1. Deploy to EKS with namespace separation per team
2. ConfigMaps for non-sensitive config (endpoint names, regions, log levels); Secrets for credentials (AWS keys, registry tokens)
3. Readiness, liveness, and startup probes with appropriate thresholds
4. ResourceQuota and LimitRange per namespace
5. Bonus: controlled failure scenario (probe restart, quota rejection, readiness-gated traffic)

**3. Multi-Endpoint SageMaker Integration (25%)**

1. Three SageMaker endpoints through the platform with explicit routing (request to the fraud endpoint returns fraud predictions, not recommendations)
2. Each wrapped in a FastAPI service with `/health`, `/ready`, `/predict`
3. Handles at least one failure path (timeout, fallback, error propagation)
5. Bonus: an additional gateway service that acts as a single entry point, proxying requests to each team's individual service so consumers don't need to know three separate URLs
6. Bonus: model versioning and A/B routing

**4. GitHub Actions CI/CD Quality (15%)**

1. Atleast one workflow for triggering build, registry push, and EKS deploy
2. Usage of Github Actions secrets and variables
3. At least one verification step (`kubectl get pods`, health check curl, rollout status)
4. Bonus: Rollback steps, branch-based targeting
5. Bonus: Multiple workflows chainged together
6. Bonus: additional workflows (destroy infra, run tests, lint manifests)

**5. Internal Operations UI — React Dashboard (10%)**

1. A simple web dashboard that shows which services are deployed, their health status, and which team owns each (Designed to serve as internal ops tool, not a consumer app)
2. Should demonstrate atleast two of the following: live polling, version display, request counts, or a test-request interface
3. Bonus: UI utilizes framework like Fast API, Flask or React
4. Bonus: clean styling (Tailwind, MUI, Streamlit, or similar)

**6. Documentation & Presentation Quality (10%)**

1. Setup and config steps clear enough for someone else to reproduce
2. At least one architecture diagram (cluster, endpoints, CI/CD, dashboard)
3. Present and answer questions about design decisions
4. Clean GitHub repo structure with documentation
5. Bonus: present early; points deducted for late
6. Bonus: helper scripts (secrets config, env scaffolding, local dev bootstrap)

---

## **Deliverables**

Everything should be repeatable by a colleague following your repo.

1. Terraform config (or docs for shared/imported resources)
2. Kubernetes manifests in `k8s/` — deployments, services, ConfigMaps, Secrets, quotas
3. GitHub Actions workflow(s) in `.github/workflows/`
4. App source — FastAPI services, React dashboard, Dockerfiles
5. Docs — project overview, architecture diagram, setup/deploy/verify steps, teardown steps

---

## **Business Scenarios**

You should provide a business scenario as context during your presentation and in your repo's README.md.

### Scenario 1 — ML Platform (Default)

You are on a platform engineering team supporting three internal business units:

- **Fraud Detection Team** — runs an XGBoost model that classifies transactions as fraudulent or legitimate
- **Recommendations Team** — runs a Factorization Machines model that generates product or content recommendations
- **Forecasting Team** — runs a time-series model (DeepAR or similar) that produces demand or usage forecasts

Each team owns their own SageMaker endpoint and FastAPI service, but all deployment operations, routing, and operational visibility are managed through a shared internal platform that your team builds and maintains.


### Scenario 2 — Data Products Contracting Firm

You are a developer on a devops team at a contracting firm that builds ML-powered data pipelines for external clients.  Each client brings a different dataset and use case, and your team is responsible for training, deploying, and maintaining the model endpoints they integrate into their own services.  You currently have three active client contracts:

- **Client A (Financial Services)** — you built an XGBoost model that scores consumer credit risk from their history data, exposed as an endpoint they call from their loan approval workflow
- **Client B (Outdoor Recreation)** — you built a clustering model that ranks locations from public datasets (national parks, visitation rules, capacity) into accessibility and feasibility scores for their trip-planning app
- **Client C (Legal Tech)** — you built an NLP model that extracts structured fields (parties, terms, dates) from raw contracts for their document processing pipeline

Each client's model runs on its own SageMaker endpoint behind a FastAPI service your team built.  Your platform handles deployment, routing, and monitoring across all three so your team can manage them from one place.

Your implementation should demonstrate how this can be done safely, repeatably, and with clear operational visibility.  Think about what your team lead would want to see before a client check-in: Are all three client endpoints healthy?  When was each last deployed?  Is Client A's endpoint getting hammered because they just launched a new product?


### Scenario 3 — Small AI Lab

You are on a platform engineering team at a small AI lab where developer teams experiment with and optimize open-source LLMs.  You support three internal teams:

- **Quantization Team** — runs compressed LLM variants (GPTQ, AWQ) and compares inference quality against full-precision baselines
- **Fine-Tuning Team** — runs LoRA-adapted models on domain-specific data and exposes them for A/B comparison against base models
- **Eval Team** — runs a scoring model that takes prompt-response pairs and returns quality metrics (coherence, factuality, toxicity) to rank model variants

Each team owns their own SageMaker endpoint and FastAPI service, but all deployment operations, routing, and operational visibility are managed through a shared internal platform that your team builds and maintains.

### Scenario Goal

For any scenario, your implementation should demonstrate how this can be done safely, repeatably, and with clear team-facing visibility.  Think about what a lab lead would want to see on a Monday morning: Are all three endpoints live?  Which model versions are deployed?  Is the quantization team burning extra compute from testing a 70B variant?

---

## **Timeline**

One week.  Points docked for every additional class day past the deadline.

**Pro tips:**

- Reuse what you've built — Week 17-18 FastAPI services, Week 19 K8s manifests, CI/CD workflows are all fair game
- Get one team's full stack end-to-end first, then replicate
- Use Terraform and Actions outputs to log endpoints, connection strings, and deploy status
- Prebuilt Actions (`docker/build-push-action`, `aws-actions/configure-aws-credentials`) save boilerplate

**Pacing:**

- **Day 1-2**: Infrastructure + one team service deployed to EKS with probes
- **Day 3**: Second and third services, namespaces, resource controls
- **Day 4**: CI/CD pipeline + React dashboard
- **Day 5**: Docs, architecture diagram, presentation prep

---

## **Hints**

- Start with what you're most comfortable with — add complexity later
- The class EKS cluster, shared VPC, and existing IAM roles can be referenced or imported
- Start with your strongest endpoint and get the full vertical slice working before expanding
- ConfigMaps and Secrets from Day 3 are directly reusable — same pattern, different values per namespace
- The dashboard doesn't need to be complex — a page that fetches `/health` and shows green/red is already valuable
- Ask questions and help each other out.  Collaboration and communication matter too
- A working demo may be available for reference in the AWS console

---

## **Troubleshooting**

### Terraform

- `terraform plan` before `apply`
- Check creds: `aws sts get-caller-identity`
- Remote state: verify the S3 bucket and DynamoDB lock table exist
- `terraform destroy` to clean up if starting fresh
- Importing: `terraform import` then verify state matches reality

### Kubernetes / EKS

- Check context: `kubectl config current-context`
- `Pending` pods: check node capacity and quotas (`kubectl describe node`, `kubectl describe resourcequota -n <namespace>`)
- `ImagePullBackOff`: verify image pull secret and credentials
- Probe failures: `kubectl describe pod <pod> -n <namespace>` — check Events
- `<pending>` EXTERNAL-IP: wait 1-2 min for the LB

### SageMaker

- Verify InService: `aws sagemaker describe-endpoint --endpoint-name <name>`
- IAM: FastAPI role needs `sagemaker:InvokeEndpoint`
- Test from pod: `kubectl exec -it <pod> -n <namespace> -- curl localhost:8000/health`
- Timeouts: check CloudWatch logs for invocation errors

### GitHub Actions

- Verify secrets: `gh secret list`
- Syntax errors show inline in the Actions tab
- `kubectl apply` fails: check EKS cluster name and region in secrets
- Image push fails: verify PAT has `write:packages` scope

### React Dashboard

- Verify frontend API config matches backend service URLs
- CORS blocking requests: check backend CORS config
- Health checks failing: verify backend services are exposed
- Test with `curl` before debugging the frontend

---

[Getting Started](./getting_started.md)
