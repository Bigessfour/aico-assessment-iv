"""Contract tests for the three team FastAPI wrappers.

These cover what the rubric cares about: the /health, /ready, /predict contract,
routing isolation via ENDPOINT_NAME, and the SageMaker failure path surfacing as
502 instead of a 500 stack trace.
"""

import json

import pytest
from botocore.exceptions import ClientError
from fastapi.testclient import TestClient
from helpers import load_service

# alias, path, expected endpoint, service name
TEAMS = [
    ("fraud_app", "fraud-detection/app.py", "aico-iv-fraud", "fraud-detection"),
    ("recs_app", "recommendations/app.py", "aico-iv-recs", "recommendations"),
    ("forecast_app", "forecasting/app.py", "aico-iv-forecast", "forecasting"),
]


class FakeBody:
    def __init__(self, payload):
        self._payload = payload

    def read(self):
        return json.dumps(self._payload).encode()


class FakeSageMaker:
    """Stand-in for the sagemaker-runtime client.

    Records every `invoke_endpoint` call so a test can assert which endpoint was
    hit — that is how routing isolation is proven without AWS. Constructing it
    with `error=` makes it raise instead, which is how the 502 failure path gets
    tested: you cannot ask AWS to have an outage on demand, so it is simulated.
    """

    def __init__(self, payload=None, error=None):
        self._payload = payload or {"score": 0.99}
        self._error = error
        self.calls = []

    def invoke_endpoint(self, **kwargs):
        self.calls.append(kwargs)
        if self._error:
            raise self._error
        return {"Body": FakeBody(self._payload)}


def build(monkeypatch, alias, path, endpoint, model_version="test-model-1"):
    monkeypatch.setenv("ENDPOINT_NAME", endpoint)
    monkeypatch.setenv("AWS_REGION", "us-east-1")
    monkeypatch.setenv("MODEL_VERSION", model_version)
    return load_service(alias, path)


@pytest.mark.parametrize("alias,path,endpoint,service", TEAMS)
def test_health_reports_team_endpoint_and_model_version(monkeypatch, alias, path, endpoint, service):
    module = build(monkeypatch, alias, path, endpoint)
    body = TestClient(module.app).get("/health").json()

    assert body["status"] == "healthy"
    assert body["service"] == service
    assert body["endpoint"] == endpoint
    assert body["model_version"] == "test-model-1"


@pytest.mark.parametrize("alias,path,endpoint,service", TEAMS)
def test_ready_is_503_without_endpoint_name(monkeypatch, alias, path, endpoint, service):
    module = build(monkeypatch, alias, path, endpoint="")
    resp = TestClient(module.app).get("/ready")

    assert resp.status_code == 503
    assert "ENDPOINT_NAME" in resp.json()["error"]


@pytest.mark.parametrize("alias,path,endpoint,service", TEAMS)
def test_predict_calls_only_its_own_endpoint(monkeypatch, alias, path, endpoint, service):
    module = build(monkeypatch, alias, path, endpoint)
    fake = FakeSageMaker(payload={"prediction": [0.1]})
    monkeypatch.setattr(module, "get_sagemaker_client", lambda: fake)

    resp = TestClient(module.app).post(
        "/predict", json={"x": 1}, headers={"X-Model-Variant": "candidate"}
    )
    body = resp.json()

    assert resp.status_code == 200
    assert fake.calls[0]["EndpointName"] == endpoint
    assert body["endpoint"] == endpoint
    assert body["served_variant"] == "candidate"
    assert body["model_version"] == "test-model-1"


@pytest.mark.parametrize("alias,path,endpoint,service", TEAMS)
def test_predict_maps_sagemaker_failure_to_502(monkeypatch, alias, path, endpoint, service):
    module = build(monkeypatch, alias, path, endpoint)
    error = ClientError(
        {"Error": {"Code": "ValidationError", "Message": "endpoint not found"}},
        "InvokeEndpoint",
    )
    monkeypatch.setattr(module, "get_sagemaker_client", lambda: FakeSageMaker(error=error))

    resp = TestClient(module.app).post("/predict", json={"x": 1})

    assert resp.status_code == 502
    assert "sagemaker invoke failed" in resp.json()["detail"]
