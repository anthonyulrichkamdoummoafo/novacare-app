import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from fastapi.testclient import TestClient
from main import app
from model_utils import model_inference, extract_symptoms_from_text

client = TestClient(app)

def test_webhook_with_sentence():
    payload = {
        "queryResult": {
            "queryText": "I have my stomach pains"
        }
    }
    response = client.post("/webhook", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert "fulfillmentText" in data
    print("Webhook response:", data["fulfillmentText"])

def test_predict_valid_symptoms():
    payload = {
        "symptoms": ["headache", "nausea"]
    }
    response = client.post("/predict", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert "predicted_disease" in data
    assert "urgency_level" in data

def test_predict_invalid_input():
    payload = {
        "symptoms": "not a list"  # invalid type for symptoms
    }
    response = client.post("/predict", json=payload)
    assert response.status_code == 422  # Validation error from Pydantic

def test_predict_empty_symptoms_list():
    payload = {
        "symptoms": []
    }
    response = client.post("/predict", json=payload)
    assert response.status_code == 400
    data = response.json()
    assert "error" in data
    assert data["error"] == "Symptom list cannot be empty."

def test_webhook_no_symptoms():
    payload = {
        "queryResult": {
            "queryText": "I feel great with no symptoms"
        }
    }
    response = client.post("/webhook", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert "fulfillmentText" in data
    assert "couldn't detect any known symptoms" in data["fulfillmentText"]

def test_model_inference_and_extraction():
    symptoms = ["headache", "fatigue"]
    predicted_disease, predicted_urgency = model_inference(symptoms)
    assert isinstance(predicted_disease, str)
    assert isinstance(predicted_urgency, str)

    text = "I have a headache and some fatigue"
    extracted = extract_symptoms_from_text(text)
    assert "headache" in extracted
    assert "fatigue" in extracted
