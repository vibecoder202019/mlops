#!/usr/bin/env bash
set -euo pipefail

MAX_BUDGET="${MAX_BUDGET:-50}"
REGION="${AWS_REGION:-ap-southeast-1}"

echo "=== Cost Guardrail Check ==="

RUNNING_GPU=$(aws ec2 describe-instances \
  --region "$REGION" \
  --filters "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[?contains(InstanceType,`g4`) || contains(InstanceType,`g5`) || contains(InstanceType,`p3`)].InstanceId' \
  --output text 2>/dev/null || echo "")

if [ -n "$RUNNING_GPU" ] && [ "$RUNNING_GPU" != "None" ]; then
  echo "WARNING: GPU instances running: $RUNNING_GPU"
else
  echo "OK: No GPU instances running"
fi

if command -v kubectl &>/dev/null && kubectl cluster-info &>/dev/null 2>&1; then
  NODES=$(kubectl get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ')
  echo "EKS nodes: $NODES"
fi

echo "Cost check complete. Budget alert target: \$${MAX_BUDGET}/month"
