#!/usr/bin/env bash
# =============================================================================
# Script: 05-verify-all.sh
# Mục đích: Kiểm tra MinIO và AWX đã chạy đúng
# Cách chạy: ./scripts/05-verify-all.sh
# =============================================================================

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

pass() { echo -e "${GREEN}✅${NC} $1"; }
fail() { echo -e "${RED}❌${NC} $1"; }
info() { echo -e "${BLUE}ℹ️ ${NC} $1"; }

echo "============================================"
echo " Kiểm tra MinIO + AWX"
echo "============================================"
echo ""

# --- MinIO checks ---
info "Kiểm tra MinIO..."

if kubectl get namespace minio &>/dev/null; then
  pass "Namespace minio tồn tại"
else
  fail "Namespace minio không tồn tại — chạy ./scripts/02-deploy-minio.sh"
fi

MINIO_POD=$(kubectl get pods -l app=minio -n minio \
  -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "NotFound")
if [ "$MINIO_POD" = "Running" ]; then
  pass "MinIO pod Running"
else
  fail "MinIO pod: $MINIO_POD"
fi

PVC_STATUS=$(kubectl get pvc minio-data -n minio \
  -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")
if [ "$PVC_STATUS" = "Bound" ]; then
  pass "MinIO PVC Bound"
else
  fail "MinIO PVC: $PVC_STATUS"
fi

# Health check qua kubectl exec
if kubectl exec -n minio deploy/minio -- \
  curl -sf http://localhost:9000/minio/health/live &>/dev/null; then
  pass "MinIO health check OK"
else
  fail "MinIO health check failed"
fi

echo ""

# --- AWX checks ---
info "Kiểm tra AWX..."

if kubectl get namespace awx &>/dev/null; then
  pass "Namespace awx tồn tại"
else
  fail "Namespace awx không tồn tại"
fi

AWX_WEB=$(kubectl get pods -l app.kubernetes.io/name=awx-web -n awx \
  -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "NotFound")
if [ "$AWX_WEB" = "Running" ]; then
  pass "AWX web pod Running"
else
  fail "AWX web pod: $AWX_WEB (có thể vẫn đang khởi tạo)"
fi

AWX_TASK=$(kubectl get pods -l app.kubernetes.io/name=awx-task -n awx \
  -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "NotFound")
if [ "$AWX_TASK" = "Running" ]; then
  pass "AWX task pod Running"
else
  fail "AWX task pod: $AWX_TASK"
fi

if kubectl get secret awx-admin-password -n awx &>/dev/null; then
  pass "AWX admin password secret tồn tại"
  ADMIN_PASS=$(kubectl get secret awx-admin-password -n awx \
    -o jsonpath='{.data.password}' | base64 -d 2>/dev/null || echo "???")
  info "AWX admin password: $ADMIN_PASS"
else
  fail "Secret awx-admin-password chưa có"
fi

echo ""
echo "============================================"
echo " Tóm tắt truy cập"
echo "============================================"
echo ""
echo "MinIO Console : http://minio.local"
echo "  User: minioadmin / Pass: minioadmin123"
echo ""
echo "AWX Web UI    : http://awx.local"
echo "  User: admin / Pass: (xem ở trên)"
echo ""
echo "Port-forward dự phòng:"
echo "  kubectl port-forward svc/minio 9001:9001 -n minio"
echo "  kubectl port-forward svc/awx-service 8052:80 -n awx"
echo "============================================"
