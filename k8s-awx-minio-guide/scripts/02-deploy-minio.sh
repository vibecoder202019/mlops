#!/usr/bin/env bash
# =============================================================================
# Script: 02-deploy-minio.sh
# Mục đích: Triển khai MinIO lên Kubernetes theo đúng thứ tự phụ thuộc
# Cách chạy: ./scripts/02-deploy-minio.sh
# Thời gian: ~2-3 phút
# =============================================================================

set -euo pipefail

# SCRIPT_DIR — thư mục chứa script này
# cd vào thư mục gốc repo (parent của scripts/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MINIO_DIR="$REPO_ROOT/minio"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[INFO]${NC} $1"; }
ok()  { echo -e "${GREEN}[OK]${NC} $1"; }

echo "============================================"
echo " Triển khai MinIO trên Kubernetes"
echo "============================================"

# --- Bước 1: Namespace ---
log "Tạo namespace minio..."
kubectl apply -f "$MINIO_DIR/namespace.yaml"

# --- Bước 2: Secret (credential) ---
log "Tạo Secret chứa root user/password..."
kubectl apply -f "$MINIO_DIR/secret.yaml"

# --- Bước 3: PVC (disk) ---
log "Tạo PersistentVolumeClaim (10Gi)..."
kubectl apply -f "$MINIO_DIR/pvc.yaml"

# Chờ PVC Bound — pod sẽ Pending nếu PVC chưa sẵn sàng
log "Chờ PVC Bound (timeout 60s)..."
kubectl wait --for=jsonpath='{.status.phase}'=Bound \
  pvc/minio-data -n minio --timeout=60s || {
    echo "PVC chưa Bound — kiểm tra StorageClass:"
    kubectl describe pvc minio-data -n minio
    exit 1
  }
ok "PVC minio-data đã Bound"

# --- Bước 4: Deployment ---
log "Deploy MinIO pod..."
kubectl apply -f "$MINIO_DIR/deployment.yaml"

# Chờ pod Ready
log "Chờ MinIO pod Ready (timeout 120s)..."
kubectl wait --for=condition=ready pod \
  -l app=minio -n minio --timeout=120s
ok "MinIO pod đang Running"

# --- Bước 5: Service ---
log "Tạo Service..."
kubectl apply -f "$MINIO_DIR/service.yaml"

# --- Bước 6: Ingress ---
log "Tạo Ingress..."
kubectl apply -f "$MINIO_DIR/ingress.yaml"

echo ""
echo "============================================"
ok "MinIO triển khai thành công!"
echo ""
echo "Truy cập:"
echo "  Console UI : http://minio.local      (user: minioadmin / pass: minioadmin123)"
echo "  S3 API     : http://minio-api.local:9000"
echo ""
echo "Nếu Ingress chưa hoạt động, dùng port-forward:"
echo "  kubectl port-forward svc/minio 9001:9001 -n minio  # Console"
echo "  kubectl port-forward svc/minio 9000:9000 -n minio  # S3 API"
echo ""
echo "Tiếp theo: ./scripts/03-deploy-awx-operator.sh"
echo "============================================"

# In trạng thái cuối
kubectl get all -n minio
