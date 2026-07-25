#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${1:?namespace}"
APP_LABEL="${2:?app label}"
PORT="${3:-8000}"
PATH_HEALTH="${4:-/health}"

echo "Running smoke test against $APP_LABEL in $NAMESPACE..."

kubectl run "smoke-test-$(date +%s)" \
  --namespace="$NAMESPACE" \
  --image=curlimages/curl:latest \
  --restart=Never \
  --rm -i \
  --command -- \
  curl -sf "http://${APP_LABEL}:${PORT}${PATH_HEALTH}"

echo "Smoke test PASSED"
