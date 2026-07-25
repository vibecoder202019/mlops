#!/usr/bin/env bash
# Install ArgoCD on Docker Desktop Kubernetes (macOS)
set -euo pipefail

echo "=== Install ArgoCD — Docker Desktop K8s ==="

kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "Waiting for ArgoCD server..."
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s || true

PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' 2>/dev/null | base64 -d || echo "N/A")

echo ""
echo "=== ArgoCD ready ==="
echo "Port-forward:"
echo "  kubectl port-forward svc/argocd-server -n argocd 8443:443"
echo ""
echo "UI: https://localhost:8443"
echo "User: admin"
echo "Password: $PASS"
