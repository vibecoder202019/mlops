#!/usr/bin/env bash
set -euo pipefail

MLOPS_ROOT="${MLOPS_ROOT:-$HOME/mlops}"
COMPOSE_DIR="$MLOPS_ROOT/infra/ec2/docker-compose/lab09-rag"

echo "=== Deploy Lab 9 — RAG docker-compose on GPU EC2 ==="
cd "$COMPOSE_DIR"
docker compose up -d
sleep 20
curl -sf http://localhost:8080/health && echo "RAG API OK" || echo "RAG API starting..."
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
echo "RAG API: http://${PUBLIC_IP}:8080/query"
