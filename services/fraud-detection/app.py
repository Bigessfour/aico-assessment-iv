"""Fraud Detection FastAPI wrapper around a SageMaker endpoint.

Why this exists:
  SageMaker endpoints are not a friendly HTTP API for other teams.
  We wrap InvokeEndpoint in a small service with /health, /ready, /predict
  so Kubernetes can probe us and callers get consistent JSON errors.
"""

from fastapi import FastAPI, HTTPException
from fastapi.responses import JSONResponse
from botocore.config import Config
from botocore.exceptions import BotoCoreError, ClientError
import boto3
import os
import json

app = FastAPI(title="fraud-detection", version="0.1.0")

ENDPOINT_NAME = os.getenv("ENDPOINT_NAME", "")
AWS_REGION = os.getenv("AWS_REGION", "us-east-1")
# Fail predict calls quickly instead of hanging forever (failure-path requirement)
INVOKE_TIMEOUT_SECONDS = int(os.getenv("INVOKE_TIMEOUT_SECONDS", "10"))

_boto_config = Config(
    connect_timeout=INVOKE_TIMEOUT_SECONDS,
    read_timeout=INVOKE_TIMEOUT_SECONDS,
    retries={"max_attempts": 2},
)


def get_sagemaker_client():
    return boto3.client(
        "sagemaker-runtime",
        region_name=AWS_REGION,
        config=_boto_config,
    )


@app.get("/health")
def health():
    """Liveness: is the process up? Does not call SageMaker."""
    return {
        "status": "healthy",
        "service": "fraud-detection",
        "team": "fraud",
        "endpoint": ENDPOINT_NAME,
        "version": app.version,
    }


@app.get("/ready")
def ready():
    """Readiness: can we construct a client and is ENDPOINT_NAME set?
    Kubernetes uses this to decide whether to send traffic.
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
def predict(payload: dict):
    """Forward JSON body to the fraud SageMaker endpoint."""
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
        return {"service": "fraud-detection", "endpoint": ENDPOINT_NAME, "prediction": result}
    except (BotoCoreError, ClientError, TimeoutError) as e:
        # Propagate as 502 so callers know upstream (SageMaker) failed
        raise HTTPException(status_code=502, detail=f"sagemaker invoke failed: {e}") from e
    except Exception as e:
        raise HTTPException(status_code=502, detail=str(e)) from e
