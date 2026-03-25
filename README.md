
**EVision**: *Electric Vehicle Range Prediction*

**Mission & Problem**

My mission is to advance sustainable transportation by providing insights that improve EV adoption, optimize energy efficiency, and reduce greenhouse gas emissions globally.
EV users often struggle to know how far they can drive due to the variation in battery capacity, motor power, aerodynamics, and vehicle weight. Fleet operators need accurate range predictions for trip planning, route optimization, and energy-efficient operations. This project addresses the electric range prediction problem using regression analysis on technical EV specifications.

**Dataset**

Name: Electric Car Performance and Battery Dataset

Source: Kaggle

URL: https://www.kaggle.com/datasets/afnansaifafnan/electric-car-performance-and-battery-dataset


Dataset Overview:

478 rows, 22 columns including battery specs, range, motor torque, efficiency, dimensions, and drivetrain type.

Rich variety of numeric and categorical features, suitable for regression modeling.

Contains missing values, handled via imputation, and duplicate-free.

**Data Visualization & Interpretation**


Correlation Heatmap – Shows which features strongly influence electric range.

Battery capacity (battery_capacity_kwh) and efficiency (efficiency_wh_per_km) have the highest correlations.

Vehicle dimensions and torque show moderate correlation.

**Feature Distributions and  Scatterplots**


battery_capacity_kwh vs electric_range_km scatter shows a positive linear trend.

efficiency_wh_per_km vs electric_range_km scatter shows negative correlation as expected.

The visualizations informed feature selection and scaling, ensuring the regression model captures key drivers of range.

**Model Implementation**


Three regression models were implemented:

**Linear Regression** (Gradient Descent + scikit-learn)

Final RMSE: 24.23 km

R²: 0.9445

Interpreted coefficients for features like battery capacity, vehicle height, and efficiency.

**Decision Tree Regressor**

Final RMSE: 22.29 km

R²: 0.9530

Feature importance shows battery_capacity_kwh dominates (~84% influence).

**Random Forest Regressor**


Final RMSE: 24.88 km

R²: 0.9415

**Top features:** battery capacity, fast charging power, top speed.


**Best Model:** Decision Tree Regressor (lowest RMSE).


**Model Saving & Single Prediction**

Best model saved as: models/best_model.pkl

Scaler saved as: models/scaler.pkl

Feature names saved as: models/feature_names.pkl


**README.md From the second task till the end**

# ⚡ Electric Vehicle Battery Range Prediction

This project predicts the electric driving range (km) of electric vehicles from their
technical specifications using machine learning. Accurate range estimation reduces
consumer range anxiety and supports data-driven decisions for fleet operators and EV buyers.
Three regression models were trained and compared; the best-performing model is deployed
via a FastAPI REST API and consumed by a Flutter mobile application.

---

## Dataset
- **Name:** Electric Car Performance and Battery Dataset
- **Source:** Kaggle
- **Link:** https://www.kaggle.com/datasets/afnansaifafnan/electric-car-performance-and-battery-dataset
- **Size:** 478 rows, 22 columns including battery specs, range, motor torque, efficiency, dimensions, and drivetrain type.
- **Target Variable:** `electric_range_km` — continuous float (regression task)
- **Features:** top_speed_kmh, battery_capacity_kwh, number_of_cells, torque_nm,
  efficiency_wh_per_km, acceleration_0_100_s, fast_charging_power_kw_dc,
  towing_capacity_kg, seats, length_mm, width_mm, height_mm

---

## Model Performance

| Model                 | MAE (km) | RMSE (km) | MSE      | R²     |
|-----------------------|----------|-----------|----------|--------|
| Linear Regression     | 19.809   | 24.232    | 587.174  | 0.9450 |
| **Decision Tree **  | **16.427** | **22.290** | **496.842** | **0.9530** |
| Random Forest         | 18.739   | 24.878    | 618.921  | 0.9420 |

> **Best Model: Decision Tree** — selected based on lowest RMSE (22.29 km) and highest R² (0.9530).
> The Decision Tree outperformed Random Forest on this dataset because the EV specification
> features have clear decision boundaries (e.g. battery capacity thresholds, speed categories)
> that tree splits capture precisely without the averaging effect of ensemble methods.

