#!/usr/bin/env bash
set -euo pipefail

MLOPS_ROOT="${MLOPS_ROOT:-$HOME/mlops}"
LAB_DIR="$MLOPS_ROOT/labs/lab01"

echo "=== Deploy Lab 1 — K3s on EC2 ==="
cd "$LAB_DIR"

source .venv/bin/activate 2>/dev/null || {
  python3 -m venv .venv && source .venv/bin/activate
  pip install -q -r requirements.txt
}
python train.py
docker build -t iris-classifier:1.0.0 .

kubectl create namespace mlops --dry-run=client -o yaml | kubectl apply -f -
kubectl label namespace mlops istio-injection=enabled --overwrite 2>/dev/null || true

kubectl apply -n mlops -f k8s/deployment.yaml -f k8s/service.yaml

if [ -d k8s/istio ]; then
  kubectl apply -n mlops -f k8s/istio/gateway.yaml \
    -f k8s/istio/destinationrule.yaml \
    -f k8s/istio/virtualservice.yaml 2>/dev/null || true
fi

kubectl rollout status deployment/iris-classifier -n mlops --timeout=120s

NODEPORT=$(kubectl get svc istio-ingressgateway -n istio-system \
  -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}' 2>/dev/null || echo "30080")

PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
echo "Lab 1 K3s deployed"
echo "Test: curl -H 'Host: iris.lab.local' http://${PUBLIC_IP}:${NODEPORT}/health"
