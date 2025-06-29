from fastapi import FastAPI, Query
from fastapi.middleware.cors import CORSMiddleware
from hospital_recommender import recommend_hospitals

app = FastAPI()

# Enable CORS for Flutter access
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/recommend-hospitals")
def get_hospitals(lat: float, lon: float, type: str = None, top_n: int = 5):
    user_location = (lat, lon)
    hospitals = recommend_hospitals(user_location, top_n, type)
    return hospitals.to_dict(orient="records")
