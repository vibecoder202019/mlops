# MLOps & AI Platform Engineer — Lộ Trình Học & Lab Thực Hành Hoàn Chỉnh

> **Dành cho:** DevOps/Sysadmin có nền K8s + AWS, hướng AI Platform / MLOps Engineer  
> **Thời gian:** 9–12 tháng (10–12 giờ/tuần)  
> **Mục tiêu cuối:** Vận hành pipeline ML từ training → registry → serving trên K8s/AWS, có monitoring, autoscaling, cost control và security.

---

## Mục lục

1. [Tổng quan lộ trình](#1-tổng-quan-lộ-trình)
2. [Chuẩn bị môi trường](#2-chuẩn-bị-môi-trường)
3. [Giai đoạn 1 — ML Fundamentals](#3-giai-đoạn-1--ml-fundamentals)
4. [Lab 1 — Train & Serve Model (Local)](#lab-1--train--serve-model-local)
5. [Lab 2 — GPU & AI Workload](#lab-2--gpu--ai-workload)
6. [Giai đoạn 2 — MLOps Core](#6-giai-đoạn-2--mlops-core)
7. [Lab 3 — End-to-End MLOps Pipeline](#lab-3--end-to-end-mlops-pipeline)
8. [Lab 4 — Data & Model Validation](#lab-4--data--model-validation)
9. [Giai đoạn 3 — AI Platform trên K8s/AWS](#9-giai-đoạn-3--ai-platform-trên-k8saws)
10. [Lab 5 — KServe trên EKS](#lab-5--kserve-trên-eks)
11. [Lab 6 — Kubeflow Pipeline trên EKS](#lab-6--kubeflow-pipeline-trên-eks)
12. [Lab 7 — Cost Optimization](#lab-7--cost-optimization)
13. [Giai đoạn 4 — Production AI Serving (LLM)](#13-giai-đoạn-4--production-ai-serving-llm)
14. [Lab 8 — vLLM Self-hosted LLM](#lab-8--vllm-self-hosted-llm)
15. [Lab 9 — RAG Platform Infrastructure](#lab-9--rag-platform-infrastructure)
16. [Lab 10 — Fine-tuning MLOps (Nâng cao)](#lab-10--fine-tuning-mlops-nâng-cao)
17. [Portfolio & Checklist](#17-portfolio--checklist)
18. [Certification & Tài nguyên](#18-certification--tài-nguyên)
19. [Troubleshooting](#19-troubleshooting)

---

## 1. Tổng quan lộ trình

### 1.1 Bốn giai đoạn

| Giai đoạn | Thời gian | Kiến thức cốt lõi | Labs |
|-----------|-----------|-------------------|------|
| 1. ML Fundamentals | 4–6 tuần | ML lifecycle, model format, inference | Lab 1, Lab 2 |
| 2. MLOps Core | 8–10 tuần | MLflow, DVC, CI/CD, validation | Lab 3, Lab 4 |
| 3. AI Platform K8s/AWS | 10–12 tuần | KServe, Kubeflow, GPU, cost | Lab 5, 6, 7 |
| 4. Production LLM | 8 tuần | vLLM, RAG infra, fine-tuning | Lab 8, 9, 10 |

### 1.2 Stack chính (học sâu, không lan man)

| Thành phần | Công cụ chính |
|------------|---------------|
| Language | Python 3.10+ |
| ML Framework | scikit-learn, Hugging Face |
| Experiment Tracking | MLflow |
| Data Versioning | DVC + S3 |
| Pipeline | Kubeflow Pipelines / Argo Workflows |
| Model Serving | KServe, vLLM |
| Container | Docker, ECR |
| Orchestration | Kubernetes (EKS) |
| IaC | Terraform, Helm |
| Observability | Prometheus, Grafana |
| Cloud | AWS (S3, EKS, SageMaker awareness) |

### 1.3 Ba project portfolio bắt buộc

1. **MLOps Pipeline** (Lab 3+4) — CI/CD, MLflow, DVC, validation gates
2. **KServe Production** (Lab 5) — Canary, monitoring, autoscaling
3. **LLM Serving Platform** (Lab 8+9) — vLLM, RAG infra, cost dashboard

---

## 2. Chuẩn bị môi trường

### 2.1 Tools cần cài

```bash
# macOS
brew install python@3.11 docker kubectl minikube helm terraform hey kind

# Kiểm tra
python3 --version    # >= 3.10
docker --version
kubectl version --client
aws --version
terraform --version
helm version
```

### 2.2 AWS setup

```bash
aws configure
# Tạo S3 bucket cho labs
aws s3 mb s3://mlops-labs-YOUR-NAME --region ap-southeast-1

# Budget alert (Console → Billing → Budgets → $50/month)
```

### 2.3 Local cluster

```bash
# Minikube (Lab 1-4)
minikube start --cpus=4 --memory=8192

# Kind (CI testing)
kind create cluster --name mlops-lab

# Ollama (LLM local, Mac M-series rất tốt)
brew install ollama
ollama pull llama3.2:1b
```

### 2.4 Thư mục workspace chung

```bash
mkdir -p ~/mlops-labs/{lab01,lab02,lab03,lab04,lab05,lab06,lab07,lab08,lab09,lab10}
cd ~/mlops-labs
```

---

## 3. Giai đoạn 1 — ML Fundamentals

### 3.1 Kiến thức cần nắm

#### ML Lifecycle

```
Data Collection → Preprocessing → Training → Evaluation → Registration → Deployment → Monitoring → Retrain
```

#### Khái niệm quan trọng

| Khái niệm | Giải thích |
|-----------|------------|
| **Supervised learning** | Học từ data có label (classification, regression) |
| **Train/Val/Test split** | Tránh overfitting; test set không được dùng khi train |
| **Feature** | Input của model (ví dụ: sepal_length, petal_width) |
| **Inference** | Chạy model đã train để dự đoán |
| **Batch inference** | Xử lý hàng loạt offline (cron, Spark) |
| **Online inference** | API real-time (FastAPI, KServe, vLLM) |
| **Model artifact** | File model (.joblib, .pkl, .onnx, Safetensors) |
| **Metadata** | Version, metrics, features, training date |

#### Model formats

| Format | Framework | Dùng khi |
|--------|-----------|----------|
| `.joblib` / `.pkl` | scikit-learn | Tabular ML |
| SavedModel | TensorFlow | Deep learning TF |
| ONNX | Cross-platform | Interoperability |
| Safetensors | Hugging Face | LLM, transformers |
| `.pt` / `.pth` | PyTorch | Deep learning PT |

#### Tài liệu đọc (Giai đoạn 1)

- [Google ML Crash Course](https://developers.google.com/machine-learning/crash-course)
- [Made With ML](https://madewithml.com/)
- [Google Rules of ML](https://developers.google.com/machine-learning/guides/rules-of-ml)

---

## Lab 1 — Train & Serve Model (Local)

**Thời gian:** 3–5 giờ  
**Mục tiêu:** Train model Iris → FastAPI → Docker → K8s local → load test  
**Repo:** `mlops-lab-01-iris-classifier`

### Lab 1.1 — Cấu trúc project

```bash
cd ~/mlops-labs/lab01
mkdir mlops-lab-01-iris-classifier && cd mlops-lab-01-iris-classifier
python3 -m venv .venv && source .venv/bin/activate
mkdir -p models k8s tests
```

```
mlops-lab-01-iris-classifier/
├── train.py
├── serve.py
├── requirements.txt
├── Dockerfile
├── .dockerignore
├── models/
├── k8s/
│   ├── deployment.yaml
│   └── service.yaml
├── tests/
│   └── test_api.py
└── README.md
```

### Lab 1.2 — requirements.txt

```txt
scikit-learn==1.5.2
pandas==2.2.3
joblib==1.4.2
fastapi==0.115.6
uvicorn[standard]==0.32.1
pydantic==2.10.3
httpx==0.28.1
pytest==8.3.4
```

```bash
pip install -r requirements.txt
```

### Lab 1.3 — train.py

```python
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
    print(f"Test accuracy: {accuracy:.4f}")


if __name__ == "__main__":
    main()
```

```bash
python train.py
# Kỳ vọng: accuracy ~0.9667
```

### Lab 1.4 — serve.py (FastAPI)

```python
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
```

```bash
python serve.py
curl http://localhost:8000/health
curl -X POST http://localhost:8000/predict \
  -H "Content-Type: application/json" \
  -d '{"sepal_length":5.1,"sepal_width":3.5,"petal_length":1.4,"petal_width":0.2}'
```

### Lab 1.5 — tests/test_api.py

```python
from fastapi.testclient import TestClient
from serve import app

client = TestClient(app)


def test_health():
    r = client.get("/health")
    assert r.status_code == 200
    assert r.json()["status"] == "ok"


def test_predict_setosa():
    r = client.post("/predict", json={
        "sepal_length": 5.1, "sepal_width": 3.5,
        "petal_length": 1.4, "petal_width": 0.2,
    })
    assert r.status_code == 200
    assert r.json()["prediction"] == "setosa"


def test_invalid_input():
    r = client.post("/predict", json={
        "sepal_length": -1, "sepal_width": 3.5,
        "petal_length": 1.4, "petal_width": 0.2,
    })
    assert r.status_code == 422
```

```bash
python train.py && pytest tests/ -v
```

### Lab 1.6 — Dockerfile

`.dockerignore`:
```
.venv/
__pycache__/
*.pyc
.git/
tests/
```

`Dockerfile`:
```dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY train.py serve.py ./
COPY models/ models/
EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')" || exit 1
CMD ["uvicorn", "serve:app", "--host", "0.0.0.0", "--port", "8000"]
```

```bash
python train.py
docker build -t iris-classifier:1.0.0 .
docker run -d --name iris-api -p 8000:8000 iris-classifier:1.0.0
curl http://localhost:8000/health
```

### Lab 1.7 — Kubernetes manifests

`k8s/deployment.yaml`:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: iris-classifier
  labels:
    app: iris-classifier
spec:
  replicas: 2
  selector:
    matchLabels:
      app: iris-classifier
  template:
    metadata:
      labels:
        app: iris-classifier
        version: v1.0.0
    spec:
      containers:
        - name: api
          image: iris-classifier:1.0.0
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 8000
          readinessProbe:
            httpGet:
              path: /health
              port: 8000
            initialDelaySeconds: 5
            periodSeconds: 5
          livenessProbe:
            httpGet:
              path: /health
              port: 8000
            initialDelaySeconds: 10
            periodSeconds: 10
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 500m
              memory: 256Mi
```

`k8s/service.yaml`:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: iris-classifier
spec:
  type: NodePort
  selector:
    app: iris-classifier
  ports:
    - port: 8000
      targetPort: 8000
      nodePort: 30080
```

```bash
eval $(minikube docker-env)
docker build -t iris-classifier:1.0.0 .
kubectl apply -f k8s/
kubectl get pods -w
curl $(minikube ip):30080/health
```

### Lab 1.8 — Load test

```bash
echo '{"sepal_length":5.1,"sepal_width":3.5,"petal_length":1.4,"petal_width":0.2}' > sample.json
hey -n 1000 -c 10 -m POST -H "Content-Type: application/json" -D sample.json http://localhost:8000/predict
```

Ghi vào README: Requests/sec, p50, p95, p99 latency, success rate.

### Lab 1.9 — Rollback exercise

```bash
# Sửa train.py: n_estimators=5, version="2.0.0"
python train.py
docker build -t iris-classifier:2.0.0 .
kubectl set image deployment/iris-classifier api=iris-classifier:2.0.0
kubectl rollout undo deployment/iris-classifier
kubectl rollout history deployment/iris-classifier
```

### Lab 1 — Checklist

- [ ] train.py accuracy > 0.95
- [ ] FastAPI /health, /predict, /metadata hoạt động
- [ ] pytest pass
- [ ] Docker health check OK
- [ ] 2 pods Running trên K8s
- [ ] Load test có số liệu p95
- [ ] Rollback thành công
- [ ] README có diagram + metrics

---

## Lab 2 — GPU & AI Workload

**Thời gian:** 2–3 giờ  
**Mục tiêu:** Hiểu GPU inference, VRAM, quantization, Hugging Face pipeline  
**Repo:** `mlops-lab-02-gpu-basics`

### Lab 2.1 — Kiến thức GPU cho MLOps

| Khái niệm | Giải thích |
|-----------|------------|
| **GPU vs CPU inference** | GPU song song hóa matrix ops → nhanh hơn cho DL/LLM |
| **VRAM** | Bộ nhớ GPU; model lớn cần nhiều VRAM |
| **Batch size** | Số sample xử lý cùng lúc; tăng batch → tăng throughput, tăng VRAM |
| **FP32/FP16/INT8** | Precision vs speed; quantization giảm VRAM |
| **TTFT** | Time To First Token — metric quan trọng cho LLM |
| **Tokens/sec** | Throughput LLM serving |

#### AWS GPU instances (tham khảo)

| Instance | GPU | VRAM | Dùng cho |
|----------|-----|------|----------|
| g4dn.xlarge | T4 | 16GB | Inference nhỏ, dev |
| g5.xlarge | A10G | 24GB | LLM 7B quantized |
| p4d.24xlarge | A100 | 40GB×8 | Training lớn |

### Lab 2.2 — Hugging Face pipeline (CPU local)

```bash
cd ~/mlops-labs/lab02
python3 -m venv .venv && source .venv/bin/activate
pip install transformers torch sentencepiece
```

`hf_sentiment.py`:
```python
from transformers import pipeline

classifier = pipeline("sentiment-analysis", model="distilbert-base-uncased-finetuned-sst-2-english")

texts = [
    "I love learning MLOps!",
    "This is terrible and boring.",
    "The weather is okay today.",
]

for text in texts:
    result = classifier(text)[0]
    print(f"{text!r} → {result['label']} ({result['score']:.4f})")
```

```bash
python hf_sentiment.py
```

### Lab 2.3 — So sánh CPU vs GPU (Google Colab free)

1. Mở [Google Colab](https://colab.research.google.com)
2. Runtime → Change runtime type → GPU (T4)
3. Chạy script benchmark:

```python
import time
import torch
from transformers import pipeline

device = 0 if torch.cuda.is_available() else -1
print(f"Device: {'GPU' if device == 0 else 'CPU'}")

classifier = pipeline("sentiment-analysis", device=device)
texts = ["Sample text"] * 100

start = time.time()
for t in texts:
    classifier(t)
elapsed = time.time() - start
print(f"100 inferences in {elapsed:.2f}s ({100/elapsed:.1f} req/s)")
```

Ghi lại: CPU bao nhiêu req/s, GPU bao nhiêu req/s → đưa vào README.

### Lab 2.4 — Ollama local LLM

```bash
ollama pull llama3.2:1b
ollama run llama3.2:1b "Explain MLOps in 3 sentences"
```

Test API:
```bash
curl http://localhost:11434/api/generate -d '{
  "model": "llama3.2:1b",
  "prompt": "What is model serving?",
  "stream": false
}'
```

### Lab 2.5 — Docker + GPU (nếu có NVIDIA GPU)

`docker-compose.gpu.yml`:
```yaml
services:
  ollama:
    image: ollama/ollama
    ports:
      - "11434:11434"
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]
```

### Lab 2 — Checklist

- [ ] Hiểu VRAM, batch size, quantization
- [ ] Chạy Hugging Face pipeline trên CPU
- [ ] Benchmark CPU vs GPU (Colab)
- [ ] Chạy Ollama local
- [ ] README ghi benchmark results

---

## 6. Giai đoạn 2 — MLOps Core

### 6.1 Kiến thức cần nắm

#### MLOps principles

1. **Reproducibility** — Cùng data + code + config → cùng kết quả
2. **Versioning** — Data (DVC), code (Git), model (MLflow Registry)
3. **Automation** — CI/CD train → test → deploy
4. **Monitoring** — Data drift, model drift, latency, errors
5. **Governance** — Ai approve model lên production?

#### MLflow components

| Component | Chức năng |
|-----------|-----------|
| Tracking | Log params, metrics, artifacts |
| Projects | Package code reproducible |
| Models | Model format chuẩn |
| Registry | Staging → Production lifecycle |

#### DVC (Data Version Control)

```
Git track code + DVC track data (pointer → S3)
dvc add data/train.csv
git add data/train.csv.dvc .gitignore
dvc push  # upload to S3
```

#### Pipeline trigger patterns

| Pattern | Khi nào |
|---------|---------|
| Code change | Retrain khi sửa feature engineering |
| Data change | Retrain khi DVC hash thay đổi |
| Schedule | Retrain hàng tuần/tháng |
| Manual | Approval workflow |

---

## Lab 3 — End-to-End MLOps Pipeline

**Thời gian:** 2–3 tuần  
**Mục tiêu:** MLflow + DVC + GitHub Actions + deploy EKS  
**Repo:** `mlops-lab-03-housing-price`

### Lab 3.1 — Cấu trúc project

```
mlops-lab-03-housing-price/
├── .github/workflows/mlops.yml
├── .dvc/config
├── data/
│   └── housing.csv.dvc
├── src/
│   ├── train.py
│   ├── evaluate.py
│   └── serve.py
├── dvc.yaml
├── params.yaml
├── requirements.txt
├── Dockerfile
├── helm/
│   └── housing-api/
├── tests/
└── README.md
```

### Lab 3.2 — Setup DVC + S3

```bash
cd ~/mlops-labs/lab03
mkdir mlops-lab-03-housing-price && cd mlops-lab-03-housing-price
python3 -m venv .venv && source .venv/bin/activate
pip install dvc[s3] scikit-learn pandas mlflow fastapi uvicorn pyyaml

dvc init
dvc remote add -d storage s3://mlops-labs-YOUR-NAME/dvc-storage
```

Download dataset (California Housing):
```bash
mkdir -p data
python -c "
from sklearn.datasets import fetch_california_housing
import pandas as pd
data = fetch_california_housing(as_frame=True)
data.frame.to_csv('data/housing.csv', index=False)
print('Saved data/housing.csv')
"

dvc add data/housing.csv
git init && git add . && git commit -m "init dvc"
dvc push
```

### Lab 3.3 — params.yaml

```yaml
model:
  type: RandomForestRegressor
  n_estimators: 100
  random_state: 42

data:
  test_size: 0.2

training:
  min_r2_score: 0.75   # gate: không deploy nếu dưới ngưỡng này
```

### Lab 3.4 — src/train.py

```python
import json
import yaml
import mlflow
import mlflow.sklearn
import pandas as pd
from pathlib import Path
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestRegressor
from sklearn.metrics import r2_score, mean_squared_error

params = yaml.safe_load(open("params.yaml"))
data = pd.read_csv("data/housing.csv")
X = data.drop("MedHouseVal", axis=1)
y = data["MedHouseVal"]

X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=params["data"]["test_size"], random_state=42
)

mlflow.set_experiment("housing-price")

with mlflow.start_run():
    model = RandomForestRegressor(
        n_estimators=params["model"]["n_estimators"],
        random_state=params["model"]["random_state"],
    )
    model.fit(X_train, y_train)
    preds = model.predict(X_test)
    r2 = r2_score(y_test, preds)
    rmse = mean_squared_error(y_test, preds) ** 0.5

    mlflow.log_params(params["model"])
    mlflow.log_metric("r2_score", r2)
    mlflow.log_metric("rmse", rmse)
    mlflow.sklearn.log_model(model, "model")

    metrics = {"r2_score": r2, "rmse": rmse}
    Path("metrics.json").write_text(json.dumps(metrics, indent=2))
    print(f"R2={r2:.4f}, RMSE={rmse:.4f}")
```

### Lab 3.5 — dvc.yaml (pipeline)

```yaml
stages:
  train:
    cmd: python src/train.py
    deps:
      - src/train.py
      - data/housing.csv
      - params.yaml
    params:
      - params.yaml
    outs:
      - metrics.json
    metrics:
      - metrics.json
```

```bash
dvc repro
dvc metrics show
```

### Lab 3.6 — Deploy MLflow server trên K8s

`helm/mlflow/values.yaml`:
```yaml
replicaCount: 1
image:
  repository: ghcr.io/mlflow/mlflow
  tag: v2.18.0
service:
  type: ClusterIP
  port: 5000
backendStore:
  postgres:
    enabled: false
artifactRoot: s3://mlops-labs-YOUR-NAME/mlflow-artifacts
```

```bash
helm repo add community-charts https://community-charts.github.io/helm-charts
# Hoặc deploy đơn giản:
kubectl create deployment mlflow --image=ghcr.io/mlflow/mlflow:v2.18.0 \
  -- mlflow server --host 0.0.0.0 --port 5000 \
  --backend-store-uri sqlite:///mlflow.db \
  --default-artifact-root s3://mlops-labs-YOUR-NAME/mlflow-artifacts
kubectl expose deployment mlflow --port=5000
```

Set tracking URI:
```bash
export MLFLOW_TRACKING_URI=http://localhost:5000
# kubectl port-forward svc/mlflow 5000:5000
mlflow ui  # local fallback
```

### Lab 3.7 — GitHub Actions CI/CD

`.github/workflows/mlops.yml`:
```yaml
name: MLOps Pipeline

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

env:
  AWS_REGION: ap-southeast-1
  ECR_REPOSITORY: housing-price-api
  EKS_CLUSTER: mlops-lab-cluster

jobs:
  train-and-deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-python@v5
        with:
          python-version: "3.11"

      - name: Install dependencies
        run: pip install -r requirements.txt dvc[s3]

      - uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Pull data
        run: dvc pull

      - name: Run pipeline
        run: dvc repro

      - name: Check model quality gate
        run: |
          R2=$(python -c "import json; print(json.load(open('metrics.json'))['r2_score'])")
          MIN=$(python -c "import yaml; print(yaml.safe_load(open('params.yaml'))['training']['min_r2_score'])")
          python -c "import sys; r2=float('$R2'); m=float('$MIN'); sys.exit(0 if r2>=m else 1)"
          echo "Quality gate passed: R2=$R2 >= $MIN"

      - name: Run tests
        run: pytest tests/ -v

      - name: Login to ECR
        id: ecr
        uses: aws-actions/amazon-ecr-login@v2

      - name: Build and push Docker
        if: github.ref == 'refs/heads/main'
        run: |
          IMAGE=${{ steps.ecr.outputs.registry }}/${{ env.ECR_REPOSITORY }}:${{ github.sha }}
          docker build -t $IMAGE .
          docker push $IMAGE

      - name: Deploy to EKS staging
        if: github.ref == 'refs/heads/main'
        run: |
          aws eks update-kubeconfig --name ${{ env.EKS_CLUSTER }}
          kubectl set image deployment/housing-api api=${{ steps.ecr.outputs.registry }}/${{ env.ECR_REPOSITORY }}:${{ github.sha }} -n staging
          kubectl rollout status deployment/housing-api -n staging
```

### Lab 3.8 — Model Registry promotion

```python
# scripts/promote_model.py
import mlflow
from mlflow.tracking import MlflowClient

client = MlflowClient()
model_name = "housing-price-regressor"

# Register latest run
run_id = "YOUR_RUN_ID"
model_uri = f"runs:/{run_id}/model"
mv = mlflow.register_model(model_uri, model_name)

# Promote Staging → Production
client.transition_model_version_stage(model_name, mv.version, "Staging")
# Sau khi test OK:
client.transition_model_version_stage(model_name, mv.version, "Production", archive_existing_versions=True)
```

### Lab 3 — Checklist

- [ ] DVC track data trên S3
- [ ] dvc repro chạy pipeline
- [ ] MLflow log metrics + model
- [ ] GitHub Actions: train → quality gate → build → deploy
- [ ] Model Registry Staging → Production
- [ ] README có pipeline diagram

---

## Lab 4 — Data & Model Validation

**Thời gian:** 1 tuần  
**Mục tiêu:** Data validation, drift detection, quality gates  
**Repo:** mở rộng Lab 3

### Lab 4.1 — Kiến thức

| Loại | Mô tả | Tool |
|------|-------|------|
| **Data validation** | Schema, range, missing values | Great Expectations |
| **Data drift** | Input distribution thay đổi | Evidently AI |
| **Model drift** | Prediction distribution thay đổi | Evidently AI |
| **Performance drift** | Accuracy/gauge giảm | Custom monitoring |
| **Quality gate** | Block deploy nếu metric không đạt | CI script |

### Lab 4.2 — Great Expectations

```bash
pip install great_expectations
great_expectations init
```

`src/validate_data.py`:
```python
import pandas as pd
import great_expectations as gx

def validate_housing_data(path: str) -> bool:
    df = pd.read_csv(path)
    context = gx.get_context()

    suite = gx.ExpectationSuite(name="housing_suite")
    suite.add_expectation(gx.expectations.ExpectTableRowCountToBeBetween(min_value=1000))
    suite.add_expectation(gx.expectations.ExpectColumnValuesToNotBeNull(column="MedHouseVal"))
    suite.add_expectation(gx.expectations.ExpectColumnValuesToBeBetween(
        column="MedHouseVal", min_value=0, max_value=10
    ))

    batch = gx.pandas.PandasDatasource(name="pandas").read_csv(path)
    results = batch.validate(suite)
    return results.success

if __name__ == "__main__":
    ok = validate_housing_data("data/housing.csv")
    print("Validation:", "PASS" if ok else "FAIL")
    exit(0 if ok else 1)
```

Thêm vào `dvc.yaml`:
```yaml
  validate:
    cmd: python src/validate_data.py
    deps:
      - src/validate_data.py
      - data/housing.csv
```

### Lab 4.3 — Evidently drift report

```bash
pip install evidently
```

`src/drift_report.py`:
```python
import pandas as pd
from evidently.report import Report
from evidently.metric_preset import DataDriftPreset

reference = pd.read_csv("data/housing.csv")
# Giả lập production data (thêm noise)
current = reference.sample(frac=0.3, random_state=99).copy()
current["MedInc"] = current["MedInc"] * 1.5  # simulate drift

report = Report(metrics=[DataDriftPreset()])
report.run(reference_data=reference, current_data=current)
report.save_html("reports/drift_report.html")
print("Drift report saved to reports/drift_report.html")
```

### Lab 4.4 — Model quality gate (CI)

Thêm vào GitHub Actions (đã có ở Lab 3):
```yaml
      - name: Validate data
        run: python src/validate_data.py

      - name: Model quality gate
        run: |
          python -c "
          import json, sys
          m = json.load(open('metrics.json'))
          if m['r2_score'] < 0.75:
              print(f'FAIL: R2 {m[\"r2_score\"]} < 0.75')
              sys.exit(1)
          print(f'PASS: R2={m[\"r2_score\"]:.4f}')
          "
```

### Lab 4.5 — Postmortem template (bài tập viết)

Tạo `docs/postmortem-model-accuracy-drop.md`:

```markdown
# Postmortem: Model Accuracy Drop 20%

## Summary
Production housing model R2 dropped from 0.78 to 0.58 over 2 weeks.

## Timeline
- T-14d: New data source added (missing income normalization)
- T-7d: Alert triggered (prediction drift detected)
- T-0d: Rolled back to model v1.2.0

## Root Cause
Data pipeline change introduced unnormalized MedInc values.

## Action Items
1. Add Great Expectations check for MedInc range
2. Block deploy without validation stage pass
3. Add Evidently drift monitoring cron job

## Lessons Learned
- Data changes are as dangerous as model changes
- Quality gates must include data validation, not just model metrics
```

### Lab 4 — Checklist

- [ ] Great Expectations validate data
- [ ] Evidently drift report generated
- [ ] CI blocks deploy khi R2 < threshold
- [ ] Postmortem document viết xong
- [ ] dvc.yaml có stage validate

---

## 9. Giai đoạn 3 — AI Platform trên K8s/AWS

### 9.1 Kiến thức cần nắm

#### KServe architecture

```
Client → Ingress/Istio → InferenceService → Predictor (model container)
                                              → Transformer (pre/post process)
                                              → Explainer (optional)
```

#### Kubeflow components

| Component | Chức năng |
|-----------|-----------|
| Notebooks | Jupyter cho data scientist |
| Pipelines (KFP) | DAG workflow ML |
| Katib | Hyperparameter tuning |
| KServe | Model serving |

#### AWS services awareness

| Service | Dùng khi |
|---------|----------|
| SageMaker Training | Managed training, không muốn tự quản GPU |
| SageMaker Endpoint | Managed inference |
| EKS + KServe | Full control, multi-model, cost optimize |
| S3 | Artifact storage |
| IRSA | Pod access AWS không cần hardcode key |

#### GPU scheduling trên K8s

```yaml
resources:
  limits:
    nvidia.com/gpu: 1
```

Cần: NVIDIA device plugin, GPU node group (EKS).

---

## Lab 5 — KServe trên EKS

**Thời gian:** 2 tuần  
**Mục tiêu:** Deploy model với KServe, canary, HPA, monitoring  
**Repo:** `mlops-lab-05-kserve-eks`

### Lab 5.1 — Tạo EKS cluster

```bash
# Dùng eksctl
eksctl create cluster \
  --name mlops-lab-cluster \
  --region ap-southeast-1 \
  --nodes 2 \
  --node-type t3.medium \
  --with-oidc

# IRSA (best practice)
eksctl utils associate-iam-oidc-provider --cluster mlops-lab-cluster --approve
```

### Lab 5.2 — Cài KServe

```bash
kubectl apply -f https://github.com/kserve/kserve/releases/download/v0.14.0/kserve.yaml
kubectl apply -f https://github.com/kserve/kserve/releases/download/v0.14.0/kserve-cluster-resources.yaml
kubectl get pods -n kserve
```

### Lab 5.3 — Deploy InferenceService

Dùng model từ Lab 1, push lên ECR:

```bash
aws ecr create-repository --repository-name iris-classifier
ECR_URI=$(aws ecr describe-repositories --repository-names iris-classifier --query 'repositories[0].repositoryUri' --output text)
docker tag iris-classifier:1.0.0 $ECR_URI:1.0.0
aws ecr get-login-password | docker login --username AWS --password-stdin $ECR_URI
docker push $ECR_URI:1.0.0
```

`k8s/inferenceservice.yaml`:
```yaml
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: iris-classifier
  namespace: default
spec:
  predictor:
    sklearn:
      storageUri: "gs://kfserving-examples/models/sklearn/1.0/model"
    # Hoặc custom container:
    containers:
      - name: kserve-container
        image: YOUR_ECR_URI/iris-classifier:1.0.0
        ports:
          - containerPort: 8000
            protocol: TCP
        readinessProbe:
          httpGet:
            path: /health
            port: 8000
```

**Lưu ý:** KServe sklearn server dùng storageUri. Với custom FastAPI, dùng `predictor.containers` như trên hoặc chuyển sang MLflow model format.

Deploy MLflow model format (khuyến nghị):
```bash
# Export model theo MLserver format
mlflow models build-docker -m "runs:/RUN_ID/model" -n iris-mlflow
```

`inferenceservice-mlflow.yaml`:
```yaml
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: iris-sklearn
spec:
  predictor:
    model:
      modelFormat:
        name: sklearn
      storageUri: "s3://mlops-labs-YOUR-NAME/models/iris/v1"
      resources:
        requests:
          cpu: 100m
          memory: 256Mi
        limits:
          cpu: "1"
          memory: 512Mi
```

```bash
kubectl apply -f k8s/inferenceservice.yaml
kubectl get inferenceservice
kubectl get pods
```

### Lab 5.4 — Canary deployment

```yaml
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: iris-canary
spec:
  predictor:
    model:
      modelFormat:
        name: sklearn
      storageUri: "s3://mlops-labs-YOUR-NAME/models/iris/v1"
    canaryTrafficPercent: 10
    model:
      storageUri: "s3://mlops-labs-YOUR-NAME/models/iris/v2"
```

Hoặc dùng Istio VirtualService cho traffic split chi tiết hơn.

### Lab 5.5 — HPA autoscaling

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: iris-classifier-hpa
spec:
  scaleTargetRef:
    apiVersion: serving.kserve.io/v1beta1
    kind: InferenceService
    name: iris-classifier
  minReplicas: 1
  maxReplicas: 5
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
```

### Lab 5.6 — Prometheus + Grafana monitoring

Cài kube-prometheus-stack:
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install monitoring prometheus-community/kube-prometheus-stack -n monitoring --create-namespace
```

Dashboard metrics cần monitor:
- Request rate, latency p50/p95/p99
- Error rate (5xx)
- Pod CPU/Memory
- Model inference duration

Alert rule example:
```yaml
groups:
  - name: ml-serving
    rules:
      - alert: HighInferenceLatency
        expr: histogram_quantile(0.95, rate(request_duration_seconds_bucket[5m])) > 0.5
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "P95 inference latency > 500ms"
```

### Lab 5 — Checklist

- [ ] EKS cluster + IRSA
- [ ] KServe installed
- [ ] InferenceService Running
- [ ] Canary 90/10 traffic split tested
- [ ] HPA scales pods
- [ ] Grafana dashboard + alert
- [ ] README architecture diagram

---

## Lab 6 — Kubeflow Pipeline trên EKS

**Thời gian:** 2 tuần  
**Mục tiêu:** KFP pipeline train → evaluate → register → deploy  
**Repo:** `mlops-lab-06-kfp-pipeline`

### Lab 6.1 — Cài Kubeflow

```bash
# Cách nhanh: KFP standalone (nhẹ hơn full Kubeflow)
export PIPELINE_VERSION=2.4.0
kubectl apply -k "github.com/kubeflow/pipelines/manifests/kustomize/env/dev?ref=$PIPELINE_VERSION"
kubectl wait --for=condition=ready pod --all -n kubeflow --timeout=600s
kubectl port-forward -n kubeflow svc/ml-pipeline-ui 8080:80
# UI: http://localhost:8080
```

### Lab 6.2 — Pipeline code

`pipeline/housing_pipeline.py`:
```python
from kfp import dsl, compiler
from kfp.dsl import Input, Output, Dataset, Model, Metrics


@dsl.component(base_image="python:3.11-slim", packages_to_install=["pandas", "scikit-learn", "pyyaml"])
def load_and_preprocess(
    data_path: str,
    processed_data: Output[Dataset],
):
    import pandas as pd
    df = pd.read_csv(data_path)
    df.to_csv(processed_data.path + "/data.csv", index=False)


@dsl.component(base_image="python:3.11-slim", packages_to_install=["pandas", "scikit-learn"])
def train_model(
    data: Input[Dataset],
    model: Output[Model],
    metrics: Output[Metrics],
    n_estimators: int = 100,
):
    import pandas as pd
    import joblib
    from sklearn.model_selection import train_test_split
    from sklearn.ensemble import RandomForestRegressor
    from sklearn.metrics import r2_score

    df = pd.read_csv(f"{data.path}/data.csv")
    X = df.drop("MedHouseVal", axis=1)
    y = df["MedHouseVal"]
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

    clf = RandomForestRegressor(n_estimators=n_estimators, random_state=42)
    clf.fit(X_train, y_train)
    r2 = r2_score(y_test, clf.predict(X_test))

    joblib.dump(clf, model.path + "/model.joblib")
    metrics.log_metric("r2_score", r2)


@dsl.component(base_image="python:3.11-slim")
def evaluate_gate(
    metrics: Input[Metrics],
    min_r2: float = 0.75,
) -> str:
    r2 = metrics.metadata["r2_score"]
    if r2 < min_r2:
        raise ValueError(f"R2 {r2} below threshold {min_r2}")
    return "passed"


@dsl.pipeline(name="housing-training-pipeline")
def housing_pipeline(
    data_path: str = "data/housing.csv",
    n_estimators: int = 100,
    min_r2: float = 0.75,
):
    preprocess = load_and_preprocess(data_path=data_path)
    train = train_model(
        data=preprocess.outputs["processed_data"],
        n_estimators=n_estimators,
    )
    evaluate_gate(metrics=train.outputs["metrics"], min_r2=min_r2)


if __name__ == "__main__":
    compiler.Compiler().compile(housing_pipeline, "housing_pipeline.yaml")
```

```bash
pip install kfp
python pipeline/housing_pipeline.py
# Upload housing_pipeline.yaml qua KFP UI hoặc:
# kfp.Client().create_run_from_pipeline_package(...)
```

### Lab 6.3 — Parameterize & trigger

Pipeline parameters:
- `n_estimators`: 50, 100, 200
- `min_r2`: quality gate threshold
- `data_path`: DVC version path

Trigger patterns:
1. Manual qua KFP UI
2. CI upload pipeline khi merge main
3. Argo Events khi S3 object mới (data update)

### Lab 6.4 — Katib hyperparameter tuning (bonus)

```yaml
apiVersion: kubeflow.org/v1beta1
kind: Experiment
metadata:
  name: housing-hp-tuning
spec:
  algorithm:
    algorithmName: random
  objective:
    type: maximize
    objectiveMetricName: r2-score
  parameters:
    - name: n_estimators
      parameterType: int
      feasibleSpace:
        min: "50"
        max: "300"
    - name: max_depth
      parameterType: int
      feasibleSpace:
        min: "3"
        max: "20"
  trialTemplate:
    primaryContainerName: training
    trialParameters:
      - name: nEstimators
        description: Number of estimators
        reference: n_estimators
```

### Lab 6 — Checklist

- [ ] KFP UI accessible
- [ ] Pipeline compile + run success
- [ ] Quality gate blocks bad models
- [ ] Parameterized runs tested
- [ ] (Bonus) Katib experiment

---

## Lab 7 — Cost Optimization

**Thời gian:** 1 tuần  
**Mục tiêu:** Tối ưu chi phí GPU/cloud cho AI workload  
**Repo:** `mlops-lab-07-cost-optimization` (docs + scripts)

### Lab 7.1 — Kiến thức cost optimization

| Kỹ thuật | Tiết kiệm | Trade-off |
|----------|-----------|-----------|
| Spot instances (GPU) | 60–70% | Có thể bị terminate |
| Scale-to-zero (Knative/KServe) | Idle cost = 0 | Cold start latency |
| Right-sizing | 20–40% | Cần monitor metrics |
| S3 lifecycle | Storage cost | Data access delay |
| Reserved instances | 30–50% (1yr) | Commitment |
| Model quantization | GPU nhỏ hơn | Accuracy giảm nhẹ |
| Batch vs realtime | Batch rẻ hơn | Không real-time |

### Lab 7.2 — Spot GPU node group (EKS)

```bash
eksctl create nodegroup \
  --cluster mlops-lab-cluster \
  --name gpu-spot \
  --node-type g4dn.xlarge \
  --nodes 0 \
  --nodes-min 0 \
  --nodes-max 2 \
  --spot \
  --node-labels workload=gpu \
  --node-taints nvidia.com/gpu=true:NoSchedule
```

Pod spec with toleration:
```yaml
tolerations:
  - key: nvidia.com/gpu
    operator: Equal
    value: "true"
    effect: NoSchedule
nodeSelector:
  workload: gpu
```

### Lab 7.3 — Scale-to-zero với KServe + Knative

KServe mặc định dùng Knative Serving → scale to zero khi không có traffic.

Verify:
```bash
# Gửi request → pod start
# Chờ 60s không traffic → pod scale to 0
kubectl get pods -w
```

Measure cold start time → ghi vào report.

### Lab 7.4 — S3 lifecycle policy

```bash
aws s3api put-bucket-lifecycle-configuration \
  --bucket mlops-labs-YOUR-NAME \
  --lifecycle-configuration '{
    "Rules": [{
      "ID": "ArchiveOldArtifacts",
      "Status": "Enabled",
      "Filter": {"Prefix": "mlflow-artifacts/"},
      "Transitions": [
        {"Days": 30, "StorageClass": "STANDARD_IA"},
        {"Days": 90, "StorageClass": "GLACIER"}
      ]
    }]
  }'
```

### Lab 7.5 — Cost comparison report (deliverable)

Tạo `docs/cost-comparison.md`:

```markdown
# AI Inference Cost Comparison

## Scenario: 1M requests/month, model 500MB, p95 latency < 200ms

| Option | Monthly Cost (est.) | Pros | Cons |
|--------|---------------------|------|------|
| EKS + KServe (t3.medium × 2) | ~$60 | Full control | Ops overhead |
| EKS + GPU spot (g4dn.xlarge) | ~$90 (8h/day) | Fast inference | Spot interrupt |
| SageMaker Serverless | ~$120 | Zero ops | Cold start, vendor lock |
| SageMaker Real-time (ml.m5.large) | ~$150 | Stable | 24/7 cost |
| Lambda + container | ~$80 | Scale to zero | 10GB limit, cold start |

## Recommendation
- Dev/staging: KServe scale-to-zero on EKS
- Production steady traffic: EKS reserved instances
- Burst traffic: SageMaker Serverless
- LLM 7B+: g5.xlarge spot + vLLM

## My cost controls implemented
1. Spot GPU node group (min=0)
2. S3 lifecycle → IA after 30 days
3. AWS Budget alert at $50/month
4. Auto-shutdown script for lab clusters
```

### Lab 7.6 — Auto-shutdown script

`scripts/shutdown-lab.sh`:
```bash
#!/bin/bash
# Chạy cuối ngày để tránh quên tắt cluster
eksctl delete nodegroup --cluster mlops-lab-cluster --name gpu-spot --drain
echo "GPU nodes scaled to 0"
# Hoặc: eksctl delete cluster --name mlops-lab-cluster (nếu lab xong)
```

### Lab 7 — Checklist

- [ ] Spot GPU node group created
- [ ] Scale-to-zero tested (cold start measured)
- [ ] S3 lifecycle policy applied
- [ ] AWS Budget alert configured
- [ ] Cost comparison report written
- [ ] Shutdown script tested

---

## 13. Giai đoạn 4 — Production AI Serving (LLM)

### 13.1 Kiến thức LLM serving

#### Serving frameworks

| Tool | Strength | Dùng khi |
|------|----------|----------|
| **vLLM** | PagedAttention, high throughput | Production LLM standard |
| **TGI** | HuggingFace native | HF ecosystem |
| **Triton** | Multi-model, multi-framework | Mixed model types |
| **Ollama** | Local dev | Development only |
| **Ray Serve** | Complex routing | Multi-model orchestration |

#### Key metrics

| Metric | Ý nghĩa |
|--------|---------|
| TTFT | Time To First Token — user perceived latency |
| Tokens/sec | Throughput |
| Inter-token latency | Streaming smoothness |
| GPU utilization | Cost efficiency |
| Queue depth | Capacity planning |

#### Quantization levels

| Method | VRAM saving | Quality |
|--------|-------------|---------|
| FP16 | 2× | Minimal loss |
| INT8 | 4× | Small loss |
| INT4 (GPTQ/AWQ) | 8× | Moderate loss |
| GGUF (Ollama) | Variable | Good for edge |

---

## Lab 8 — vLLM Self-hosted LLM

**Thời gian:** 2 tuần  
**Mục tiêu:** Deploy vLLM trên GPU, OpenAI-compatible API, load test, autoscaling  
**Repo:** `mlops-lab-08-vllm-serving`

### Lab 8.1 — Deploy vLLM trên GPU (RunPod hoặc EKS)

**Option A — RunPod (nhanh, rẻ cho lab):**

1. Tạo account [RunPod](https://runpod.io)
2. Deploy GPU Pod: RTX 4090 hoặc A5000
3. Template: vLLM

**Option B — EKS GPU node:**

```bash
# g5.xlarge spot node
eksctl create nodegroup \
  --cluster mlops-lab-cluster \
  --name llm-gpu \
  --node-type g5.xlarge \
  --spot \
  --nodes 1 \
  --nodes-min 0 \
  --nodes-max 1
```

### Lab 8.2 — vLLM Docker

```bash
docker run --gpus all -v ~/.cache/huggingface:/root/.cache/huggingface \
  -p 8000:8000 \
  --ipc=host \
  vllm/vllm-openai:latest \
  --model meta-llama/Llama-3.2-1B-Instruct \
  --max-model-len 4096 \
  --gpu-memory-utilization 0.9
```

Test OpenAI-compatible API:
```bash
curl http://localhost:8000/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "meta-llama/Llama-3.2-1B-Instruct",
    "prompt": "Explain MLOps in 2 sentences:",
    "max_tokens": 100
  }'

curl http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "meta-llama/Llama-3.2-1B-Instruct",
    "messages": [{"role": "user", "content": "What is model serving?"}],
    "max_tokens": 150
  }'
```

### Lab 8.3 — K8s deployment

`k8s/vllm-deployment.yaml`:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: vllm-server
spec:
  replicas: 1
  selector:
    matchLabels:
      app: vllm-server
  template:
    metadata:
      labels:
        app: vllm-server
    spec:
      tolerations:
        - key: nvidia.com/gpu
          operator: Exists
          effect: NoSchedule
      containers:
        - name: vllm
          image: vllm/vllm-openai:latest
          args:
            - --model
            - meta-llama/Llama-3.2-1B-Instruct
            - --max-model-len
            - "4096"
            - --gpu-memory-utilization
            - "0.9"
          ports:
            - containerPort: 8000
          resources:
            limits:
              nvidia.com/gpu: 1
              memory: 16Gi
            requests:
              nvidia.com/gpu: 1
              memory: 8Gi
---
apiVersion: v1
kind: Service
metadata:
  name: vllm-server
spec:
  selector:
    app: vllm-server
  ports:
    - port: 8000
      targetPort: 8000
  type: LoadBalancer
```

### Lab 8.4 — Load test LLM

```bash
pip install locust

# locustfile.py
from locust import HttpUser, task, between

class LLMUser(HttpUser):
    wait_time = between(1, 3)

    @task
    def completion(self):
        self.client.post("/v1/completions", json={
            "model": "meta-llama/Llama-3.2-1B-Instruct",
            "prompt": "Hello, how are you?",
            "max_tokens": 50,
        })
```

```bash
locust -f locustfile.py --host http://VLLM_URL:8000 --users 10 --spawn-rate 2 --run-time 5m
```

Ghi metrics: TTFT, tokens/sec, error rate, GPU utilization (`nvidia-smi dmon`).

### Lab 8.5 — Rate limiting + auth

`nginx-config.yaml` (Ingress):
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: vllm-ingress
  annotations:
    nginx.ingress.kubernetes.io/limit-rps: "10"
    nginx.ingress.kubernetes.io/auth-type: basic
    nginx.ingress.kubernetes.io/auth-secret: vllm-basic-auth
spec:
  rules:
    - host: llm.lab.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: vllm-server
                port:
                  number: 8000
```

### Lab 8.6 — Logging prompts (PII redaction)

`src/log_middleware.py`:
```python
import re
import json
from datetime import datetime

EMAIL_PATTERN = re.compile(r'[\w.+-]+@[\w-]+\.[\w.-]+')
PHONE_PATTERN = re.compile(r'\b\d{10,}\b')

def redact_pii(text: str) -> str:
    text = EMAIL_PATTERN.sub("[EMAIL]", text)
    text = PHONE_PATTERN.sub("[PHONE]", text)
    return text

def log_request(prompt: str, response: str, model: str):
    entry = {
        "timestamp": datetime.utcnow().isoformat(),
        "model": model,
        "prompt": redact_pii(prompt),
        "response_length": len(response),
    }
    # Write to stdout → Fluentd → S3
    print(json.dumps(entry))
```

### Lab 8 — Checklist

- [ ] vLLM serving OpenAI-compatible API
- [ ] Chat + completion endpoints tested
- [ ] Load test: TTFT, tokens/sec recorded
- [ ] Rate limiting configured
- [ ] Prompt logging with PII redaction
- [ ] GPU utilization monitored
- [ ] README with architecture diagram

---

## Lab 9 — RAG Platform Infrastructure

**Thời gian:** 2 tuần  
**Mục tiêu:** Deploy RAG stack (embedding + vector DB + LLM) — góc Platform Engineer  
**Repo:** `mlops-lab-09-rag-platform`

### Lab 9.1 — Kiến thức RAG infrastructure

```
Documents → Ingestion Pipeline → Chunking → Embedding → Vector DB
                                                              ↓
User Query → Embedding → Retrieval → Context + Query → LLM → Answer
```

**Platform engineer responsible for:**
- Deploy & scale embedding service
- Operate vector database (backup, HA)
- LLM serving (Lab 8)
- Ingestion pipeline (Argo/KFP)
- Monitoring latency per component
- Cost tracking (tokens, embedding calls)

### Lab 9.2 — Architecture

```
                    ┌─────────────┐
                    │   Ingress   │
                    └──────┬──────┘
                           │
              ┌────────────┼────────────┐
              ▼            ▼            ▼
        ┌──────────┐ ┌──────────┐ ┌──────────┐
        │ RAG API  │ │ Embedding│ │  vLLM    │
        │ (FastAPI)│ │ Service  │ │  Server  │
        └────┬─────┘ └──────────┘ └──────────┘
             │
             ▼
        ┌──────────┐
        │  Qdrant  │  (Vector DB)
        └──────────┘
             ▲
             │
        ┌──────────┐
        │  Ingest  │  (Argo Workflow)
        │ Pipeline │
        └──────────┘
```

### Lab 9.3 — Deploy Qdrant

`helm/qdrant/values.yaml`:
```yaml
replicaCount: 1
persistence:
  enabled: true
  size: 10Gi
resources:
  requests:
    memory: 512Mi
    cpu: 250m
  limits:
    memory: 2Gi
    cpu: "1"
```

```bash
helm repo add qdrant https://qdrant.to/helm
helm install qdrant qdrant/qdrant -f helm/qdrant/values.yaml
kubectl port-forward svc/qdrant 6333:6333
```

### Lab 9.4 — Embedding service

`src/embedding_service.py`:
```python
from fastapi import FastAPI
from pydantic import BaseModel
from sentence_transformers import SentenceTransformer

app = FastAPI()
model = SentenceTransformer("all-MiniLM-L6-v2")


class EmbedRequest(BaseModel):
    texts: list[str]


class EmbedResponse(BaseModel):
    embeddings: list[list[float]]
    model: str = "all-MiniLM-L6-v2"
    dimensions: int = 384


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/embed", response_model=EmbedResponse)
def embed(request: EmbedRequest):
    vectors = model.encode(request.texts).tolist()
    return EmbedResponse(embeddings=vectors)
```

`Dockerfile.embedding`:
```dockerfile
FROM python:3.11-slim
WORKDIR /app
RUN pip install fastapi uvicorn sentence-transformers
COPY src/embedding_service.py .
CMD ["uvicorn", "embedding_service:app", "--host", "0.0.0.0", "--port", "8080"]
```

### Lab 9.5 — Ingestion pipeline (Argo Workflow)

`workflows/ingest-documents.yaml`:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: ingest-docs-
spec:
  entrypoint: ingest-pipeline
  templates:
    - name: ingest-pipeline
      steps:
        - - name: fetch-docs
            template: fetch-from-s3
        - - name: chunk-docs
            template: chunk
        - - name: embed-chunks
            template: embed
        - - name: store-vectors
            template: upsert-qdrant

    - name: fetch-from-s3
      container:
        image: amazon/aws-cli
        command: [sh, -c]
        args: ["aws s3 sync s3://mlops-labs-YOUR-NAME/documents/ /data/"]

    - name: chunk
      container:
        image: YOUR_ECR/ingestion:latest
        command: [python, chunk.py]
        args: ["--input", "/data", "--output", "/chunks"]

    - name: embed
      container:
        image: YOUR_ECR/ingestion:latest
        command: [python, embed_and_store.py]
        args: ["--chunks", "/chunks", "--qdrant-url", "http://qdrant:6333"]
```

`src/chunk.py`:
```python
import json
from pathlib import Path

def chunk_text(text: str, chunk_size: int = 512, overlap: int = 50) -> list[str]:
    chunks = []
    for i in range(0, len(text), chunk_size - overlap):
        chunks.append(text[i:i + chunk_size])
    return chunks

def main(input_dir: str, output_dir: str):
    Path(output_dir).mkdir(exist_ok=True)
    all_chunks = []
    for f in Path(input_dir).glob("**/*.txt"):
        text = f.read_text()
        for i, chunk in enumerate(chunk_text(text)):
            all_chunks.append({"source": str(f), "chunk_id": i, "text": chunk})
    Path(output_dir, "chunks.json").write_text(json.dumps(all_chunks, indent=2))
    print(f"Created {len(all_chunks)} chunks")

if __name__ == "__main__":
    import argparse
    p = argparse.ArgumentParser()
    p.add_argument("--input")
    p.add_argument("--output")
    args = p.parse_args()
    main(args.input, args.output)
```

### Lab 9.6 — RAG API (orchestration layer)

`src/rag_api.py`:
```python
import httpx
from fastapi import FastAPI
from pydantic import BaseModel
from qdrant_client import QdrantClient

app = FastAPI()
qdrant = QdrantClient(url="http://qdrant:6333")
EMBEDDING_URL = "http://embedding-service:8080"
LLM_URL = "http://vllm-server:8000"
COLLECTION = "documents"


class QueryRequest(BaseModel):
    question: str
    top_k: int = 3


class QueryResponse(BaseModel):
    answer: str
    sources: list[str]


@app.post("/query", response_model=QueryResponse)
async def query(request: QueryRequest):
    async with httpx.AsyncClient() as client:
        # 1. Embed query
        emb_resp = await client.post(f"{EMBEDDING_URL}/embed", json={"texts": [request.question]})
        query_vector = emb_resp.json()["embeddings"][0]

        # 2. Retrieve from Qdrant
        hits = qdrant.search(collection_name=COLLECTION, query_vector=query_vector, limit=request.top_k)
        context = "\n".join([h.payload["text"] for h in hits])
        sources = list(set([h.payload.get("source", "unknown") for h in hits]))

        # 3. Generate answer
        prompt = f"Context:\n{context}\n\nQuestion: {request.question}\n\nAnswer:"
        llm_resp = await client.post(f"{LLM_URL}/v1/completions", json={
            "model": "meta-llama/Llama-3.2-1B-Instruct",
            "prompt": prompt,
            "max_tokens": 300,
        })
        answer = llm_resp.json()["choices"][0]["text"]

    return QueryResponse(answer=answer.strip(), sources=sources)
```

### Lab 9.7 — Monitoring RAG components

Metrics cần track:

| Component | Metrics |
|-----------|---------|
| Embedding service | latency, requests/sec, error rate |
| Qdrant | query latency, collection size, memory |
| vLLM | TTFT, tokens/sec, queue depth |
| RAG API end-to-end | total latency, retrieval latency, generation latency |
| Cost | tokens used per team/day |

Prometheus ServiceMonitor cho từng component.

Grafana dashboard panels:
1. End-to-end query latency (p50, p95)
2. Retrieval vs generation latency breakdown
3. Token usage per hour
4. Error rate by component

### Lab 9.8 — Backup vector DB

```bash
# Qdrant snapshot
curl -X POST "http://localhost:6333/collections/documents/snapshots"

# Upload snapshot to S3
aws s3 cp snapshot/ s3://mlops-labs-YOUR-NAME/qdrant-backups/ --recursive

# CronJob backup hàng ngày
```

### Lab 9 — Checklist

- [ ] Qdrant deployed with persistence
- [ ] Embedding service running
- [ ] Ingestion pipeline (Argo) processes documents
- [ ] RAG API returns answers with sources
- [ ] End-to-end latency measured
- [ ] Grafana dashboard per component
- [ ] Vector DB backup to S3
- [ ] Cost tracking (token usage log)

---

## Lab 10 — Fine-tuning MLOps (Nâng cao)

**Thời gian:** 2 tuần  
**Mục tiêu:** LoRA fine-tune → MLflow tracking → deploy → A/B test  
**Repo:** `mlops-lab-10-finetuning`

### Lab 10.1 — Kiến thức fine-tuning cho Platform Engineer

| Khái niệm | Giải thích |
|-----------|------------|
| **Fine-tuning** | Train thêm trên data domain-specific |
| **LoRA** | Low-Rank Adaptation — train adapter nhỏ, tiết kiệm GPU |
| **Base model** | Model gốc (Llama, Mistral) |
| **Adapter** | Weights nhỏ attach vào base model |
| **Merge** | Gộp adapter vào base model để deploy |

Platform engineer lo:
- GPU provisioning cho training job
- Log experiments (MLflow)
- Register & version fine-tuned models
- Deploy base vs fine-tuned (A/B test)
- Cost tracking training hours

### Lab 10.2 — LoRA fine-tune script

```bash
pip install transformers peft trl datasets mlflow bitsandbytes accelerate
```

`src/finetune_lora.py`:
```python
import mlflow
from datasets import load_dataset
from transformers import AutoModelForCausalLM, AutoTokenizer, TrainingArguments
from peft import LoraConfig, get_peft_model
from trl import SFTTrainer

MODEL_NAME = "meta-llama/Llama-3.2-1B-Instruct"
mlflow.set_experiment("llama-finetune")

dataset = load_dataset("databricks/databricks-dolly-15k", split="train[:500]")

tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME)
tokenizer.pad_token = tokenizer.eos_token

model = AutoModelForCausalLM.from_pretrained(
    MODEL_NAME,
    load_in_4bit=True,
    device_map="auto",
)

lora_config = LoraConfig(
    r=16,
    lora_alpha=32,
    target_modules=["q_proj", "v_proj"],
    lora_dropout=0.05,
    task_type="CAUSAL_LM",
)
model = get_peft_model(model, lora_config)

training_args = TrainingArguments(
    output_dir="./output",
    num_train_epochs=1,
    per_device_train_batch_size=4,
    gradient_accumulation_steps=4,
    learning_rate=2e-4,
    logging_steps=10,
    save_steps=100,
    fp16=True,
)

with mlflow.start_run():
    mlflow.log_params({"model": MODEL_NAME, "lora_r": 16, "epochs": 1})

    trainer = SFTTrainer(
        model=model,
        train_dataset=dataset,
        args=training_args,
        tokenizer=tokenizer,
        max_seq_length=512,
    )
    trainer.train()

    model.save_pretrained("./output/lora_adapter")
    mlflow.log_artifacts("./output/lora_adapter", "adapter")
    print("Fine-tuning complete. Adapter saved.")
```

```bash
# Chạy trên GPU (RunPod hoặc g5.xlarge)
python src/finetune_lora.py
```

### Lab 10.3 — Register fine-tuned model

```python
import mlflow
from mlflow.tracking import MlflowClient

client = MlflowClient()
model_name = "llama-dolly-finetuned"

mv = mlflow.register_model("runs:/RUN_ID/adapter", model_name)
client.transition_model_version_stage(model_name, mv.version, "Staging")
```

### Lab 10.4 — Deploy base vs fine-tuned (A/B test)

```yaml
# KServe canary: 80% base, 20% fine-tuned
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: llama-ab-test
spec:
  predictor:
    canaryTrafficPercent: 20
    containers:
      - name: base-model
        image: vllm/vllm-openai:latest
        args: ["--model", "meta-llama/Llama-3.2-1B-Instruct"]
      - name: finetuned-model
        image: vllm/vllm-openai:latest
        args: ["--model", "/models/lora-merged"]
```

### Lab 10.5 — Evaluate A/B test

```python
# scripts/ab_evaluate.py
import httpx

BASE_URL = "http://llama-ab-test/v1/completions"
TEST_PROMPTS = [
    "Explain how to fine-tune a LLM using LoRA.",
    "What is Databricks Dolly dataset used for?",
]

for prompt in TEST_PROMPTS:
    for variant in ["base-model", "finetuned-model"]:
        headers = {"X-Model-Variant": variant}
        resp = httpx.post(BASE_URL, json={"prompt": prompt, "max_tokens": 200}, headers=headers)
        print(f"[{variant}] {prompt[:50]}... → {resp.json()['choices'][0]['text'][:100]}...")
```

### Lab 10.6 — Training job trên K8s (GPU job)

`k8s/training-job.yaml`:
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: lora-training
spec:
  template:
    spec:
      restartPolicy: Never
      tolerations:
        - key: nvidia.com/gpu
          operator: Exists
          effect: NoSchedule
      containers:
        - name: trainer
          image: YOUR_ECR/finetune:latest
          command: ["python", "src/finetune_lora.py"]
          resources:
            limits:
              nvidia.com/gpu: 1
              memory: 32Gi
          env:
            - name: MLFLOW_TRACKING_URI
              value: "http://mlflow:5000"
            - name: AWS_DEFAULT_REGION
              value: "ap-southeast-1"
          volumeMounts:
            - name: output
              mountPath: /output
      volumes:
        - name: output
          persistentVolumeClaim:
            claimName: training-output
```

### Lab 10 — Checklist

- [ ] LoRA fine-tune chạy thành công trên GPU
- [ ] MLflow log params + artifacts
- [ ] Model registered in MLflow Registry
- [ ] Deploy base vs fine-tuned
- [ ] A/B test evaluated
- [ ] Training Job YAML cho K8s
- [ ] Cost ghi lại: GPU hours × price

---

## 17. Portfolio & Checklist

### 17.1 Ba repo bắt buộc publish GitHub

| # | Repo | Labs | Highlights |
|---|------|------|------------|
| 1 | `mlops-pipeline-housing` | 3, 4 | DVC, MLflow, CI/CD, validation gates |
| 2 | `kserve-production` | 5, 6, 7 | Canary, monitoring, cost report |
| 3 | `llm-serving-platform` | 8, 9 | vLLM, RAG infra, cost dashboard |

### 17.2 Mỗi repo phải có

- [ ] Architecture diagram (draw.io / mermaid)
- [ ] README: problem → solution → how to run → metrics
- [ ] Terraform hoặc Helm cho IaC
- [ ] Runbook: deploy, rollback, incident response
- [ ] `.github/workflows/` CI pipeline

### 17.3 Checklist trước khi apply job

- [ ] Deploy model lên K8s với canary + rollback
- [ ] Setup MLflow tracking + model registry
- [ ] CI/CD pipeline train → deploy tự động
- [ ] Monitor: latency, error rate, data/model drift
- [ ] Deploy LLM với vLLM, đo tokens/sec
- [ ] Tính và tối ưu chi phí GPU/cloud
- [ ] IRSA + secrets management (không hardcode key)
- [ ] Viết postmortem cho incident giả định
- [ ] 3 repo public + 1–2 bài blog/kỹ thuật

### 17.4 Job titles nên nhắm

- MLOps Engineer
- AI Platform Engineer
- ML Infrastructure Engineer
- LLM Platform Engineer
- Senior DevOps Engineer (AI/ML team)

---

## 18. Certification & Tài nguyên

### 18.1 Certification (theo thứ tự ưu tiên)

| Cert | Giá trị | Ghi chú |
|------|---------|---------|
| CKA | Cao | Bắt buộc nếu chưa có |
| AWS ML Specialty | Rất cao | Phù hợp hướng này |
| AWS DevOps Pro | Trung bình | Bổ sung CI/CD |
| NVIDIA DLI — Deploying Models | Bonus | GPU serving |

### 18.2 Tài nguyên học

| Resource | URL | Giai đoạn |
|----------|-----|-----------|
| Made With ML | madewithml.com | 1, 2 |
| Full Stack Deep Learning | fullstackdeeplearning.com | 2, 4 |
| KServe docs | kserve.github.io | 3 |
| Kubeflow examples | github.com/kubeflow/examples | 3 |
| vLLM docs | docs.vllm.ai | 4 |
| MLflow docs | mlflow.org/docs | 2 |
| DVC docs | dvc.org/doc | 2 |
| AWS Workshop Studio | workshop.aws | 3 |
| Evidently AI | docs.evidentlyai.com | 2 |
| Hugging Face Course | huggingface.co/learn | 1, 4 |

### 18.3 Blog/case study nên đọc

- Uber Michelangelo (ML platform original)
- Netflix Metaflow
- Spotify ML Platform
- Google TFX (TensorFlow Extended)
- Anyscale (Ray for ML)

---

## 19. Troubleshooting

### 19.1 Lab 1 — Iris Classifier

| Lỗi | Nguyên nhân | Fix |
|-----|-------------|-----|
| `Model not found` | Chưa train | `python train.py` |
| `ImagePullBackOff` | Image không có trong cluster | `eval $(minikube docker-env)` + rebuild |
| `CrashLoopBackOff` | Model không có trong image | COPY models/ trong Dockerfile |
| Port 8000 busy | Process cũ | `lsof -i :8000` → kill |

### 19.2 Lab 3 — DVC/MLflow

| Lỗi | Fix |
|-----|-----|
| `dvc push` fail | Check AWS credentials + bucket policy |
| MLflow S3 artifact fail | IAM permission: s3:PutObject, s3:GetObject |
| `dvc repro` stale | `dvc repro -f` force rerun |

### 19.3 Lab 5 — KServe

| Lỗi | Fix |
|-----|-----|
| InferenceService not Ready | `kubectl describe inferenceservice` → check storageUri |
| S3 access denied | IRSA role + trust policy |
| Canary not splitting | Check Istio/Knative installation |

### 19.4 Lab 8 — vLLM

| Lỗi | Fix |
|-----|-----|
| OOM GPU | Giảm `--max-model-len` hoặc `--gpu-memory-utilization` |
| Model download slow | Pre-pull vào Docker image |
| Slow first request | Cold start — expected; dùng min replicas > 0 |
| `CUDA not available` | Check NVIDIA driver + device plugin |

### 19.5 Lab 9 — RAG

| Lỗi | Fix |
|-----|-----|
| Qdrant connection refused | Check service name + port-forward |
| Empty retrieval | Collection chưa có data → run ingestion |
| High latency | Profile từng component; thường LLM generation chiếm nhiều nhất |

### 19.6 Cost accidents

```bash
# LUÔN set budget alert trước khi lab
# LUÔN tắt GPU instances sau lab
# Script kiểm tra resources đang chạy:
kubectl get nodes
aws ec2 describe-instances --filters "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].{Type:InstanceType,Id:InstanceId}'
```

---

## Lịch học mẫu 90 ngày

| Tuần | Nội dung | Labs |
|------|----------|------|
| 1–2 | ML Fundamentals + Lab 1 | Lab 1 |
| 3 | GPU basics | Lab 2 |
| 4–6 | MLOps Core | Lab 3 |
| 7 | Data validation | Lab 4 |
| 8–10 | KServe on EKS | Lab 5 |
| 11–12 | Kubeflow Pipelines | Lab 6 |
| 13 | Cost optimization | Lab 7 |
| 14–16 | vLLM serving | Lab 8 |
| 17–18 | RAG platform | Lab 9 |
| 19–20 | Fine-tuning (optional) | Lab 10 |
| 21–24 | Portfolio polish + blog | All |

---

## Ghi chú cuối

- **Mỗi lab xong → push GitHub ngay** với README đầy đủ
- **Tắt AWS resources sau mỗi session** — dùng budget alert
- **Dùng AI (Cursor, ChatGPT) để tăng tốc** — nhưng phải hiểu code, không copy blindly
- **Focus depth over breadth** — 3 project sâu > 10 project nông
- **Viết blog 2–3 bài** về bài học thực tế — hiring manager đọc blog

---

*Tài liệu này được tạo cho lộ trình AI Platform / MLOps Engineer. Cập nhật: 2026.*
