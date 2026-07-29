#!/usr/bin/env bash
# =============================================================================
# Script: 04-deploy-awx-instance.sh
# Mục đích: Tạo AWX instance (Custom Resource) — Operator sẽ tự deploy AWX stack
# Cách chạy: ./scripts/04-deploy-awx-instance.sh
# Thời gian: ~10-15 phút (PostgreSQL init lâu)
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
AWX_DIR="$REPO_ROOT/awx"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${BLUE}[INFO]${NC} $1"; }
ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WAIT]${NC} $1"; }

echo "============================================"
echo " Triển khai AWX Instance"
echo "============================================"

# Kiểm tra Operator đang chạy
if ! kubectl get pods -l app.kubernetes.io/name=awx-operator -n awx &>/dev/null; then
  echo "AWX Operator chưa cài — chạy trước: ./scripts/03-deploy-awx-operator.sh"
  exit 1
fi

# --- Apply AWX Custom Resource ---
log "Apply AWX Custom Resource..."
kubectl apply -f "$AWX_DIR/awx-instance.yaml"

# --- Apply Ingress ---
log "Apply Ingress cho AWX..."
kubectl apply -f "$AWX_DIR/ingress.yaml"

warn "AWX đang khởi tạo — có thể mất 10-15 phút..."
echo "Theo dõi tiến trình: watch kubectl get pods -n awx"
echo ""

# Chờ awx-web pod Ready (timeout dài vì PostgreSQL init)
log "Chờ awx-web pod Ready (timeout 900s = 15 phút)..."
if kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=awx-web \
  -n awx --timeout=900s 2>/dev/null; then
  ok "AWX web pod đang Running"
else
  warn "Timeout — AWX có thể vẫn đang khởi tạo. Kiểm tra:"
  echo "  kubectl get pods -n awx"
  echo "  kubectl logs -l app.kubernetes.io/name=awx-web -n awx"
fi

# --- Lấy admin password ---
echo ""
log "Lấy mật khẩu admin AWX..."
# Chờ secret được tạo
sleep 5
if kubectl get secret awx-admin-password -n awx &>/dev/null; then
  ADMIN_PASS=$(kubectl get secret awx-admin-password -n awx \
    -o jsonpath='{.data.password}' | base64 -d)
  ok "Admin password: $ADMIN_PASS"
else
  warn "Secret awx-admin-password chưa sẵn sàng — thử lại sau vài phút:"
  echo "  kubectl get secret awx-admin-password -n awx -o jsonpath='{.data.password}' | base64 -d"
fi

echo ""
echo "============================================"
ok "AWX instance đã được tạo!"
echo ""
echo "Truy cập:"
echo "  Web UI : http://awx.local"
echo "  User   : admin"
echo "  Pass   : (xem ở trên hoặc lệnh kubectl ở trên)"
echo ""
echo "Port-forward (nếu Ingress chưa hoạt động):"
echo "  kubectl port-forward svc/awx-service 8052:80 -n awx"
echo "  → http://localhost:8052"
echo ""
echo "Tiếp theo: ./scripts/05-verify-all.sh"
echo "============================================"

kubectl get pods -n awx
