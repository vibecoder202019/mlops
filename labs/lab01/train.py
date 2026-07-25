#!/usr/bin/env python3
"""Train Iris classifier and save model + metadata."""

import json
import joblib
from datetime import datetime, timezone
from pathlib import Path

import pandas as pd
from sklearn.datasets import load_iris
from sklearn.metrics import accuracy_score
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier

MODEL_DIR = Path("models")
MODEL_PATH = MODEL_DIR / "model.joblib"
METADATA_PATH = MODEL_DIR / "metadata.json"
FEATURE_NAMES = ["sepal_length", "sepal_width", "petal_length", "petal_width"]
TARGET_NAMES = ["setosa", "versicolor", "virginica"]


def main() -> None:
    MODEL_DIR.mkdir(exist_ok=True)

    iris = load_iris()
    X = pd.DataFrame(iris.data, columns=FEATURE_NAMES)
    y = iris.target

    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )

    model = RandomForestClassifier(n_estimators=100, random_state=42)
    model.fit(X_train, y_train)

    y_pred = model.predict(X_test)
    accuracy = float(accuracy_score(y_test, y_pred))

    joblib.dump(model, MODEL_PATH)

    metadata = {
        "model_name": "iris-random-forest",
        "version": "1.0.0",
        "trained_at": datetime.now(timezone.utc).isoformat(),
        "algorithm": "RandomForestClassifier",
        "features": FEATURE_NAMES,
        "target_classes": TARGET_NAMES,
        "metrics": {"accuracy": round(accuracy, 4)},
        "train_samples": len(X_train),
        "test_samples": len(X_test),
    }

    METADATA_PATH.write_text(json.dumps(metadata, indent=2))
    print(f"Model saved to {MODEL_PATH}")
    print(f"Metadata saved to {METADATA_PATH}")
    print(f"Test accuracy: {accuracy:.4f}")


if __name__ == "__main__":
    main()
