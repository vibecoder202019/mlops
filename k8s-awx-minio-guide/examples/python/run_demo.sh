#!/usr/bin/env bash
# =============================================================================
# Script: run_demo.sh
# Mục đích: Demo tích hợp Python + AWX API (chạy trên máy local)
# Yêu cầu: AWX đang chạy, AWX_TOKEN đã set
# Cách chạy:
#   export AWX_URL="http://localhost:8052"
#   export AWX_TOKEN="your-token"
#   ./examples/python/run_demo.sh
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${BLUE}[DEMO]${NC} $1"; }
ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

echo "============================================"
echo " Python + AWX Demo"
echo "============================================"

# --- Kiểm tra biến môi trường ---
if [ -z "${AWX_TOKEN:-}" ]; then
  warn "AWX_TOKEN chưa set."
  echo ""
  echo "Tạo token:"
  echo "  1. AWX UI → User (góc phải) → Tokens → Create Token"
  echo "  2. export AWX_TOKEN='paste-token-here'"
  echo "  3. export AWX_URL='http://localhost:8052'"
  echo ""
  echo "Hoặc port-forward AWX trước:"
  echo "  kubectl port-forward svc/awx-service 8052:80 -n awx"
  exit 1
fi

export AWX_URL="${AWX_URL:-http://localhost:8052}"
log "AWX URL: $AWX_URL"

# --- Setup venv ---
if [ ! -d ".venv" ]; then
  log "Tạo Python venv..."
  python3 -m venv .venv
fi
# shellcheck disable=SC1091
source .venv/bin/activate

log "Cài dependencies..."
pip install -q -r requirements.txt

# --- Test Python script local (không cần AWX) ---
echo ""
log "Test 1: Chạy Python script local..."
python3 scripts/process_data.py --name "Demo Local"
ok "Script local OK"

log "Test 2: Generate report..."
REPORT=$(python3 scripts/generate_report.py)
ok "Report created: $REPORT"

# --- Gọi AWX API ---
echo ""
log "Test 3: Liệt kê Job Template qua AWX API..."
python3 awx_client.py list-templates || warn "Không kết nối được AWX API — kiểm tra AWX_URL và token"

echo ""
log "Test 4: Liệt kê Projects..."
python3 list_resources.py projects 2>/dev/null || true

echo ""
echo "============================================"
ok "Demo hoàn tất!"
echo ""
echo "Launch job từ Python (cần Job Template đã tạo trên AWX):"
echo "  python3 launch_job.py --template-name 'Python Hello World' --wait"
echo ""
echo "Launch kèm extra vars:"
echo "  python3 launch_job.py --template-id 7 --extra-vars '{\"user_name\": \"Python API\"}' --wait"
echo "============================================"
