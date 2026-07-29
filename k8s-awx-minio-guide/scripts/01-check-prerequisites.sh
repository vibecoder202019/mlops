#!/usr/bin/env bash
# =============================================================================
# Script: 01-check-prerequisites.sh
# Mục đích: Kiểm tra môi trường trước khi triển khai AWX & MinIO
# Cách chạy: ./scripts/01-check-prerequisites.sh
# =============================================================================

set -euo pipefail

# Màu sắc cho output dễ đọc
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

pass() { echo -e "${GREEN}✅ PASS${NC}: $1"; }
fail() { echo -e "${RED}❌ FAIL${NC}: $1"; FAILED=1; }
warn() { echo -e "${YELLOW}⚠️  WARN${NC}: $1"; }

FAILED=0

echo "============================================"
echo " Kiểm tra môi trường K8s + AWX + MinIO"
echo "============================================"
echo ""

# --- Kiểm tra kubectl ---
# command -v — tìm đường dẫn binary trong PATH
if command -v kubectl &>/dev/null; then
  KUBECTL_VERSION=$(kubectl version --client -o yaml 2>/dev/null | grep gitVersion | head -1 | awk '{print $2}')
  pass "kubectl đã cài ($KUBECTL_VERSION)"
else
  fail "kubectl chưa cài — brew install kubectl"
fi

# --- Kiểm tra kết nối cluster ---
# get nodes — nếu cluster không chạy sẽ báo lỗi
if kubectl get nodes &>/dev/null; then
  NODE_STATUS=$(kubectl get nodes -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}')
  if [ "$NODE_STATUS" = "True" ]; then
    pass "Kubernetes cluster đang chạy (node Ready)"
  else
    fail "Node chưa Ready — kiểm tra Docker Desktop Kubernetes"
  fi
else
  fail "Không kết nối được cluster — bật Kubernetes trong Docker Desktop"
fi

# --- Kiểm tra StorageClass ---
# Cần StorageClass để PVC (MinIO data, PostgreSQL) hoạt động
if kubectl get storageclass &>/dev/null; then
  SC_COUNT=$(kubectl get storageclass --no-headers 2>/dev/null | wc -l | tr -d ' ')
  if [ "$SC_COUNT" -gt 0 ]; then
    pass "StorageClass có sẵn ($SC_COUNT class)"
  else
    fail "Không có StorageClass — bật storage trong Docker Desktop Settings"
  fi
else
  fail "Không lấy được StorageClass"
fi

# --- Kiểm tra Helm (tuỳ chọn) ---
if command -v helm &>/dev/null; then
  HELM_VER=$(helm version --short 2>/dev/null)
  pass "helm đã cài ($HELM_VER)"
else
  warn "helm chưa cài — cần để cài AWX Operator (brew install helm)"
fi

# --- Kiểm tra mc CLI (tuỳ chọn) ---
if command -v mc &>/dev/null; then
  pass "MinIO Client (mc) đã cài"
else
  warn "mc chưa cài — cần để thao tác bucket (brew install minio/stable/mc)"
fi

# --- Kiểm tra Ingress Controller ---
# AWX và MinIO cần Ingress để truy cập qua browser
if kubectl get pods -n ingress-nginx &>/dev/null; then
  INGRESS_READY=$(kubectl get pods -n ingress-nginx \
    -l app.kubernetes.io/component=controller \
    -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "NotFound")
  if [ "$INGRESS_READY" = "Running" ]; then
    pass "NGINX Ingress Controller đang chạy"
  else
    warn "Ingress Controller chưa Running — chạy: kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.3/deploy/static/provider/cloud/deploy.yaml"
  fi
else
  warn "Namespace ingress-nginx chưa tồn tại — cần cài Ingress Controller (xem docs/01)"
fi

# --- Kiểm tra /etc/hosts ---
# grep -q — tìm im lặng, exit 0 nếu tìm thấy
if grep -q "awx.local" /etc/hosts 2>/dev/null; then
  pass "/etc/hosts đã có awx.local"
else
  warn "/etc/hosts chưa có awx.local — thêm: 127.0.0.1 minio.local minio-api.local awx.local"
fi

echo ""
echo "============================================"
if [ "${FAILED:-0}" -eq 0 ]; then
  echo -e "${GREEN}Môi trường sẵn sàng! Tiếp theo: ./scripts/02-deploy-minio.sh${NC}"
else
  echo -e "${RED}Có lỗi cần khắc phục trước khi tiếp tục.${NC}"
  exit 1
fi
