#!/usr/bin/env bash
set -euo pipefail

MLOPS_ROOT="${MLOPS_ROOT:-$HOME/mlops}"
LAB_DIR="$MLOPS_ROOT/labs/lab01"

echo "=== Deploy Lab 1 — Docker on EC2 ==="
cd "$LAB_DIR"

python3 -m venv .venv
source .venv/bin/activate
pip install -q -r requirements.txt
python train.py

docker build -t iris-classifier:1.0.0 .
docker rm -f iris-api 2>/dev/null || true
docker run -d --name iris-api -p 8000:8000 --restart unless-stopped iris-classifier:1.0.0

sleep 3
curl -sf http://localhost:8000/health && echo ""
echo "Lab 1 running: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8000/docs"
