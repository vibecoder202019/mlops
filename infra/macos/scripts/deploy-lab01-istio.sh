#!/usr/bin/env bash
# Deploy Lab 1 + Istio on Docker Desktop Kubernetes (macOS)
set -euo pipefail

MLOPS_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"

echo "=== Deploy Lab 1 + Istio — Docker Desktop ==="

# Deploy base app first
bash "$(dirname "$0")/deploy-lab01-k8s.sh"

# Istio
if ! kubectl get namespace istio-system &>/dev/null; then
  echo "Installing Istio..."
  istioctl install --set profile=demo -y
fi

kubectl label namespace mlops istio-injection=enabled --overwrite

# Restart deployment to inject sidecar
kubectl rollout restart deployment/iris-classifier -n mlops
kubectl rollout status deployment/iris-classifier -n mlops --timeout=180s

# Istio routing
kubectl apply -n mlops -f "$MLOPS_ROOT/labs/lab01/k8s/istio/gateway.yaml"
kubectl apply -n mlops -f "$MLOPS_ROOT/labs/lab01/k8s/istio/destinationrule.yaml"
kubectl apply -n mlops -f "$MLOPS_ROOT/labs/lab01/k8s/istio/virtualservice.yaml"

# /etc/hosts hint
if ! grep -q "iris.lab.local" /etc/hosts 2>/dev/null; then
  echo ""
  echo "Add to /etc/hosts (optional):"
  echo "  echo '127.0.0.1 iris.lab.local' | sudo tee -a /etc/hosts"
fi

echo ""
echo "=== Istio deployed ==="
echo "Start port-forward (keep running in separate terminal):"
echo "  kubectl port-forward -n istio-system svc/istio-ingressgateway 8080:80"
echo ""
echo "Test:"
echo "  curl -H 'Host: iris.lab.local' http://localhost:8080/health"
echo "  GW_URL=http://localhost:8080 bash scripts/test-istio-lab01.sh"
