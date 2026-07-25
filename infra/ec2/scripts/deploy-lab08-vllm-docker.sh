#!/usr/bin/env bash
set -euo pipefail

echo "=== Deploy Lab 8 — vLLM Docker on GPU EC2 ==="

MODEL="${VLLM_MODEL:-meta-llama/Llama-3.2-1B-Instruct}"
PORT="${VLLM_PORT:-8000}"

nvidia-smi || { echo "ERROR: GPU not available. Reboot after driver install."; exit 1; }

docker rm -f vllm 2>/dev/null || true
docker run -d --name vllm --gpus all \
  -p "${PORT}:8000" \
  --ipc=host \
  -v /home/ubuntu/.cache/huggingface:/root/.cache/huggingface \
  --restart unless-stopped \
  vllm/vllm-openai:latest \
  --model "$MODEL" \
  --max-model-len 4096 \
  --gpu-memory-utilization 0.9

echo "Waiting for vLLM to start (may take 2-5 min)..."
sleep 30

for i in $(seq 1 20); do
  curl -sf "http://localhost:${PORT}/v1/models" && break
  sleep 15
done

PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
echo "vLLM ready: http://${PUBLIC_IP}:${PORT}/v1/models"
echo ""
echo 'Test chat:'
echo "curl http://${PUBLIC_IP}:${PORT}/v1/chat/completions -H 'Content-Type: application/json' -d '{\"model\":\"${MODEL}\",\"messages\":[{\"role\":\"user\",\"content\":\"Hello\"}],\"max_tokens\":50}'"
