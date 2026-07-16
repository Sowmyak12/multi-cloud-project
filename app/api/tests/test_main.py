import fakeredis
import pytest
from fastapi.testclient import TestClient

from .. import main


@pytest.fixture(autouse=True)
def fake_redis(monkeypatch):
    monkeypatch.setattr(main, "r", fakeredis.FakeStrictRedis(decode_responses=True))


@pytest.fixture
def client():
    return TestClient(main.app)


def test_healthz(client):
    resp = client.get("/healthz")
    assert resp.status_code == 200
    assert resp.json()["status"] == "ok"


def test_readyz(client):
    resp = client.get("/readyz")
    assert resp.status_code == 200
    assert resp.json()["status"] == "ready"


def test_list_tasks(client):
    client.post("/tasks", json={"title": "first task"})
    client.post("/tasks", json={"title": "second task"})

    resp = client.get("/tasks")
    assert resp.status_code == 200
    titles = {task["title"] for task in resp.json()}
    assert titles == {"first task", "second task"}


def test_create_and_get_task(client):
    created = client.post("/tasks", json={"title": "write portfolio project"})
    assert created.status_code == 201
    task_id = created.json()["id"]

    fetched = client.get(f"/tasks/{task_id}")
    assert fetched.status_code == 200
    assert fetched.json()["title"] == "write portfolio project"
    assert fetched.json()["done"] is False


def test_update_task(client):
    created = client.post("/tasks", json={"title": "deploy to gke"})
    task_id = created.json()["id"]

    updated = client.patch(f"/tasks/{task_id}", params={"done": True})
    assert updated.status_code == 200
    assert updated.json()["done"] is True


def test_delete_task(client):
    created = client.post("/tasks", json={"title": "tear down cluster"})
    task_id = created.json()["id"]

    deleted = client.delete(f"/tasks/{task_id}")
    assert deleted.status_code == 204

    missing = client.get(f"/tasks/{task_id}")
    assert missing.status_code == 404


def test_get_missing_task_404(client):
    resp = client.get("/tasks/does-not-exist")
    assert resp.status_code == 404
