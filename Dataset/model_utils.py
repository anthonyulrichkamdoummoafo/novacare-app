import joblib
import numpy as np
import pandas as pd
import logging

logging.basicConfig(filename='logs/app.log', level=logging.INFO,
                    format='%(asctime)s:%(levelname)s:%(message)s')

# Load models and encoders
model = joblib.load("models/disease_urgency_model.pkl")
disease_encoder = joblib.load("models/disease_encoder.pkl")
urgency_encoder = joblib.load("models/urgency_encoder.pkl")
columns = pd.read_csv("models/Training_with_Urgency.csv").drop(['Disease', 'Urgency_Level'], axis=1).columns.tolist()

def model_inference(symptom_list):
    input_vector = [1 if symptom in symptom_list else 0 for symptom in columns]
    input_df = pd.DataFrame([input_vector], columns=columns)

    # Predict disease and urgency separately
    prediction = model.predict(input_df)  # shape: (1, 2)
    disease_pred, urgency_pred = prediction[0]

    # Predict disease probabilities for top 3 suggestions
    disease_proba = model.estimators_[0].predict_proba(input_df)[0]
    top_indices = np.argsort(-disease_proba)[:3]

    top_predictions = [
        {
            "disease": disease_encoder.inverse_transform([i])[0],
            "confidence": round(float(disease_proba[i]), 2)
        }
        for i in top_indices
    ]

    urgency_level = urgency_encoder.inverse_transform([urgency_pred])[0]
    logging.info(f"Top predictions: {top_predictions} | Urgency: {urgency_level}")
    return top_predictions, urgency_level


def extract_symptoms_from_text(user_text):
    return [symptom for symptom in columns if symptom.lower() in user_text.lower()]
