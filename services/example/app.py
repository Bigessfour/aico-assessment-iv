from fastapi import FastAPI, HTTPException
from fastapi.responses import JSONResponse
import boto3, os, json

app = FastAPI()

ENDPOINT_NAME = os.getenv("ENDPOINT_NAME", "")
AWS_REGION = os.getenv("AWS_REGION", "us-east-1")


def get_sagemaker_client():
    return boto3.client("sagemaker-runtime", region_name=AWS_REGION)


@app.get("/health")
def health():
    return {"status": "healthy", "endpoint": ENDPOINT_NAME}


@app.get("/ready")
def ready():
    if not ENDPOINT_NAME:
        return JSONResponse(
            status_code=503,
            content={"status": "not ready", "error": "ENDPOINT_NAME not set"},
        )
    try:
        get_sagemaker_client()
        return {"status": "ready"}
    except Exception as e:
        return JSONResponse(
            status_code=503,
            content={"status": "not ready", "error": str(e)},
        )


@app.post("/predict")
def predict(payload: dict):
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
        return {"prediction": result}
    except Exception as e:
        raise HTTPException(status_code=502, detail=str(e))
