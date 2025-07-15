# predict.py
import joblib
import numpy as np
import pandas as pd

# Load the trained model and encoders
model = joblib.load("models/disease_urgency_model.pkl")
disease_encoder = joblib.load("models/disease_encoder.pkl")
urgency_encoder = joblib.load("models/urgency_encoder.pkl")

# Load symptoms list (columns) for proper input
columns = pd.read_csv("models/Training_with_Urgency.csv").drop(['Disease', 'Urgency_Level'], axis=1).columns.tolist()

# 🧠 Example: User reports these symptoms
input_symptoms = ['headache', 'nausea', 'fatigue']

# Convert to one-hot encoded input
input_data = [1 if symptom in input_symptoms else 0 for symptom in columns]
input_array = pd.DataFrame([input_data], columns=columns)

# Predict
prediction = model.predict(input_array)
predicted_disease = disease_encoder.inverse_transform([prediction[0][0]])[0]
predicted_urgency = urgency_encoder.inverse_transform([prediction[0][1]])[0]

# Output
print(f"🦠 Predicted Disease: {predicted_disease}")
print(f"⚠️ Urgency Level: {predicted_urgency}")






