import os
os.environ["DATABASE_URL"] = "sqlite:///./test.db"

from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_health():
    assert client.get("/health").json() == {"status": "UP"}

def test_root():
    response = client.get("/")
    assert response.status_code == 200
    assert response.json()["service"] == "TaskBoard API"

def test_create_task_validation():
    response = client.post("/api/tasks", json={"title": "Deploy application", "priority": "HIGH", "assignee": "Student"})
    assert response.status_code == 201
    assert response.json()["title"] == "Deploy application"

def test_create_rejects_invalid_priority():
    response = client.post("/api/tasks", json={"title": "Bad task", "priority": "URGENT"})
    assert response.status_code == 422

def test_create_rejects_empty_title():
    response = client.post("/api/tasks", json={"title": ""})
    assert response.status_code == 422

def test_task_crud_lifecycle():
    created = client.post("/api/tasks", json={"title": "Write README", "assignee": "Talin"}).json()
    task_id = created["id"]
    assert created["status"] == "TODO"
    assert created["priority"] == "MEDIUM"

    assert client.get(f"/api/tasks/{task_id}").json()["title"] == "Write README"
    assert any(t["id"] == task_id for t in client.get("/api/tasks").json())

    updated = client.put(f"/api/tasks/{task_id}", json={"status": "DONE"}).json()
    assert updated["status"] == "DONE"
    assert updated["title"] == "Write README"  # partial update keeps other fields

    assert client.delete(f"/api/tasks/{task_id}").status_code == 204
    assert client.get(f"/api/tasks/{task_id}").status_code == 404

def test_missing_task_returns_404_on_every_verb():
    assert client.get("/api/tasks/999999").status_code == 404
    assert client.put("/api/tasks/999999", json={"status": "DONE"}).status_code == 404
    assert client.delete("/api/tasks/999999").status_code == 404

def test_stats_count_by_status():
    before = client.get("/api/tasks/stats").json()
    client.post("/api/tasks", json={"title": "In flight", "status": "IN_PROGRESS"})
    after = client.get("/api/tasks/stats").json()
    assert after["total"] == before["total"] + 1
    assert after["inProgress"] == before["inProgress"] + 1
    assert after["total"] == after["todo"] + after["inProgress"] + after["done"]

def test_metrics_endpoint_exposes_prometheus_format():
    client.get("/health")
    body = client.get("/metrics").text
    assert "http_requests_total" in body
