"""
Train the disease + urgency prediction model.

Fixes vs. the previous version:
- The old script did a naive random train_test_split() on a dataset where
  4,609 of 4,920 rows are exact duplicates (only 304 unique symptom
  patterns exist, each repeated ~16x). A random split leaks duplicates
  across train/test, so any accuracy reported from that split is
  meaningless (it measured memorization, not generalization) - a test run
  showed 100% accuracy that way, entirely from leakage.
- This version splits by unique symptom pattern first, so no pattern's
  duplicates can appear in both train and test. It also fixes
  RandomForestClassifier's missing random_state (previously results
  weren't reproducible between reruns) and prints real metrics instead of
  training silently with no evaluation step at all.
- Finally validates against Testing.csv, a genuinely independent
  hand-built set (one row per disease) that was never part of training.
"""
from sklearn.ensemble import RandomForestClassifier
from sklearn.multioutput import MultiOutputClassifier
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder
from sklearn.metrics import accuracy_score, classification_report
import joblib
import pandas as pd

RANDOM_STATE = 42

# Load and preprocess dataset
df = pd.read_csv("models/Training_with_Urgency.csv")
symptom_cols = [c for c in df.columns if c not in ("Disease", "Urgency_Level")]

# Encode both targets
disease_encoder = LabelEncoder()
urgency_encoder = LabelEncoder()
df["Disease_enc"] = disease_encoder.fit_transform(df["Disease"])
df["Urgency_enc"] = urgency_encoder.fit_transform(df["Urgency_Level"])

# Leak-free split: group rows by their unique symptom pattern so duplicates
# of the same pattern always land entirely in train or entirely in test.
df["_pattern_id"] = df[symptom_cols].astype(str).agg("-".join, axis=1)
unique_patterns = df[["_pattern_id", "Disease"]].drop_duplicates("_pattern_id")
train_patterns, test_patterns = train_test_split(
    unique_patterns["_pattern_id"],
    test_size=0.2,
    random_state=RANDOM_STATE,
    stratify=unique_patterns["Disease"],
)
train_df = df[df["_pattern_id"].isin(train_patterns)]
test_df = df[df["_pattern_id"].isin(test_patterns)]

X_train = train_df[symptom_cols]
y_train = train_df[["Disease_enc", "Urgency_enc"]]
X_test = test_df[symptom_cols]
y_test = test_df[["Disease_enc", "Urgency_enc"]]

# Train model
base_model = RandomForestClassifier(random_state=RANDOM_STATE)
model = MultiOutputClassifier(base_model)
model.fit(X_train, y_train)

# Honest evaluation - no duplicate leakage between train and test
preds = model.predict(X_test)
disease_acc = accuracy_score(y_test["Disease_enc"], preds[:, 0])
urgency_acc = accuracy_score(y_test["Urgency_enc"], preds[:, 1])
print(f"Leak-free held-out accuracy - Disease: {disease_acc:.4f}, Urgency: {urgency_acc:.4f}")
print()
print("Disease classification report (held-out, leak-free):")
print(classification_report(
    y_test["Disease_enc"], preds[:, 0],
    labels=sorted(set(y_test["Disease_enc"])),
    target_names=disease_encoder.inverse_transform(sorted(set(y_test["Disease_enc"]))),
    zero_division=0,
))

# Independent validation against Testing.csv (never touched during training)
try:
    ext_test = pd.read_csv("Testing.csv")
    ext_X = ext_test[symptom_cols]
    ext_y_true = ext_test["prognosis"]
    ext_preds = disease_encoder.inverse_transform(model.predict(ext_X)[:, 0])
    ext_acc = accuracy_score(ext_y_true, ext_preds)
    print(f"Independent Testing.csv accuracy: {ext_acc:.4f} ({sum(ext_preds==ext_y_true)}/{len(ext_y_true)})")
    mismatches = [(a, b) for a, b in zip(ext_preds, ext_y_true) if a != b]
    if mismatches:
        print("Mismatches (predicted, actual):", mismatches)
except FileNotFoundError:
    print("Testing.csv not found next to this script - skipped independent validation.")

# Save model and encoders
joblib.dump(model, "models/disease_urgency_model.pkl")
joblib.dump(disease_encoder, "models/disease_encoder.pkl")
joblib.dump(urgency_encoder, "models/urgency_encoder.pkl")
print("\nSaved models/disease_urgency_model.pkl, disease_encoder.pkl, urgency_encoder.pkl")
