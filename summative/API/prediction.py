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

# App
app = FastAPI(
    title="EV Battery Range Predictor",
    description=(
        "Predicts the electric driving range (km) of electric vehicles "
        "from their technical specifications."
    ),
    version="1.0.0",
)

# CORS Middleware
# No wildcard (*) — prevents CSRF attacks from unknown origins.
# Origins explicitly list only trusted frontends.
# Methods restricted to GET and POST only.
# Headers scoped to Content-Type and Authorization.
# credentials=True safe because origins are explicitly allowlisted.

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:3000",
        "http://localhost:8080",
        "http://localhost:8000",
        "https://ev-range-predictor.onrender.com",
    ],
    allow_credentials=True,
    allow_methods=["GET", "POST"],
    allow_headers=["Content-Type", "Authorization", "Accept"],
)

# Load Model Artifacts
BASE = os.path.dirname(os.path.abspath(__file__))


def load_artifacts():
    global model, scaler, feat_names
    model      = joblib.load(os.path.join(BASE, "models/best_model.pkl"))
    scaler     = joblib.load(os.path.join(BASE, "models/scaler.pkl"))
    feat_names = joblib.load(os.path.join(BASE, "models/feature_names.pkl"))


load_artifacts()


#  Pydantic Input Schema
# Every field has:
#   1. Enforced Python datatype (float or int)
#   2. Realistic range constraint via ge= and le=
#   3. Human-readable description shown in Swagger UI

class EVInput(BaseModel):
    battery_capacity_kwh: float = Field(
        ..., ge=20.0, le=200.0,
        description="Usable battery capacity in kWh (20 – 200)"
    )
    motor_power_kw: float = Field(
        ..., ge=50.0, le=750.0,
        description="Combined motor power in kW (50 – 750)"
    )
    vehicle_weight_kg: float = Field(
        ..., ge=1200.0, le=3500.0,
        description="Kerb weight in kg (1200 – 3500)"
    )
    drag_coefficient: float = Field(
        ..., ge=0.18, le=0.45,
        description="Aerodynamic drag coefficient Cd (0.18 – 0.45)"
    )
    num_motors: int = Field(
        ..., ge=1, le=4,
        description="Number of electric motors (1 – 4)"
    )
    regen_braking: int = Field(
        ..., ge=0, le=1,
        description="Regenerative braking: 1 = Yes, 0 = No"
    )
    fast_charge_kw: float = Field(
        ..., ge=0.0, le=350.0,
        description="Max DC fast charge rate in kW (0 – 350)"
    )
    drive_AWD: int = Field(
        0, ge=0, le=1,
        description="1 if All-Wheel Drive, 0 otherwise"
    )
    drive_RWD: int = Field(
        0, ge=0, le=1,
        description="1 if Rear-Wheel Drive, 0 otherwise (FWD when both are 0)"
    )

    @validator("regen_braking", "drive_AWD", "drive_RWD")
    def must_be_binary(cls, v):
        if v not in (0, 1):
            raise ValueError("Value must be 0 or 1")
        return v

    @validator("drive_AWD")
    def not_both_awd_and_rwd(cls, v, values):
        if v == 1 and values.get("drive_RWD") == 1:
            raise ValueError("drive_AWD and drive_RWD cannot both be 1")
        return v


class PredictionResponse(BaseModel):
    predicted_range_km: float
    model_used: str
    status: str


# ── Root ──────────────────────────────────────────────────────────────────────
@app.get("/", tags=["Status"])
async def root():
    return {
        "message": "EV Battery Range Predictor API is running",
        "docs":    "/docs",
        "predict": "POST /predict",
    }


# Health Check
@app.get("/health", tags=["Status"])
async def health():
    return {
        "status":       "online",
        "model":        type(model).__name__,
        "features":     feat_names,
        "num_features": len(feat_names),
    }


# Prediction Endpoint
@app.post("/predict", response_model=PredictionResponse, tags=["Prediction"])
async def predict_range(ev: EVInput):
    try:
        # Build a single-row DataFrame in the correct feature order
        row = pd.DataFrame([{
            "battery_capacity_kwh": ev.battery_capacity_kwh,
            "motor_power_kw":       ev.motor_power_kw,
            "vehicle_weight_kg":    ev.vehicle_weight_kg,
            "drag_coefficient":     ev.drag_coefficient,
            "num_motors":           ev.num_motors,
            "regen_braking":        ev.regen_braking,
            "fast_charge_kw":       ev.fast_charge_kw,
            "drive_AWD":            ev.drive_AWD,
            "drive_RWD":            ev.drive_RWD,
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


#  Retraining Endpoint
def retrain_pipeline(csv_bytes: bytes):
    """
    Full retraining pipeline triggered by a new CSV upload.
    Runs as a background task — API stays responsive during retraining.
    """
    df = pd.read_csv(io.StringIO(csv_bytes.decode("utf-8")))

    # Standardise column names
    df.columns = [c.strip().lower().replace(" ", "_") for c in df.columns]

    # Drop leaky and non-informative columns
    drop_cols = ["model_name", "brand", "image_url",
                 "efficiency_wh_km", "city_range_km", "highway_range_km"]
    df.drop(columns=[c for c in drop_cols if c in df.columns],
            inplace=True, errors="ignore")

    # Encode regen_braking
    if "regen_braking" in df.columns:
        df["regen_braking"] = df["regen_braking"].map(
            {"Yes": 1, "No": 0, "yes": 1, "no": 0}
        ).fillna(0).astype(int)

    # One-hot encode drive_type
    if "drive_type" in df.columns:
        df = pd.get_dummies(df, columns=["drive_type"], drop_first=True)
        df.rename(
            columns={c: c.replace("drive_type_", "drive_")
                     for c in df.columns if c.startswith("drive_type_")},
            inplace=True,
        )

    # Impute nulls
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

    sc_new    = StandardScaler()
    X_tr_sc   = sc_new.fit_transform(X_tr)

    new_model = RandomForestRegressor(
        n_estimators=200, random_state=42, n_jobs=-1
    )
    new_model.fit(X_tr_sc, y_tr)

    # Overwrite saved artifacts
    joblib.dump(new_model, os.path.join(BASE, "models/best_model.pkl"))
    joblib.dump(sc_new,    os.path.join(BASE, "models/scaler.pkl"))
    joblib.dump(FEATURES,  os.path.join(BASE, "models/feature_names.pkl"))

    # Reload globals so the very next /predict uses the new model
    load_artifacts()
    print("[RETRAIN] Model updated successfully.")


@app.post("/retrain", tags=["Admin"])
async def retrain(
    background_tasks: BackgroundTasks,
    file: UploadFile = File(...),
):
    """
    Upload a new CSV to trigger background model retraining.
    The API continues serving predictions while retraining runs.
    """
    if not file.filename.endswith(".csv"):
        raise HTTPException(
            status_code=400,
            detail="Only CSV files are accepted."
        )
    contents = await file.read()
    background_tasks.add_task(retrain_pipeline, contents)
    return {
        "status":  "Retraining started in background",
        "file":    file.filename,
        "message": "Next /predict call will use the updated model once done.",
    }
```

---

