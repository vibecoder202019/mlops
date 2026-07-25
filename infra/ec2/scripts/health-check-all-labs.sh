#!/usr/bin/env bash
# Quick health check for all labs on EC2
set -euo pipefail

echo "=== MLOps EC2 Labs Health Check ==="
echo "Host: $(hostname)"
echo "Public IP: $(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo N/A)"
echo ""

check() {
  local name="$1" url="$2"
  if curl -sf --max-time 5 "$url" >/dev/null 2>&1; then
    echo "[PASS] $name — $url"
  else
    echo "[FAIL] $name — $url"
  fi
}

check "Lab1 Docker" "http://localhost:8000/health"
check "MLflow" "http://localhost:5000" 2>/dev/null || echo "[SKIP] MLflow — not running"
check "vLLM" "http://localhost:8000/v1/models" 2>/dev/null || echo "[SKIP] vLLM — not running or port conflict"

if command -v kubectl &>/dev/null && kubectl cluster-info &>/dev/null 2>&1; then
  echo ""
  echo "K3s pods:"
  kubectl get pods -A --field-selector=status.phase=Running 2>/dev/null | head -15
fi

nvidia-smi --query-gpu=name,memory.used,memory.total --format=csv 2>/dev/null || echo "[INFO] No GPU on this node"
