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

import numpy as np
import pandas as pd
import logging

def model_inference(symptom_list):
    # Create binary feature vector for symptoms
    input_vector = [1 if symptom in symptom_list else 0 for symptom in columns]
    input_df = pd.DataFrame([input_vector], columns=columns)

    # Predict [disease_id, urgency_id]
    predicted = model.predict(input_df)[0]
    urgency_pred = predicted[1]
    urgency_level = urgency_encoder.inverse_transform([urgency_pred])[0]

    # Get probabilities from disease estimator (assumed to be model.estimators_[0])
    disease_probs = model.estimators_[0].predict_proba(input_df)[0]

    # Get top 3 diseases with confidence
    top_indices = np.argsort(-disease_probs)[:3]
    top_predictions = []
    for idx in top_indices:
        disease = disease_encoder.classes_[idx]  # ✅ Correct usage
        confidence = round(float(disease_probs[idx]) * 100, 1)
        top_predictions.append({
            "disease": disease,
            "confidence": confidence,
            "urgency": urgency_level
        })

    logging.info(f"Predicted: {top_predictions}")
    return top_predictions



def extract_symptoms_from_text(user_text):
    return [symptom for symptom in columns if symptom.lower() in user_text.lower()]
