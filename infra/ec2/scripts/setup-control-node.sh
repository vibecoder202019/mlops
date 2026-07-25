#!/usr/bin/env bash
# Setup control node: Istio, ArgoCD, Argo Rollouts on k3s
set -euo pipefail

MLOPS_ROOT="${MLOPS_ROOT:-$HOME/mlops}"
source "${HOME}/.mlops-env" 2>/dev/null || true

echo "=== Setup K3s Platform Stack ==="

# Istio
if ! kubectl get namespace istio-system &>/dev/null; then
  curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.22.0 sh -
  sudo mv istio-1.22.0/bin/istioctl /usr/local/bin/
  istioctl install --set profile=demo -y
fi

kubectl create namespace mlops --dry-run=client -o yaml | kubectl apply -f -
kubectl label namespace mlops istio-injection=enabled --overwrite

# Argo Rollouts
kubectl create namespace argo-rollouts --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml

# ArgoCD
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "Waiting for ArgoCD..."
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s || true

echo "=== Platform stack ready ==="
echo "Istio gateway:"
kubectl get svc istio-ingressgateway -n istio-system
echo ""
echo "ArgoCD password:"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' 2>/dev/null | base64 -d; echo
echo "Port-forward: kubectl port-forward svc/argocd-server -n argocd 8080:443"
