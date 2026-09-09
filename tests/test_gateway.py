"""Tests for the platform gateway: aggregation, routing isolation, A/B, counters."""

import json

import httpx
import pytest
from fastapi.testclient import TestClient
from helpers import load_service

TEAM_HEALTH = {
    "fraud": {"status": "healthy", "version": "0.1.0", "model_version": "fraud-1", "endpoint": "aico-iv-fraud"},
    "recommendations": {"status": "healthy", "version": "0.1.0", "model_version": "recs-1", "endpoint": "aico-iv-recs"},
    "forecasting": {"status": "healthy", "version": "0.1.0", "model_version": "fc-1", "endpoint": "aico-iv-forecast"},
}


class FakeResponse:
    def __init__(self, status_code, payload):
        self.status_code = status_code
        self._payload = payload
        self.text = json.dumps(payload)

    def json(self):
        return self._payload


class FakeClient:
    """Async httpx stand-in. Records the last POST so we can assert on headers."""

    last_post = None
    post_error = None

    def __init__(self, *args, **kwargs):
        pass

    async def __aenter__(self):
        return self

    async def __aexit__(self, *exc):
        return False

    async def get(self, url):
        team = next(t for t in TEAM_HEALTH if t in url)
        return FakeResponse(200, TEAM_HEALTH[team])

    async def post(self, url, json=None, headers=None):
        FakeClient.last_post = {"url": url, "json": json, "headers": headers or {}}
        if FakeClient.post_error:
            raise FakeClient.post_error
        return FakeResponse(200, {"service": "team", "prediction": [1]})


@pytest.fixture
def gateway(monkeypatch):
    """Fresh gateway module per test: fresh env constants and fresh counters."""
    FakeClient.last_post = None
    FakeClient.post_error = None
    monkeypatch.setenv("WEIGHT_A", "100")  # deterministic variant for assertions
    monkeypatch.setenv("VARIANT_A_LABEL", "baseline")
    monkeypatch.setenv("VARIANT_B_LABEL", "candidate")
    module = load_service("gateway_app", "gateway/app.py")
    monkeypatch.setattr(module.httpx, "AsyncClient", FakeClient)
    return module


def test_health_aggregates_all_three_teams(gateway):
    body = TestClient(gateway.app).get("/health").json()

    assert body["status"] == "healthy"
    assert set(body["teams"]) == {"fraud", "recommendations", "forecasting"}
    assert body["teams"]["fraud"]["model_version"] == "fraud-1"
    assert body["requests"]["total"] == 0


def test_unknown_team_is_404_not_a_proxy_attempt(gateway):
    resp = TestClient(gateway.app).post("/predict/marketing", json={})

    assert resp.status_code == 404
    assert FakeClient.last_post is None


def test_predict_routes_to_the_named_team_and_forwards_variant(gateway):
    resp = TestClient(gateway.app).post("/predict/recommendations", json={"user_id": "u-1"})
    body = resp.json()

    assert resp.status_code == 200
    assert "recommendations-api.recommendations" in FakeClient.last_post["url"]
    assert FakeClient.last_post["headers"]["X-Model-Variant"] == "baseline"
    assert body["routed_team"] == "recommendations"
    assert body["variant"] == "baseline"


def test_stats_count_requests_per_team_and_variant(gateway):
    client = TestClient(gateway.app)
    client.post("/predict/fraud", json={})
    client.post("/predict/fraud", json={})
    client.post("/predict/forecasting", json={})

    stats = client.get("/stats").json()

    assert stats["total"] == 3
    assert stats["errors"] == 0
    assert stats["by_team"]["fraud"] == 2
    assert stats["by_team"]["forecasting"] == 1
    assert stats["by_variant"]["baseline"] == 3


def test_upstream_timeout_becomes_504_and_counts_as_error(gateway):
    FakeClient.post_error = httpx.TimeoutException("read timeout")
    client = TestClient(gateway.app)

    resp = client.post("/predict/fraud", json={})

    assert resp.status_code == 504
    assert client.get("/stats").json()["errors"] == 1


def test_weight_zero_sends_everything_to_variant_b(monkeypatch):
    monkeypatch.setenv("WEIGHT_A", "0")
    module = load_service("gateway_app_b", "gateway/app.py")

    assert {module.pick_variant() for _ in range(50)} == {"candidate"}
