#!/usr/bin/env bash
# =============================================================================
# Script: demo-upload.sh
# Mục đích: Demo thao tác MinIO — tạo bucket, upload/download file
# Cách chạy: ./examples/minio/demo-upload.sh
# Yêu cầu: mc CLI + MinIO đang chạy (port-forward hoặc Ingress)
# =============================================================================

set -euo pipefail

# Cấu hình MinIO — đổi nếu dùng credential khác
MINIO_ENDPOINT="${MINIO_ENDPOINT:-http://localhost:9000}"
MINIO_USER="${MINIO_USER:-minioadmin}"
MINIO_PASS="${MINIO_PASS:-minioadmin123}"
ALIAS="lab-minio"
BUCKET="demo-bucket"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[DEMO]${NC} $1"; }
ok()  { echo -e "${GREEN}[OK]${NC} $1"; }

echo "============================================"
echo " MinIO Demo — Upload/Download"
echo " Endpoint: $MINIO_ENDPOINT"
echo "============================================"

# Kiểm tra mc
command -v mc &>/dev/null || {
  echo "Cài mc: brew install minio/stable/mc"
  exit 1
}

# --- Bước 1: Cấu hình alias ---
log "Cấu hình mc alias '$ALIAS'..."
# mc alias set <tên> <endpoint> <access-key> <secret-key>
mc alias set "$ALIAS" "$MINIO_ENDPOINT" "$MINIO_USER" "$MINIO_PASS"

# --- Bước 2: Kiểm tra kết nối ---
log "Kiểm tra kết nối MinIO..."
mc admin info "$ALIAS"
ok "Kết nối thành công"

# --- Bước 3: Tạo bucket ---
log "Tạo bucket '$BUCKET'..."
# mc mb — make bucket (bỏ qua lỗi nếu bucket đã tồn tại)
mc mb "$ALIAS/$BUCKET" 2>/dev/null || log "Bucket đã tồn tại — bỏ qua"
ok "Bucket '$BUCKET' sẵn sàng"

# --- Bước 4: Tạo và upload file ---
DEMO_FILE="/tmp/minio-demo-$(date +%s).txt"
echo "MinIO demo upload at $(date)" > "$DEMO_FILE"
log "Upload file: $DEMO_FILE"
mc cp "$DEMO_FILE" "$ALIAS/$BUCKET/"
ok "Upload thành công"

# --- Bước 5: Liệt kê object ---
log "Danh sách object trong bucket:"
mc ls "$ALIAS/$BUCKET/"

# --- Bước 6: Download file ---
DOWNLOAD="/tmp/minio-downloaded.txt"
log "Download về: $DOWNLOAD"
mc cp "$ALIAS/$BUCKET/$(basename "$DEMO_FILE")" "$DOWNLOAD"
ok "Download thành công — nội dung:"
cat "$DOWNLOAD"

# --- Bước 7: Tạo bucket cho AWX ---
log "Tạo bucket cho AWX..."
for B in awx-projects awx-artifacts awx-backups; do
  mc mb "$ALIAS/$B" 2>/dev/null || true
  ok "Bucket '$B' sẵn sàng"
done

echo ""
echo "============================================"
ok "Demo hoàn tất!"
echo ""
echo "Các bucket đã tạo:"
mc ls "$ALIAS"
echo ""
echo "Truy cập Console: http://minio.local (hoặc port-forward 9001)"
echo "============================================"

# Dọn file tạm
rm -f "$DEMO_FILE" "$DOWNLOAD"
