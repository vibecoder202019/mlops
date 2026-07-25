#!/usr/bin/env bash
set -euo pipefail

REGION="${AWS_REGION:-ap-southeast-1}"
PROJECT="${PROJECT:-mlops}"

IDS=$(aws ec2 describe-instances \
  --region "$REGION" \
  --filters "Name=tag:Project,Values=${PROJECT}" "Name=instance-state-name,Values=stopped" \
  --query 'Reservations[].Instances[].InstanceId' \
  --output text)

if [ -z "$IDS" ] || [ "$IDS" = "None" ]; then
  echo "No stopped instances found with tag Project=${PROJECT}"
  exit 0
fi

echo "Starting instances: $IDS"
aws ec2 start-instances --region "$REGION" --instance-ids $IDS
aws ec2 wait instance-running --region "$REGION" --instance-ids $IDS
echo "Instances running."
