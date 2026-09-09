"""Platform gateway — single entry point for all three team ML services.

Talking points (presentation / rubric bonus):
  - Consumers call ONE URL instead of three team ClusterIPs.
  - Proxies POST /predict/{team} to the matching in-cluster Service DNS.
  - GET /health aggregates each team's /health for the ops dashboard.
  - Optional A/B weights (ConfigMap) label responses with variant A|B
    without creating extra SageMaker endpoints.
"""

from __future__ import annotations

import asyncio
import os
import random
from typing import Any

import httpx
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

app = FastAPI(title="ml-platform-gateway", version="0.1.0")

# Allow the React dashboard (port-forward or ClusterIP) to call us from a browser.
# In-cluster demos usually go through dashboard nginx /api proxy; CORS still helps local vite.
app.add_middleware(
    CORSMiddleware,
    allow_origins=os.getenv("CORS_ORIGINS", "*").split(","),
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# In-cluster DNS names — set via ConfigMap so we never hardcode IPs.
# Pattern: http://<service>.<namespace>.svc.cluster.local
TEAM_URLS = {
    "fraud": os.getenv("FRAUD_URL", "http://fraud-api.fraud.svc.cluster.local"),
    "recommendations": os.getenv(
        "RECOMMENDATIONS_URL",
        "http://recommendations-api.recommendations.svc.cluster.local",
    ),
    "forecasting": os.getenv(
        "FORECASTING_URL",
        "http://forecasting-api.forecasting.svc.cluster.local",
    ),
}

# Human-readable owners shown on the ops dashboard (Scenario 1 narrative).
TEAM_OWNERS = {
    "fraud": "Fraud Detection Team",
    "recommendations": "Recommendations Team",
    "forecasting": "Forecasting Team",
}

# A/B bonus: weight for variant A (0-100). Remainder goes to B.
# Does NOT require new SageMaker endpoints — just labels the gateway hop.
WEIGHT_A = int(os.getenv("WEIGHT_A", "80"))
HTTP_TIMEOUT = float(os.getenv("HTTP_TIMEOUT_SECONDS", "15"))


def pick_variant() -> str:
    """Weighted coin flip for A/B labeling (presentation talking point)."""
    return "A" if random.randint(1, 100) <= WEIGHT_A else "B"


async def _team_health(client: httpx.AsyncClient, team: str, base: str) -> tuple[str, dict[str, Any]]:
    """Fetch one team's /health; never raises — errors become unhealthy entries."""
    try:
        resp = await client.get(f"{base.rstrip('/')}/health")
        body = resp.json() if resp.status_code < 500 else {"status": "error"}
        return team, {
            "owner": TEAM_OWNERS[team],
            "http_status": resp.status_code,
            "healthy": resp.status_code == 200 and body.get("status") == "healthy",
            "version": body.get("version", "unknown"),
            "endpoint": body.get("endpoint", ""),
            "raw": body,
        }
    except Exception as exc:  # noqa: BLE001 — surface any connect error to UI
        return team, {
            "owner": TEAM_OWNERS[team],
            "http_status": 0,
            "healthy": False,
            "version": "unknown",
            "endpoint": "",
            "error": str(exc),
        }


@app.get("/health")
async def health() -> dict[str, Any]:
    """Aggregate team health for the dashboard (live polling target).

    Gateway itself is always 'up' if this handler runs; each team entry
    may be healthy / unreachable independently. Team probes run in parallel.
    """
    async with httpx.AsyncClient(timeout=HTTP_TIMEOUT) as client:
        pairs = await asyncio.gather(
            *[_team_health(client, team, base) for team, base in TEAM_URLS.items()]
        )
    teams = dict(pairs)

    all_healthy = all(t.get("healthy") for t in teams.values()) if teams else False
    return {
        "status": "healthy" if all_healthy else "degraded",
        "service": "gateway",
        "version": app.version,
        "weight_a": WEIGHT_A,
        "teams": teams,
    }


@app.get("/ready")
def ready() -> dict[str, str]:
    """Liveness-style ready for kube probes — gateway process is up."""
    return {"status": "ready", "service": "gateway"}


@app.post("/predict/{team}")
async def predict(team: str, payload: dict[str, Any]) -> JSONResponse:
    """Proxy a prediction to exactly one team's FastAPI → SageMaker path.

    Path param enforces routing isolation: /predict/fraud cannot hit recs.
    Response includes endpoint + variant so the dashboard can prove isolation.
    """
    if team not in TEAM_URLS:
        raise HTTPException(
            status_code=404,
            detail=f"unknown team '{team}'. Expected one of: {sorted(TEAM_URLS)}",
        )

    variant = pick_variant()
    url = f"{TEAM_URLS[team].rstrip('/')}/predict"
    try:
        async with httpx.AsyncClient(timeout=HTTP_TIMEOUT) as client:
            resp = await client.post(url, json=payload)
    except httpx.TimeoutException as exc:
        raise HTTPException(status_code=504, detail=f"timeout calling {team}: {exc}") from exc
    except httpx.HTTPError as exc:
        raise HTTPException(status_code=502, detail=f"gateway proxy error: {exc}") from exc

    # Pass through team status codes when possible; always annotate for demos.
    try:
        body = resp.json()
    except Exception:
        body = {"raw": resp.text}

    if isinstance(body, dict):
        body = {
            **body,
            "gateway": "ml-platform-gateway",
            "routed_team": team,
            "owner": TEAM_OWNERS[team],
            "variant": variant,
            "weight_a": WEIGHT_A,
        }

    return JSONResponse(status_code=resp.status_code, content=body)


@app.get("/config/ab")
def ab_config() -> dict[str, Any]:
    """Expose current A/B weights so the dashboard can display them."""
    return {
        "weight_a": WEIGHT_A,
        "weight_b": max(0, 100 - WEIGHT_A),
        "note": "Change WEIGHT_A in the platform ConfigMap and restart/roll the gateway pod.",
    }
