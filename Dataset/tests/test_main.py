import pytest
from fastapi.testclient import TestClient
from main import app

client = TestClient(app)

def test_predict_disease_success():
    """Test successful disease prediction with multiple results"""
    test_data = {"symptoms": ["fever", "headache", "fatigue"]}
    response = client.post("/predict", json=test_data)
    assert response.status_code == 200
    body = response.json()
    assert "predictions" in body
    assert isinstance(body["predictions"], list)
    assert len(body["predictions"]) > 1
    for pred in body["predictions"]:
        assert "disease" in pred
        assert "confidence" in pred
        assert "urgency" in pred

def test_predict_disease_empty_symptoms():
    """Test prediction with empty symptoms list"""
    response = client.post("/predict", json={"symptoms": []})
    assert response.status_code == 400
    assert response.json()["error"] == "Symptom list cannot be empty."

def test_predict_disease_invalid_input():
    """Test prediction with invalid input format"""
    response = client.post("/predict", json={"wrong_key": ["fever"]})
    assert response.status_code == 422

def test_webhook_success():
    """Test webhook with user-friendly multiple prediction format"""
    test_data = {
        "queryResult": {
            "queryText": "I have cough and headache and fatigue"
        }
    }
    response = client.post("/webhook", json=test_data)
    assert response.status_code == 200
    msg = response.json()["fulfillmentText"]
    assert "🤖 Based on your symptoms" in msg
    assert "🦠" in msg
    assert "Urgency:" in msg
    assert "%" in msg

def test_webhook_no_symptoms():
    """Test webhook with query that has no known symptoms"""
    test_data = {
        "queryResult": {
            "queryText": "I feel like spaghetti"
        }
    }
    response = client.post("/webhook", json=test_data)
    assert response.status_code == 200
    assert "No known symptoms detected" in response.json()["fulfillmentText"]

def test_webhook_malformed_request():
    """Test webhook with malformed request"""
    response = client.post("/webhook", json={"wrong_structure": "value"})
    assert response.status_code == 200
    assert "Error:" in response.json()["fulfillmentText"]

def test_get_symptoms_success():
    """Test retrieval of symptom vocabulary"""
    response = client.get("/symptoms")
    assert response.status_code == 200
    assert isinstance(response.json(), list)
    assert len(response.json()) > 0

def test_get_symptoms_error_handling(monkeypatch):
    """Force error in /symptoms by patching"""
    from main import columns
    monkeypatch.setattr('main.columns', None)
    response = client.get("/symptoms")
    assert response.status_code == 500
    assert "error" in response.json()
