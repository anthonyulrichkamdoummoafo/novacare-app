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
        top_predictions, urgency_level = model_inference(input.symptoms)
        return {
            "top_predictions": top_predictions,
            "urgency_level": urgency_level
        }
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
            return JSONResponse({
                "fulfillmentText": "Sorry, I couldn't detect any known symptoms. Please describe your symptoms clearly."
            })

        top_predictions, urgency_level = model_inference(matched_symptoms)
        best = top_predictions[0]
        response_text = (
            f"🦠 Possible Disease: {best['disease']} (Confidence: {best['confidence']})\n"
            f"⚠️ Urgency Level: {urgency_level}"
        )
        return JSONResponse({"fulfillmentText": response_text})
    except Exception as e:
        logging.error(f"Webhook error: {e}\n{traceback.format_exc()}")
        return JSONResponse({"fulfillmentText": f"Error: {str(e)}"})

@app.get("/symptoms")
async def get_symptoms():
    try:
        return JSONResponse(content=columns)
    except Exception as e:
        logging.error(f"Symptoms route error: {e}\n{traceback.format_exc()}")
        return JSONResponse(status_code=500, content={"error": str(e)})
