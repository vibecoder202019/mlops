#!/usr/bin/env python3
"""Train placeholder model — replace with your dataset."""
import json
import joblib
from pathlib import Path
from sklearn.datasets import load_iris
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score

MODEL_DIR = Path("models")
MODEL_DIR.mkdir(exist_ok=True)

X, y = load_iris(return_X_y=True)
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
model = RandomForestClassifier(n_estimators=100, random_state=42)
model.fit(X_train, y_train)
accuracy = accuracy_score(y_test, model.predict(X_test))

joblib.dump(model, MODEL_DIR / "model.joblib")
Path("models/metadata.json").write_text(json.dumps({"version": "1.0.0", "accuracy": accuracy}, indent=2))
print(f"Model trained. Accuracy: {accuracy:.4f}")
