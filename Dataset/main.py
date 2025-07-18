from fastapi import FastAPI, Request, HTTPException, status
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field, validator
from typing import List, Optional, Dict, Any
import logging
import traceback
from contextlib import asynccontextmanager
from datetime import datetime
import time
from functools import lru_cache

from model_utils import model_inference, extract_symptoms_from_text, columns

# Enhanced logging configuration
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('logs/app.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

class SymptomInput(BaseModel):
    symptoms: List[str] = Field(..., min_items=1, max_items=20, description="List of symptoms")

    @validator('symptoms')
    def validate_symptoms(cls, v):
        if not v:
            raise ValueError('Symptoms list cannot be empty')
        # Clean and validate symptoms
        cleaned = [s.strip().lower() for s in v if s.strip()]
        if not cleaned:
            raise ValueError('No valid symptoms provided')
        return cleaned

class PredictionResponse(BaseModel):
    predictions: List[Dict[str, Any]]
    timestamp: datetime
    processing_time_ms: float
    symptoms_used: List[str]

class WebhookRequest(BaseModel):
    queryResult: Dict[str, Any]

@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Disease Prediction API started and ready to receive requests")
    yield
    logger.info("Disease Prediction API is shutting down")

app = FastAPI(
    title="Disease Prediction API",
    description="AI-powered disease prediction based on symptoms",
    version="2.0.0",
    lifespan=lifespan
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure for production
    allow_methods=["GET", "POST"],
    allow_headers=["*"],
)

class SymptomInput(BaseModel):
    symptoms: List[str]

@lru_cache(maxsize=1000)
def cached_model_inference(symptoms_tuple):
    """Cached version of model inference for better performance"""
    return model_inference(list(symptoms_tuple))

@app.post("/predict", response_model=PredictionResponse)
async def predict_disease(input: SymptomInput):
    """
    Predict diseases based on symptoms.

    - **symptoms**: List of symptoms (1-20 items)

    Returns predictions with confidence scores and urgency levels.
    """
    start_time = time.time()

    try:
        logger.info(f"Prediction request with symptoms: {input.symptoms}")

        # Validate symptoms against known symptoms
        valid_symptoms = [s for s in input.symptoms if s in columns]
        if not valid_symptoms:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="No valid symptoms found. Please check symptom names."
            )

        # Use cached inference for better performance
        symptoms_tuple = tuple(sorted(valid_symptoms))
        predictions = cached_model_inference(symptoms_tuple)

        processing_time = (time.time() - start_time) * 1000

        response = PredictionResponse(
            predictions=predictions,
            timestamp=datetime.now(),
            processing_time_ms=round(processing_time, 2),
            symptoms_used=valid_symptoms
        )

        logger.info(f"Prediction completed in {processing_time:.2f}ms")
        return response

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Prediction error: {e}\n{traceback.format_exc()}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Prediction failed: {str(e)}"
        )


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
