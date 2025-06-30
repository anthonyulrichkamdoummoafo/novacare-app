from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from typing import List
import logging
import traceback
from contextlib import asynccontextmanager

from model_utils import model_inference, extract_symptoms_from_text, columns

logging.basicConfig(filename='logs/app.log', level=logging.INFO,
                    format='%(asctime)s:%(levelname)s:%(message)s')

@asynccontextmanager
async def lifespan(app: FastAPI):
    logging.info("API started and ready to receive requests")
    yield
    logging.info("API is shutting down")

app = FastAPI(lifespan=lifespan)

class SymptomInput(BaseModel):
    symptoms: List[str]

@app.post("/predict")
async def predict_disease(input: SymptomInput):
    if not input.symptoms:
        return JSONResponse(status_code=400, content={"error": "Symptom list cannot be empty."})
    try:
        predictions = model_inference(input.symptoms)
        return {"predictions": predictions}
    except Exception as e:
        logging.error(f"Prediction error: {e}\n{traceback.format_exc()}")
        return JSONResponse(status_code=500, content={"error": str(e)})


@app.post("/webhook")
async def webhook(request: Request):
    try:
        body = await request.json()
        user_query = body.get('queryResult', {}).get('queryText', '')
        matched_symptoms = extract_symptoms_from_text(user_query)

        if not matched_symptoms:
            return JSONResponse({"fulfillmentText": "Error: No known symptoms detected in your query."})

        predictions = model_inference(matched_symptoms)

        # Build human-friendly message
        response_lines = ["🤖 Based on your symptoms, here are possible conditions:"]
        for i, pred in enumerate(predictions, 1):
            line = f"{i}. 🦠 {pred['disease']} — Urgency: {pred['urgency']} (Confidence: {pred['confidence']}%)"
            response_lines.append(line)

        return JSONResponse({"fulfillmentText": "\n".join(response_lines)})
    except Exception as e:
        logging.error(f"Webhook error: {e}\n{traceback.format_exc()}")
        return JSONResponse({"fulfillmentText": f"Error: {str(e)}"})


@app.get("/symptoms")
async def get_symptoms():
    try:
        if columns is None:
            raise ValueError("Symptoms list is not available")
        return JSONResponse(content=columns)
    except Exception as e:
        logging.error(f"Symptoms route error: {e}\n{traceback.format_exc()}")
        return JSONResponse(status_code=500, content={"error": str(e)})
