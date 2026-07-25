#!/usr/bin/env bash
# Test Argo Rollouts canary deployment for Lab 1
set -euo pipefail

NAMESPACE="${NAMESPACE:-mlops}"
ROLLOUT="${ROLLOUT:-iris-classifier}"
GW_HOST="${GW_HOST:-iris.lab.local}"

echo "=== ArgoCD Canary Test Suite ==="
echo ""

# 1. Rollout exists
echo "--- [1/5] Rollout status ---"
if ! kubectl get rollout "$ROLLOUT" -n "$NAMESPACE" &>/dev/null; then
  echo "FAIL: Rollout $ROLLOUT not found in $NAMESPACE"
  exit 1
fi
kubectl argo rollouts get rollout "$ROLLOUT" -n "$NAMESPACE" 2>/dev/null || \
  kubectl get rollout "$ROLLOUT" -n "$NAMESPACE"
echo ""

# 2. ArgoCD app (optional)
echo "--- [2/5] ArgoCD Application ---"
if kubectl get application lab01-iris-canary-staging -n argocd &>/dev/null; then
  kubectl get application lab01-iris-canary-staging -n argocd \
    -o custom-columns=NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status
else
  echo "SKIP: ArgoCD app not installed"
fi
echo ""

# 3. Gateway health
echo "--- [3/5] Health via Istio Gateway ---"
if command -v minikube &>/dev/null && minikube status &>/dev/null 2>&1; then
  GW="http://$(minikube ip):$(kubectl get svc istio-ingressgateway -n istio-system \
    -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}')"
  HTTP=$(curl -s -o /dev/null -w "%{http_code}" -H "Host: $GW_HOST" "$GW/health")
  echo "HTTP $HTTP"
  [ "$HTTP" = "200" ] && echo "PASS" || echo "WARN: gateway not 200"
else
  echo "SKIP: minikube not running"
fi
echo ""

# 4. In-cluster health
echo "--- [4/5] In-cluster service health ---"
kubectl run argocd-canary-test-$(date +%s) -n "$NAMESPACE" \
  --image=curlimages/curl --restart=Never --rm -i \
  --command -- curl -sf "http://iris-classifier:8000/health" && echo "PASS" || echo "FAIL"
echo ""

# 5. Rollout revision
echo "--- [5/5] Rollout revision info ---"
kubectl argo rollouts history rollout/"$ROLLOUT" -n "$NAMESPACE" 2>/dev/null || true
echo ""
echo "=== Done ==="
echo "Promote: kubectl argo rollouts promote rollout/$ROLLOUT -n $NAMESPACE"
echo "Rollback: kubectl argo rollouts undo rollout/$ROLLOUT -n $NAMESPACE"
