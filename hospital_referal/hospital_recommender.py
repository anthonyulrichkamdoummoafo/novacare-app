import pandas as pd
from geopy.distance import geodesic
import logging
from typing import Tuple, Optional
import os

logger = logging.getLogger(__name__)

def load_hospital_data():
    """Load and clean hospital data with proper error handling"""
    try:
        if not os.path.exists("camerounhopitals.xlsx"):
            raise FileNotFoundError("Hospital data file not found")

        df = pd.read_excel("camerounhopitals.xlsx")
        logger.info(f"Loaded {len(df)} hospital records")

        # Clean column names
        df.columns = df.columns.str.lower().str.strip()
        df = df.rename(columns={
            "facility_n": "facility_name",
            "facility_t": "facility_type",
            "lat": "latitude",
            "long": "longitude"
        })

        # Clean data
        initial_count = len(df)
        df = df[df["latitude"].notnull() & df["longitude"].notnull()]
        df = df[(df["latitude"] != 0) & (df["longitude"] != 0)]
        df = df[(df["latitude"].between(-90, 90)) & (df["longitude"].between(-180, 180))]

        # Clean facility names
        df["facility_name"] = df["facility_name"].str.strip()
        df["facility_type"] = df["facility_type"].str.strip()

        final_count = len(df)
        logger.info(f"Cleaned data: {initial_count} -> {final_count} records")

        return df

    except Exception as e:
        logger.error(f"Error loading hospital data: {e}")
        raise

# Load data at startup
df = load_hospital_data()

def recommend_hospitals(patient_coords: Tuple[float, float], top_n: int = 5, required_type: Optional[str] = None) -> pd.DataFrame:
    """
    Recommend hospitals based on patient location and optional type filter.

    Args:
        patient_coords: Tuple of (latitude, longitude)
        top_n: Number of hospitals to return
        required_type: Optional filter by facility type

    Returns:
        DataFrame with recommended hospitals
    """
    try:
        # Validate coordinates
        lat, lon = patient_coords
        if not (-90 <= lat <= 90) or not (-180 <= lon <= 180):
            raise ValueError(f"Invalid coordinates: lat={lat}, lon={lon}")

        data = df.copy()
        logger.info(f"Starting with {len(data)} hospitals")

        # Apply type filter if specified
        if required_type:
            original_count = len(data)
            data = data[data["facility_type"].str.contains(required_type, case=False, na=False)]
            logger.info(f"After type filter '{required_type}': {len(data)} hospitals")

            if data.empty:
                logger.warning(f"No hospitals found matching type: {required_type}")
                return pd.DataFrame(columns=["facility_name", "facility_type", "latitude", "longitude", "distance_km"])

        # Calculate distances
        def calculate_distance(row):
            try:
                return geodesic(patient_coords, (row["latitude"], row["longitude"])).km
            except Exception as e:
                logger.warning(f"Error calculating distance for {row['facility_name']}: {e}")
                return float('inf')

        data["distance_km"] = data.apply(calculate_distance, axis=1)

        # Remove hospitals with invalid distances
        data = data[data["distance_km"] != float('inf')]

        # Sort by distance and get top N
        data = data.sort_values("distance_km").head(top_n)
        data["distance_km"] = data["distance_km"].round(2)

        result = data[["facility_name", "facility_type", "latitude", "longitude", "distance_km"]]
        logger.info(f"Returning {len(result)} hospitals")

        return result

    except Exception as e:
        logger.error(f"Error in recommend_hospitals: {e}")
        raise

def get_facility_types() -> list:
    """Get list of available facility types"""
    try:
        return sorted(df["facility_type"].dropna().unique().tolist())
    except Exception as e:
        logger.error(f"Error getting facility types: {e}")
        return []
