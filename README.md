
**EVision**: *Electric Vehicle Range Prediction*

**Mission**

My mission is to advance sustainable transportation by providing insights that improve EV adoption, optimize energy efficiency, and reduce greenhouse gas emissions globally.
EV users and fleet operators face uncertainty about driving range due to variable vehicle specifications. Accurate range prediction reduces consumer range anxiety, helps plan efficient trips, and supports the global transition to clean mobility

**Dataset**

Name: Electric Car Performance and Battery Dataset

Source: Kaggle

URL: https://www.kaggle.com/datasets/afnansaifafnan/electric-car-performance-and-battery-dataset

Dataset Overview:

478 EV models, 22 columns including battery specs, range, motor torque, efficiency, dimensions, and drivetrain type.

Rich variety of numeric and categorical features, suitable for regression modeling.

Contains missing values, handled via imputation, and duplicate-free.

**Data Visualization & Interpretation**


Correlation Heatmap – Shows which features strongly influence electric range.

Battery capacity (battery_capacity_kwh) and efficiency (efficiency_wh_per_km) have the highest correlations.

Vehicle dimensions and torque show moderate correlation.

Feature Distributions and  Scatterplots

battery_capacity_kwh vs electric_range_km scatter shows a positive linear trend.

efficiency_wh_per_km vs electric_range_km scatter shows negative correlation as expected.

The visualizations informed feature selection and scaling, ensuring the regression model captures key drivers of range.

**Model Implementation**


Three regression models were implemented:

Linear Regression (Gradient Descent + scikit-learn)

Final RMSE: 24.23 km

R²: 0.9445

Interpreted coefficients for features like battery capacity, vehicle height, and efficiency.

Decision Tree Regressor

Final RMSE: 22.29 km

R²: 0.9530

Feature importance shows battery_capacity_kwh dominates (~84% influence).

Random Forest Regressor

Final RMSE: 24.88 km

R²: 0.9415

Top features: battery capacity, fast charging power, top speed.

Best Model: Decision Tree Regressor (lowest RMSE).

Model Saving & Single Prediction

Best model saved as: models/best_model.pkl

Scaler saved as: models/scaler.pkl

Feature names saved as: models/feature_names.pkl
