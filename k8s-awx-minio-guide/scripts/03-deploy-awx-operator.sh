#!/usr/bin/env bash
# =============================================================================
# Script: 03-deploy-awx-operator.sh
# Mục đích: Cài AWX Operator bằng Helm vào namespace awx
# Cách chạy: ./scripts/03-deploy-awx-operator.sh
# Yêu cầu: helm đã cài (brew install helm)
# Thời gian: ~2-3 phút
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
AWX_DIR="$REPO_ROOT/awx"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${BLUE}[INFO]${NC} $1"; }
ok()  { echo -e "${GREEN}[OK]${NC} $1"; }
err() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

echo "============================================"
echo " Cài AWX Operator"
echo "============================================"

# Kiểm tra helm
command -v helm &>/dev/null || err "helm chưa cài — chạy: brew install helm"

# --- Bước 1: Namespace ---
log "Tạo namespace awx..."
kubectl apply -f "$AWX_DIR/namespace.yaml"

# --- Bước 2: Thêm Helm repo ---
# awx-operator chart được Ansible team publish lên GitHub Pages
log "Thêm Helm repository awx-operator..."
helm repo add awx-operator https://ansible.github.io/awx-operator/ 2>/dev/null || true
# helm repo update — cập nhật index chart mới nhất
helm repo update

# --- Bước 3: Cài Operator ---
# Kiểm tra xem đã cài chưa để tránh lỗi duplicate
if helm status awx-operator -n awx &>/dev/null; then
  log "AWX Operator đã cài — đang upgrade..."
  helm upgrade awx-operator awx-operator/awx-operator -n awx
else
  log "Cài AWX Operator (lần đầu)..."
  helm install awx-operator awx-operator/awx-operator \
    -n awx \
    --create-namespace
fi

# --- Bước 4: Chờ Operator pod Ready ---
log "Chờ AWX Operator pod Ready (timeout 180s)..."
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=awx-operator \
  -n awx --timeout=180s
ok "AWX Operator đang Running"

echo ""
echo "============================================"
ok "AWX Operator cài thành công!"
echo ""
echo "Tiếp theo: ./scripts/04-deploy-awx-instance.sh"
echo "============================================"

kubectl get pods -n awx
