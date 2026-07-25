# Lab 1 — Train & Serve Iris Classifier

Xem hướng dẫn chi tiết: [docs/MLOPS-AI-PLATFORM-LABS-GUIDE.md](../../docs/MLOPS-AI-PLATFORM-LABS-GUIDE.md#lab-1--train--serve-model-local)

## Quick start

```bash
cd labs/lab01
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
python train.py
python serve.py
```

API: http://localhost:8000/docs

## Docker

```bash
python train.py
docker build -t iris-classifier:1.0.0 .
docker run -d -p 8000:8000 iris-classifier:1.0.0
```

## Kubernetes (minikube)

```bash
eval $(minikube docker-env)
docker build -t iris-classifier:1.0.0 .
kubectl apply -f k8s/
curl $(minikube ip):30080/health
```

## CI/CD

Workflow: `.github/workflows/ci-lab01.yml`
