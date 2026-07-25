#!/usr/bin/env bash
# Stop MLOps lab EC2 instances by tag
set -euo pipefail

REGION="${AWS_REGION:-ap-southeast-1}"
PROJECT="${PROJECT:-mlops}"

IDS=$(aws ec2 describe-instances \
  --region "$REGION" \
  --filters "Name=tag:Project,Values=${PROJECT}" "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].InstanceId' \
  --output text)

if [ -z "$IDS" ] || [ "$IDS" = "None" ]; then
  echo "No running instances found with tag Project=${PROJECT}"
  exit 0
fi

echo "Stopping instances: $IDS"
aws ec2 stop-instances --region "$REGION" --instance-ids $IDS
echo "Done. Remember to start again: start-all-lab-instances.sh"
