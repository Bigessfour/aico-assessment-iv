"""Fraud Detection FastAPI wrapper around a SageMaker endpoint.

Talking points (presentation):
  - SageMaker InvokeEndpoint is AWS SDK only — not a friendly REST API.
  - Platform eng wraps each team's endpoint in FastAPI so callers and
    Kubernetes get the same contract: /health, /ready, /predict.
  - This service is owned by the Fraud team; ENDPOINT_NAME must point at
    aico-iv-fraud (not recs/forecast) so routing stays correct.
"""

from typing import Optional

from fastapi import FastAPI, Header, HTTPException
from fastapi.responses import JSONResponse
from botocore.config import Config
from botocore.exceptions import BotoCoreError, ClientError
import boto3
import os
import json

app = FastAPI(title="fraud-detection", version="0.1.0")

# --- Config from environment (ConfigMap + Secret in Kubernetes) ---
# ENDPOINT_NAME: which SageMaker endpoint to call (set per team).
# AWS_REGION: must match where the endpoint lives (us-east-1 for class).
# AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY: injected from a K8s Secret
#   so the pod can call sagemaker:InvokeEndpoint (not in this file).
ENDPOINT_NAME = os.getenv("ENDPOINT_NAME", "")
AWS_REGION = os.getenv("AWS_REGION", "us-east-1")
# Fail predict calls quickly instead of hanging forever (assessment
# failure-path requirement: timeout / error propagation).
INVOKE_TIMEOUT_SECONDS = int(os.getenv("INVOKE_TIMEOUT_SECONDS", "10"))
# MODEL_VERSION: which trained model this endpoint is serving. Lives in the
# ConfigMap so the dashboard shows a real version without an image rebuild.
MODEL_VERSION = os.getenv("MODEL_VERSION", "unversioned")

_boto_config = Config(
    connect_timeout=INVOKE_TIMEOUT_SECONDS,
    read_timeout=INVOKE_TIMEOUT_SECONDS,
    retries={"max_attempts": 2},
)


def get_sagemaker_client():
    """Build a sagemaker-runtime client with our timeout/retry policy.

    Uses the default boto3 credential chain (env vars in the pod,
    or AWS_PROFILE / aws login locally).
    """
    return boto3.client(
        "sagemaker-runtime",
        region_name=AWS_REGION,
        config=_boto_config,
    )


@app.get("/health")
def health():
    """Liveness probe target.

    Meaning: "is the Python process up?"
    Does NOT call SageMaker — if the app is frozen but AWS is fine,
    we still want kubelet to restart us. Keep this cheap and local.
    """
    return {
        "status": "healthy",
        "service": "fraud-detection",
        "team": "fraud",
        "endpoint": ENDPOINT_NAME,
        "version": app.version,
        "model_version": MODEL_VERSION,
    }


@app.get("/ready")
def ready():
    """Readiness probe target.

    Meaning: "should Kubernetes send traffic to this pod?"
    Returns 503 if ENDPOINT_NAME is missing or we cannot build a client
    (e.g. bad/missing AWS creds). Service endpoints only include Ready pods.
    """
    if not ENDPOINT_NAME:
        return JSONResponse(
            status_code=503,
            content={"status": "not ready", "error": "ENDPOINT_NAME not set"},
        )
    try:
        get_sagemaker_client()
        return {"status": "ready", "endpoint": ENDPOINT_NAME}
    except Exception as e:
        return JSONResponse(
            status_code=503,
            content={"status": "not ready", "error": str(e)},
        )


@app.post("/predict")
def predict(payload: dict, x_model_variant: Optional[str] = Header(default=None)):
    """Business path: forward JSON to the fraud SageMaker endpoint.

    Success → {"prediction": ...} tagged with service/endpoint for demos.
    SageMaker/boto failures → HTTP 502 so callers know upstream failed
    (not a bug in our routing).
    X-Model-Variant is set by the gateway's A/B split and echoed back so a
    caller can see which variant served the request.
    """
    if not ENDPOINT_NAME:
        raise HTTPException(status_code=503, detail="ENDPOINT_NAME not set")
    try:
        client = get_sagemaker_client()
        response = client.invoke_endpoint(
            EndpointName=ENDPOINT_NAME,
            ContentType="application/json",
            Body=json.dumps(payload),
        )
        result = json.loads(response["Body"].read().decode())
        return {
            "service": "fraud-detection",
            "endpoint": ENDPOINT_NAME,
            "model_version": MODEL_VERSION,
            "served_variant": x_model_variant or "direct",
            "prediction": result,
        }
    except (BotoCoreError, ClientError, TimeoutError) as e:
        # 502 = bad gateway: we are up, but SageMaker (or network) failed
        raise HTTPException(status_code=502, detail=f"sagemaker invoke failed: {e}") from e
    except Exception as e:
        raise HTTPException(status_code=502, detail=str(e)) from e