---

## Public API
- **Base URL:** `https://linear-regression-model-3-ip44.onrender.com`
- **Swagger UI:** `https://linear-regression-model-3-ip44.onrender.com/docs`
- **Predict Endpoint:** `POST /predict`
- **Health Check:** `GET /health`

### Sample Request
```bash
curl -X POST "https://linear-regression-model-3-ip44.onrender.com/predict" \
  -H "Content-Type: application/json" \
  -d '{
    "top_speed_kmh": 250.0,
    "battery_capacity_kwh": 75.0,
    "number_of_cells": 4416,
    "torque_nm": 420.0,
    "efficiency_wh_per_km": 160.0,
    "acceleration_0_100_s": 5.0,
    "fast_charging_power_kw_dc": 250.0,
    "towing_capacity_kg": 1000.0,
    "seats": 5,
    "length_mm": 4694.0,
    "width_mm": 1849.0,
    "height_mm": 1443.0
  }'
```

### Sample Response
```json
{
  "predicted_range_km": 465.7,
  "model_used": "DecisionTreeRegressor",
  "status": "success"
}
```

---

## Repository Structure
```
linear_regression_model/
│
├── README.md
│
└── summative/
    ├── linear_regression/
    │   └── multivariate.ipynb
    │
    ├── API/
    │   ├── prediction.py
    │   ├── requirements.txt
    │   ├── runtime.txt
    │   └── models/
    │       ├── best_model.pkl
    │       ├── scaler.pkl
    │       └── feature_names.pkl
    │
    └── evision/
        ├── lib/
        │   └── main.dart
        └── pubspec.yaml
```

---

## Running the API Locally
```bash
# 1. Navigate to the API folder
cd summative/API

# 2. Create and activate a virtual environment
python -m venv venv
source venv/Scripts/activate     # Git Bash 

# 3. Install dependencies
pip install -r requirements.txt

# 4. Start the server
uvicorn prediction:app --reload --host 0.0.0.0 --port 8000

# 5. Open Swagger UI

''' https://linear-regression-model-3-ip44.onrender.com/docs'''

## Running the Flutter App

### Prerequisites
- Flutter SDK ≥ 3.0.0 installed
- Android emulator running

### Steps
```bash
# 1. Navigate to the Flutter app folder
cd summative/evision

# 2. Install dependencies
flutter pub get

# 3. Run the app
flutter run
```

### Switching between local and production API

Open `lib/main.dart` and update the `_apiUrl` constant:
```dart
// Android emulator ( this for local testing)
static const String _apiUrl = 'http://10.0.2.2:8000/predict';

// iOS simulator (local testing on ios)
static const String _apiUrl = 'http://127.0.0.1:8000/predict';

// Physical device
static const String _apiUrl = 'http://192.168.1.X:8000/predict';

// Production — Render deployment
static const String _apiUrl = 'https://linear-regression-model-3-ip44.onrender.com/predict';
```

### Input Fields (12 variables)

| Field | Type | Valid Range |
|---|---|---|
| Top Speed | float | 50 – 500 km/h |
| Battery Capacity | float | 10 – 300 kWh |
| Number of Cells | int | 1 – 10,000 |
| Torque | float | 50 – 3,000 Nm |
| Efficiency | float | 50 – 500 Wh/km |
| Acceleration 0-100 | float | 1 – 30 seconds |
| Fast Charging Power | float | 0 – 1,000 kW |
| Towing Capacity | float | 0 – 5,000 kg |
| Seats | int | 1 – 9 |
| Length | float | 2,000 – 7,000 mm |
| Width | float | 1,400 – 3,000 mm |
| Height | float | 1,000 – 3,000 mm |

---

## Video Demo


---

## API Endpoints Summary

| Method | Path | Description |
|---|---|---|
| GET | `/` | API status message |
| GET | `/health` | Health check — returns model name and feature count |
| POST | `/predict` | Predict EV range from 12 input specifications |
| POST | `/retrain` | Upload a new CSV to trigger background model retraining |
| GET | `/docs` | Swagger UI — interactive API documentation |
| GET | `/redoc` | ReDoc API documentation |
```

---

