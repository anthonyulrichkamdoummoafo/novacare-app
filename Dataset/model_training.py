from sklearn.ensemble import RandomForestClassifier
from sklearn.multioutput import MultiOutputClassifier
from sklearn.model_selection import train_test_split
import joblib
import pandas as pd

# Load and preprocess dataset
df = pd.read_csv("models/Training_with_Urgency.csv")
X = df.drop(['Disease', 'Urgency_Level'], axis=1)
y = df[['Disease', 'Urgency_Level']]  # 2-column y

# Encode both targets
from sklearn.preprocessing import LabelEncoder
disease_encoder = LabelEncoder()
urgency_encoder = LabelEncoder()

y_encoded = pd.DataFrame({
    'Disease': disease_encoder.fit_transform(y['Disease']),
    'Urgency': urgency_encoder.fit_transform(y['Urgency_Level'])
})

# Train/test split
X_train, X_test, y_train, y_test = train_test_split(X, y_encoded, test_size=0.2, random_state=42)

# Train model
base_model = RandomForestClassifier()
model = MultiOutputClassifier(base_model)
model.fit(X_train, y_train)

# Save model and encoders
joblib.dump(model, "models/disease_urgency_model.pkl")
joblib.dump(disease_encoder, "models/disease_encoder.pkl")
joblib.dump(urgency_encoder, "models/urgency_encoder.pkl")
