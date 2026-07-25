import pytest
from fastapi.testclient import TestClient
from serve import app


@pytest.fixture
def client():
    with TestClient(app) as c:
        yield c


def test_health(client):
    r = client.get("/health")
    assert r.status_code == 200
    assert r.json()["status"] == "ok"
    assert r.json()["model_loaded"] is True


def test_predict_setosa(client):
    r = client.post("/predict", json={
        "sepal_length": 5.1, "sepal_width": 3.5,
        "petal_length": 1.4, "petal_width": 0.2,
    })
    assert r.status_code == 200
    assert r.json()["prediction"] == "setosa"


def test_invalid_input(client):
    r = client.post("/predict", json={
        "sepal_length": -1, "sepal_width": 3.5,
        "petal_length": 1.4, "petal_width": 0.2,
    })
    assert r.status_code == 422
