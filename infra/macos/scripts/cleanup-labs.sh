#!/usr/bin/env bash
# Cleanup MLOps lab resources on Docker Desktop K8s
set -euo pipefail

read -r -p "Delete namespace mlops and all lab resources? [y/N] " CONFIRM
if [[ "${CONFIRM,,}" != "y" ]]; then
  echo "Cancelled"
  exit 0
fi

kubectl delete namespace mlops --ignore-not-found --timeout=120s
echo "Namespace mlops deleted."
echo "Recreate: kubectl apply -f labs/lab01/k8s/namespace.yaml"
