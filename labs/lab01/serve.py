#!/usr/bin/env python3
"""FastAPI service for Iris classification."""

import json
from pathlib import Path

import joblib
import uvicorn
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

MODEL_PATH = Path("models/model.joblib")
METADATA_PATH = Path("models/metadata.json")

app = FastAPI(title="Iris Classifier API", version="1.0.0")
model = None
metadata = {}


class PredictRequest(BaseModel):
    sepal_length: float = Field(..., ge=0, le=20, example=5.1)
    sepal_width: float = Field(..., ge=0, le=20, example=3.5)
    petal_length: float = Field(..., ge=0, le=20, example=1.4)
    petal_width: float = Field(..., ge=0, le=20, example=0.2)


class PredictResponse(BaseModel):
    prediction: str
    probabilities: dict[str, float]
    model_version: str


@app.on_event("startup")
def load_model() -> None:
    global model, metadata
    if not MODEL_PATH.exists():
        raise RuntimeError(f"Model not found at {MODEL_PATH}. Run train.py first.")
    model = joblib.load(MODEL_PATH)
    metadata = json.loads(METADATA_PATH.read_text()) if METADATA_PATH.exists() else {"version": "unknown"}


@app.get("/health")
def health():
    return {"status": "ok", "model_loaded": model is not None}


@app.get("/metadata")
def get_metadata():
    return metadata


@app.post("/predict", response_model=PredictResponse)
def predict(request: PredictRequest):
    if model is None:
        raise HTTPException(status_code=503, detail="Model not loaded")

    features = [[request.sepal_length, request.sepal_width, request.petal_length, request.petal_width]]
    pred_idx = int(model.predict(features)[0])
    proba = model.predict_proba(features)[0]
    class_names = metadata.get("target_classes", ["class_0", "class_1", "class_2"])
    probabilities = {class_names[i]: round(float(proba[i]), 4) for i in range(len(proba))}

    return PredictResponse(
        prediction=class_names[pred_idx],
        probabilities=probabilities,
        model_version=metadata.get("version", "unknown"),
    )


if __name__ == "__main__":
    uvicorn.run("serve:app", host="0.0.0.0", port=8000)
