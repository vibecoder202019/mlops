#!/usr/bin/env bash
# Test Istio routing for Lab 1 — Iris Classifier
set -euo pipefail

NAMESPACE="${NAMESPACE:-mlops}"
GW_HOST="${GW_HOST:-iris.lab.local}"

echo "=== Istio Lab 1 Test Suite ==="
echo "Namespace: $NAMESPACE"
echo ""

# Detect gateway URL
if command -v minikube &>/dev/null && minikube status &>/dev/null 2>&1; then
  MINIKUBE_IP=$(minikube ip)
  NODEPORT=$(kubectl get svc istio-ingressgateway -n istio-system \
    -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}' 2>/dev/null || echo "")
  if [ -n "$NODEPORT" ]; then
    GW_URL="http://${MINIKUBE_IP}:${NODEPORT}"
  fi
fi

# Fallback: port-forward
if [ -z "${GW_URL:-}" ]; then
  echo "Using port-forward to istio-ingressgateway..."
  kubectl port-forward -n istio-system svc/istio-ingressgateway 8080:80 &
  PF_PID=$!
  trap "kill $PF_PID 2>/dev/null" EXIT
  sleep 2
  GW_URL="http://localhost:8080"
fi

echo "Gateway URL: $GW_URL"
echo "Host header: $GW_HOST"
echo ""

# 1. Mesh health
echo "--- [1/7] Pod sidecar check ---"
PODS=$(kubectl get pods -n "$NAMESPACE" -l app=iris-classifier --no-headers 2>/dev/null || true)
if [ -z "$PODS" ]; then
  echo "FAIL: No iris-classifier pods in namespace $NAMESPACE"
  echo "Deploy first: kubectl apply -n $NAMESPACE -f labs/lab01/k8s/"
  exit 1
fi
echo "$PODS"
READY=$(echo "$PODS" | awk '{print $2}' | head -1)
if [[ "$READY" == 2/2* ]]; then
  echo "PASS: Sidecar injected (2/2)"
else
  echo "WARN: Expected 2/2 containers. Enable injection:"
  echo "  kubectl label namespace $NAMESPACE istio-injection=enabled --overwrite"
fi
echo ""

# 2. istioctl proxy status
echo "--- [2/7] Proxy sync ---"
if command -v istioctl &>/dev/null; then
  istioctl proxy-status 2>/dev/null | head -5 || echo "WARN: istioctl proxy-status failed"
else
  echo "SKIP: istioctl not installed"
fi
echo ""

# 3. Health via Gateway
echo "--- [3/7] GET /health via Istio Gateway ---"
HTTP_CODE=$(curl -s -o /tmp/istio-health.json -w "%{http_code}" \
  -H "Host: ${GW_HOST}" "${GW_URL}/health")
echo "HTTP $HTTP_CODE"
cat /tmp/istio-health.json
echo ""
if [ "$HTTP_CODE" != "200" ]; then
  echo "FAIL: Expected 200"
  exit 1
fi
echo "PASS"
echo ""

# 4. Predict via Gateway
echo "--- [4/7] POST /predict via Gateway ---"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SAMPLE="${SCRIPT_DIR}/../labs/lab01/sample.json"
HTTP_CODE=$(curl -s -o /tmp/istio-predict.json -w "%{http_code}" \
  -H "Host: ${GW_HOST}" \
  -H "Content-Type: application/json" \
  -X POST "${GW_URL}/predict" \
  -d @"${SAMPLE}")
echo "HTTP $HTTP_CODE"
cat /tmp/istio-predict.json
echo ""
if [ "$HTTP_CODE" != "200" ]; then
  echo "FAIL: Expected 200"
  exit 1
fi
echo "PASS"
echo ""

# 5. Metadata + version
echo "--- [5/7] GET /metadata ---"
curl -s -H "Host: ${GW_HOST}" "${GW_URL}/metadata" | python3 -m json.tool 2>/dev/null || true
echo ""

# 6. In-mesh request
echo "--- [6/7] In-mesh curl (pod → service) ---"
kubectl run istio-mesh-test-"$(date +%s)" -n "$NAMESPACE" \
  --image=curlimages/curl --restart=Never --rm -i \
  --command -- curl -sf "http://iris-classifier:8000/health" && echo "PASS: in-mesh OK" || echo "WARN: in-mesh failed"
echo ""

# 7. Response headers (istio-envoy)
echo "--- [7/7] Check Istio/Envoy headers ---"
curl -sI -H "Host: ${GW_HOST}" "${GW_URL}/health" | grep -iE "server|x-envoy" || echo "WARN: no envoy headers (may still work)"
echo ""

echo "=== All tests completed ==="
echo ""
echo "Optional — canary test (requires virtualservice-canary.yaml + v2 deployed):"
echo "  for i in \$(seq 1 20); do curl -s -H \"Host: ${GW_HOST}\" ${GW_URL}/metadata | python3 -c \"import sys,json; print(json.load(sys.stdin).get('version','?'))\"; done | sort | uniq -c"
