#!/usr/bin/env bash
set -euo pipefail

NS="${1:?namespace}"
SVC="${2:?service}"
PORT="${3:-8000}"

echo "Waiting for vLLM pod to be ready..."
kubectl wait --for=condition=ready pod -l app="$SVC" -n "$NS" --timeout=600s

kubectl run "llm-smoke-$(date +%s)" -n "$NS" \
  --image=curlimages/curl --restart=Never --rm -i \
  --command -- curl -sf "http://${SVC}:${PORT}/v1/models"

kubectl run "llm-gen-$(date +%s)" -n "$NS" \
  --image=curlimages/curl --restart=Never --rm -i \
  --command -- curl -sf "http://${SVC}:${PORT}/v1/completions" \
    -H "Content-Type: application/json" \
    -d '{"model":"meta-llama/Llama-3.2-1B-Instruct","prompt":"Hello","max_tokens":10}'

echo "LLM smoke test PASSED"
