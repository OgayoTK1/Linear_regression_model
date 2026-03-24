from fastapi import FastAPI, HTTPException, UploadFile, File, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field, validator
import joblib
import numpy as np
import pandas as pd
import io
import os
from sklearn.ensemble import RandomForestRegressor
from sklearn.preprocessing import StandardScaler
from sklearn.model_selection import train_test_split

app = FastAPI(
    title="EV Battery Range Predictor",
    description="Predicts the electric driving range (km) of electric vehicles from their technical specifications.",
    version="1.0.0",
)

# ── CORS Middleware ───────────────────────────────────────────────────────────
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:3000",
        "http://localhost:8080",
        "http://localhost:8000",
        "https://linear-regression-model-3-ip44.onrender.com",
    ],
    allow_credentials=True,
    allow_methods=["GET", "POST"],
    allow_headers=["Content-Type", "Authorization", "Accept"],
)

BASE = os.path.dirname(os.path.abspath(__file__))


def load_artifacts():
    global model, scaler, feat_names
    model      = joblib.load(os.path.join(BASE, "models/best_model.pkl"))
    scaler     = joblib.load(os.path.join(BASE, "models/scaler.pkl"))
    feat_names = joblib.load(os.path.join(BASE, "models/feature_names.pkl"))


load_artifacts()


# Pydantic Schema — 12 fields matching feature_names.pkl exactly 
class EVInput(BaseModel):
    top_speed_kmh: float = Field(
        ..., ge=50.0, le=500.0,
        description="Top speed in km/h (50 - 500)"
    )
    battery_capacity_kwh: float = Field(
        ..., ge=10.0, le=300.0,
        description="Usable battery capacity in kWh (10 - 300)"
    )
    number_of_cells: int = Field(
        ..., ge=1, le=10000,
        description="Total number of battery cells (1 - 10000)"
    )
    torque_nm: float = Field(
        ..., ge=50.0, le=3000.0,
        description="Motor torque in Nm (50 - 3000)"
    )
    efficiency_wh_per_km: float = Field(
        ..., ge=50.0, le=500.0,
        description="Energy consumption in Wh/km (50 - 500)"
    )
    acceleration_0_100_s: float = Field(
        ..., ge=1.0, le=30.0,
        description="0-100 km/h acceleration time in seconds (1 - 30)"
    )
    fast_charging_power_kw_dc: float = Field(
        ..., ge=0.0, le=1000.0,
        description="DC fast charging power in kW (0 - 1000)"
    )
    towing_capacity_kg: float = Field(
        ..., ge=0.0, le=5000.0,
        description="Towing capacity in kg (0 - 5000)"
    )
    seats: int = Field(
        ..., ge=1, le=9,
        description="Number of seats (1 - 9)"
    )
    length_mm: float = Field(
        ..., ge=2000.0, le=7000.0,
        description="Vehicle length in mm (2000 - 7000)"
    )
    width_mm: float = Field(
        ..., ge=1400.0, le=3000.0,
        description="Vehicle width in mm (1400 - 3000)"
    )
    height_mm: float = Field(
        ..., ge=1000.0, le=3000.0,
        description="Vehicle height in mm (1000 - 3000)"
    )

    @validator("seats")
    def seats_reasonable(cls, v):
        if v < 1 or v > 9:
            raise ValueError("Seats must be between 1 and 9")
        return v

    @validator("number_of_cells")
    def cells_reasonable(cls, v):
        if v < 1:
            raise ValueError("Number of cells must be at least 1")
        return v


class PredictionResponse(BaseModel):
    predicted_range_km: float
    model_used: str
    status: str


#  Root
@app.get("/", tags=["Status"])
async def root():
    return {
        "message": "EV Battery Range Predictor API is running",
        "docs": "/docs",
        "predict": "POST /predict",
    }


# Health Check
@app.get("/health", tags=["Status"])
async def health():
    return {
        "status": "online",
        "model": type(model).__name__,
        "features": feat_names,
        "num_features": len(feat_names),
    }


# Prediction Endpoint
@app.post("/predict", response_model=PredictionResponse, tags=["Prediction"])
async def predict_range(ev: EVInput):
    try:
        row = pd.DataFrame([{
            "top_speed_kmh":           ev.top_speed_kmh,
            "battery_capacity_kwh":    ev.battery_capacity_kwh,
            "number_of_cells":         ev.number_of_cells,
            "torque_nm":               ev.torque_nm,
            "efficiency_wh_per_km":    ev.efficiency_wh_per_km,
            "acceleration_0_100_s":    ev.acceleration_0_100_s,
            "fast_charging_power_kw_dc": ev.fast_charging_power_kw_dc,
            "towing_capacity_kg":      ev.towing_capacity_kg,
            "seats":                   ev.seats,
            "length_mm":               ev.length_mm,
            "width_mm":                ev.width_mm,
            "height_mm":               ev.height_mm,
        }])[feat_names]

        scaled     = scaler.transform(row)
        prediction = float(model.predict(scaled)[0])

        return PredictionResponse(
            predicted_range_km=round(prediction, 2),
            model_used=type(model).__name__,
            status="success",
        )

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# Retraining Endpoint
def retrain_pipeline(csv_bytes: bytes):
    df = pd.read_csv(io.StringIO(csv_bytes.decode("utf-8")))

    df.columns = [c.strip().lower().replace(" ", "_") for c in df.columns]

    for col in df.select_dtypes(include="number").columns:
        df[col].fillna(df[col].median(), inplace=True)

    TARGET   = "electric_range_km"
    FEATURES = [c for c in df.select_dtypes(include="number").columns
                if c != TARGET]

    X_new = df[FEATURES]
    y_new = df[TARGET]

    X_tr, X_te, y_tr, y_te = train_test_split(
        X_new, y_new, test_size=0.2, random_state=42
    )

    sc_new  = StandardScaler()
    X_tr_sc = sc_new.fit_transform(X_tr)

    new_model = RandomForestRegressor(
        n_estimators=200, random_state=42, n_jobs=-1
    )
    new_model.fit(X_tr_sc, y_tr)

    joblib.dump(new_model, os.path.join(BASE, "models/best_model.pkl"))
    joblib.dump(sc_new,    os.path.join(BASE, "models/scaler.pkl"))
    joblib.dump(FEATURES,  os.path.join(BASE, "models/feature_names.pkl"))

    load_artifacts()
    print("[RETRAIN] Model updated successfully.")


@app.post("/retrain", tags=["Admin"])
async def retrain(
    background_tasks: BackgroundTasks,
    file: UploadFile = File(...),
):
    if not file.filename.endswith(".csv"):
        raise HTTPException(status_code=400, detail="Only CSV files are accepted.")
    contents = await file.read()
    background_tasks.add_task(retrain_pipeline, contents)
    return {
        "status": "Retraining started in background",
        "file": file.filename,
        "message": "Next /predict call will use the updated model once done.",
    }