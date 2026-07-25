#!/usr/bin/env bash
# Setup control node: Istio, ArgoCD, Argo Rollouts on k3s
set -euo pipefail

MLOPS_ROOT="${MLOPS_ROOT:-$HOME/mlops}"
source "${HOME}/.mlops-env" 2>/dev/null || true

ARGOCD_MANIFEST="https://raw.githubusercontent.com/argoproj/argo-cd/v2.13.3/manifests/install.yaml"
ARGO_ROLLOUTS_MANIFEST="https://github.com/argoproj/argo-rollouts/releases/download/v1.7.2/install.yaml"
ISTIO_VERSION="1.22.0"

echo "=== Setup K3s Platform Stack ==="

if ! kubectl cluster-info &>/dev/null; then
  echo "ERROR: kubectl cannot reach cluster. Is k3s running? (sudo systemctl status k3s)"
  exit 1
fi

# Istio
if ! kubectl get namespace istio-system &>/dev/null; then
  echo "Installing Istio ${ISTIO_VERSION}..."
  ISTIO_TMP=$(mktemp -d)
  (
    cd "${ISTIO_TMP}"
    curl -fsSL https://istio.io/downloadIstio | ISTIO_VERSION="${ISTIO_VERSION}" sh -
    sudo mv "istio-${ISTIO_VERSION}/bin/istioctl" /usr/local/bin/istioctl
  )
  rm -rf "${ISTIO_TMP}"
  istioctl install --set profile=demo -y \
    --set values.gateways.istio-ingressgateway.service.type=NodePort \
    --set values.gateways.istio-ingressgateway.service.ports[1].nodePort=30080
else
  echo "Istio already installed, skipping."
fi

kubectl create namespace mlops --dry-run=client -o yaml | kubectl apply -f -
kubectl label namespace mlops istio-injection=enabled --overwrite

# Argo Rollouts
kubectl create namespace argo-rollouts --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argo-rollouts -f "${ARGO_ROLLOUTS_MANIFEST}"

# ArgoCD — server-side apply avoids CRD "metadata.annotations: Too long" on kubectl apply
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply --server-side --force-conflicts -n argocd -f "${ARGOCD_MANIFEST}"

echo "Waiting for ArgoCD..."
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s || true

echo "=== Platform stack ready ==="
echo "Istio gateway:"
kubectl get svc istio-ingressgateway -n istio-system
NODEPORT=$(kubectl get svc istio-ingressgateway -n istio-system \
  -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}' 2>/dev/null || echo "unknown")
PUBLIC_IP=$(curl -sf http://169.254.169.254/latest/meta-data/public-ipv4 || echo "EC2_PUBLIC_IP")
echo ""
echo "Istio HTTP NodePort: ${NODEPORT}"
echo "Test: curl -H 'Host: iris.lab.local' http://${PUBLIC_IP}:${NODEPORT}/health"
echo ""
echo "ArgoCD password:"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' 2>/dev/null | base64 -d; echo
echo "Port-forward: kubectl port-forward svc/argocd-server -n argocd 8080:443"
