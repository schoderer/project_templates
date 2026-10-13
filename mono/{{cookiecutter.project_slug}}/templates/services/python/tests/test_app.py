from fastapi.testclient import TestClient

from __NAME_SNAKE__.app import app

client = TestClient(app)


def test_health() -> None:
    response = client.get("/health")
    assert response.status_code == 200
    assert response.text == "ok"


def test_hello() -> None:
    response = client.get("/hello/nix")
    assert response.status_code == 200
    assert response.text == "Hello, nix!"
