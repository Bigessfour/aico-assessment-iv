# Assessment IV - Getting Started

## Prerequisites

- AWS CLI configured (`aws sts get-caller-identity` returns your identity)
- `kubectl` installed
- Terraform 1.0+
- Docker installed and running
- Python 3.9+
- Node.js 18+ and npm
- GitHub CLI (`gh`)

## Setup

### 1. Create your repo

```bash
mkdir ~/assessment-4 && cd ~/assessment-4
git init
gh repo create assessment-4-ml-platform --public --source=. --remote=origin
```

### 2. Copy starter files

Copy the contents of the `resources/` directory into your repo.  This gives you a working FastAPI service, React dashboard shell, Terraform skeleton, and example K8s manifests.

```bash
cp -r /path/to/resources/* .
```

### 3. Run the starter script

```bash
chmod +x start.sh
./start.sh
```

This creates `.env` and `.env.secrets` files with defaults and checks port availability.

### 4. Connect to EKS

```bash
aws eks update-kubeconfig --region us-east-1 --name <class-cluster-name>
kubectl get nodes
```

### 5. Verify your SageMaker endpoints

```bash
aws sagemaker list-endpoints --status-filter InService
```

You need at least one running endpoint from Weeks 17-18.  If they've been deleted, redeploy from your earlier notebooks.

### 6. Set up GitHub Secrets

```bash
gh secret set AWS_ACCESS_KEY_ID
gh secret set AWS_SECRET_ACCESS_KEY
gh secret set GHCR_TOKEN
gh secret list
```

### 7. Test locally

```bash
cd services/example
pip install -r requirements.txt
ENDPOINT_NAME=<your-endpoint> uvicorn app:app --port 8000
# In another terminal:
curl http://localhost:8000/health
```

Once `/health` returns, you're good to start building.

## What's in `resources/`

```
resources/
├── services/example/       # FastAPI service with /health, /ready, /predict
│   ├── app.py
│   ├── requirements.txt
│   └── Dockerfile
├── dashboard/              # React + Vite shell
│   ├── src/
│   ├── package.json
│   ├── Dockerfile
│   └── nginx.conf
├── terraform/main.tf       # Provider + variable skeleton
├── k8s/example/            # Namespace, ConfigMap, Deployment, Service
├── .github/workflows/      # CI/CD workflow template
├── .gitignore
└── start.sh                # Env setup script
```

Rename `example` to your team names, duplicate per team, and swap in team-specific values.  The rest is on you.
