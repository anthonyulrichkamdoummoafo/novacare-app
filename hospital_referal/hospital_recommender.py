import pandas as pd
from geopy.distance import geodesic

# Load and clean data once at startup
df = pd.read_excel("camerounhopitals.xlsx")
df.columns = df.columns.str.lower().str.strip()
df = df.rename(columns={
    "facility_n": "facility_name",
    "facility_t": "facility_type",
    "lat": "latitude",
    "long": "longitude"
})
df = df[df["latitude"].notnull() & df["longitude"].notnull()]
df = df[(df["latitude"] != 0) & (df["longitude"] != 0)]

def recommend_hospitals(patient_coords, top_n=5, required_type=None):
    data = df.copy()
    if required_type:
        data = data[data["facility_type"].str.contains(required_type, case=False, na=False)]

    data["distance_km"] = data.apply(
        lambda row: geodesic(patient_coords, (row["latitude"], row["longitude"])).km,
        axis=1
    )
    data = data.sort_values("distance_km").head(top_n)
    data["distance_km"] = data["distance_km"].round(2)
    return data[["facility_name", "facility_type", "latitude", "longitude", "distance_km"]]
