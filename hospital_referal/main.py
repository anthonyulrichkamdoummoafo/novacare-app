from fastapi import FastAPI, Query, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field, validator
from typing import Optional, List
import logging
import traceback
from contextlib import asynccontextmanager
from hospital_recommender import recommend_hospitals

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('hospital_api.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

class HospitalRequest(BaseModel):
    lat: float = Field(..., ge=-90, le=90, description="Latitude coordinate")
    lon: float = Field(..., ge=-180, le=180, description="Longitude coordinate")
    type: Optional[str] = Field(None, description="Filter by facility type")
    top_n: int = Field(5, ge=1, le=50, description="Number of results to return")

class HospitalResponse(BaseModel):
    facility_name: str
    facility_type: str
    latitude: float
    longitude: float
    distance_km: float

@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Hospital Referral API started")
    yield
    logger.info("Hospital Referral API shutting down")

app = FastAPI(
    title="Hospital Referral API",
    description="API for finding nearby hospitals in Cameroon",
    version="1.0.0",
    lifespan=lifespan
)

# Enable CORS for Flutter access
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify exact origins
    allow_methods=["GET", "POST"],
    allow_headers=["*"],
)

@app.get("/recommend-hospitals", response_model=List[HospitalResponse])
async def get_hospitals(
    lat: float = Query(..., ge=-90, le=90, description="Latitude coordinate"),
    lon: float = Query(..., ge=-180, le=180, description="Longitude coordinate"),
    type: Optional[str] = Query(None, description="Filter by facility type"),
    top_n: int = Query(5, ge=1, le=50, description="Number of results to return")
):
    """
    Get recommended hospitals based on user location.

    - **lat**: User's latitude coordinate
    - **lon**: User's longitude coordinate
    - **type**: Optional filter by facility type (e.g., "Hospital", "Centre")
    - **top_n**: Number of results to return (1-50)
    """
    try:
        logger.info(f"Hospital search request: lat={lat}, lon={lon}, type={type}, top_n={top_n}")

        user_location = (lat, lon)
        hospitals = recommend_hospitals(user_location, top_n, type)

        if hospitals.empty:
            logger.warning(f"No hospitals found for location ({lat}, {lon}) with type filter: {type}")
            return []

        result = hospitals.to_dict(orient="records")
        logger.info(f"Returning {len(result)} hospitals")
        return result

    except Exception as e:
        logger.error(f"Error in get_hospitals: {e}\n{traceback.format_exc()}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch hospitals: {str(e)}"
        )

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy", "service": "hospital-referral-api"}
