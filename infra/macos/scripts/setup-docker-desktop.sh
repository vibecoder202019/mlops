#!/usr/bin/env bash
# Setup Docker Desktop Kubernetes on macOS for MLOps labs
set -euo pipefail

echo "=== MLOps — Docker Desktop K8s Setup (macOS) ==="

# 1. Check Docker
if ! docker info &>/dev/null; then
  echo "ERROR: Docker Desktop is not running."
  echo "Open Docker Desktop app and wait until it is ready."
  exit 1
fi
echo "[OK] Docker running"

# 2. Check Kubernetes
if ! kubectl cluster-info &>/dev/null 2>&1; then
  echo "ERROR: Kubernetes not available."
  echo "Enable: Docker Desktop → Settings → Kubernetes → Enable Kubernetes"
  exit 1
fi

CTX=$(kubectl config current-context)
echo "[OK] Kubernetes context: $CTX"

if [ "$CTX" != "docker-desktop" ]; then
  echo "WARN: Expected context 'docker-desktop', got '$CTX'"
  echo "Run: kubectl config use-context docker-desktop"
fi

kubectl get nodes
echo ""

# 3. Namespace
kubectl apply -f "$(dirname "$0")/../../../labs/lab01/k8s/namespace.yaml" 2>/dev/null || \
  kubectl create namespace mlops --dry-run=client -o yaml | kubectl apply -f -

echo "[OK] Namespace mlops ready"
echo ""

# 4. Optional: Istio
read -r -p "Install Istio demo profile? [y/N] " INSTALL_ISTIO
if [[ "${INSTALL_ISTIO,,}" == "y" ]]; then
  if ! command -v istioctl &>/dev/null; then
    echo "Install istioctl: brew install istioctl"
    exit 1
  fi
  istioctl install --set profile=demo -y
  kubectl label namespace mlops istio-injection=enabled --overwrite
  echo "[OK] Istio installed"
fi

# 5. Optional: Argo Rollouts
read -r -p "Install Argo Rollouts? [y/N] " INSTALL_ROLLOUTS
if [[ "${INSTALL_ROLLOUTS,,}" == "y" ]]; then
  kubectl create namespace argo-rollouts --dry-run=client -o yaml | kubectl apply -f -
  kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml
  echo "[OK] Argo Rollouts installed"
fi

echo ""
echo "=== Setup complete ==="
echo "Next: bash infra/macos/scripts/deploy-lab01-k8s.sh"
