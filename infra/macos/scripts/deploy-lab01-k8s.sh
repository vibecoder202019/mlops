#!/usr/bin/env bash
# Deploy Lab 1 to Docker Desktop Kubernetes (macOS)
set -euo pipefail

MLOPS_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
LAB_DIR="$MLOPS_ROOT/labs/lab01"

echo "=== Deploy Lab 1 — Docker Desktop K8s ==="

# Verify context
kubectl config use-context docker-desktop 2>/dev/null || true

cd "$LAB_DIR"

# Train model
if [ ! -f models/model.joblib ]; then
  python3 -m venv .venv 2>/dev/null || true
  source .venv/bin/activate
  pip install -q -r requirements.txt
  python train.py
else
  echo "[OK] Model already exists"
fi

# Build — Docker Desktop shares daemon with K8s
echo "Building Docker image..."
docker build -t iris-classifier:1.0.0 .

# Deploy
kubectl apply -f k8s/namespace.yaml
kubectl apply -n mlops -f k8s/deployment.yaml -f k8s/service.yaml

echo "Waiting for rollout..."
kubectl rollout status deployment/iris-classifier -n mlops --timeout=120s

echo ""
echo "=== Lab 1 deployed ==="
kubectl get pods,svc -n mlops

echo ""
echo "Test:"
echo "  curl http://localhost:30080/health"
echo ""
echo "Or port-forward:"
echo "  kubectl port-forward -n mlops svc/iris-classifier 8000:8000"

# Quick test
sleep 2
if curl -sf --max-time 5 http://localhost:30080/health >/dev/null 2>&1; then
  echo ""
  curl -s http://localhost:30080/health
  echo ""
  echo "[PASS] Health check OK"
else
  echo "[INFO] NodePort not ready yet — try again in 10s or use port-forward"
fi
