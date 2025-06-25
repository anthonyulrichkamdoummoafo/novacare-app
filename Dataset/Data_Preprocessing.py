from sklearn.preprocessing import LabelEncoder
import pandas as pd

df = pd.read_csv("Training_with_Urgency.csv")

disease_encoder = LabelEncoder()
urgency_encoder = LabelEncoder()

df['Disease'] = disease_encoder.fit_transform(df['Disease'])
df['Urgency_Level'] = urgency_encoder.fit_transform(df['Urgency_Level'])

X = df.drop(['Disease', 'Urgency_Level'], axis=1)
y = df[['Disease', 'Urgency_Level']]

print("Feature shape:", X.shape)
print("Label shape:", y.shape)
print("Diseases:", disease_encoder.classes_)
print("Urgency Levels:", urgency_encoder.classes_)
