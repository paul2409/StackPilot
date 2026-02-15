#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
AWS_ENV="$ROOT/infra/aws/aws.env"
LOG_DIR="$ROOT/ci/logs/aws"

mkdir -p "$LOG_DIR"
source "$AWS_ENV"

echo "== CLEANUP CHECK ==" | tee "$LOG_DIR/cleanup.txt"

echo "-- Instances --" | tee -a "$LOG_DIR/cleanup.txt"
aws ec2 describe-instances \
  --filters "Name=tag:project,Values=stackpilot" \
            "Name=instance-state-name,Values=pending,running,stopping,stopped" \
  --query "Reservations[*].Instances[*].[InstanceId,State.Name,PublicIpAddress]" \
  --output table | tee -a "$LOG_DIR/cleanup.txt"

echo "-- Volumes --" | tee -a "$LOG_DIR/cleanup.txt"
aws ec2 describe-volumes \
  --filters "Name=tag:project,Values=stackpilot" \
  --query "Volumes[*].[VolumeId,State,Size]" \
  --output table | tee -a "$LOG_DIR/cleanup.txt"

echo "-- Security Groups --" | tee -a "$LOG_DIR/cleanup.txt"
aws ec2 describe-security-groups \
  --filters "Name=tag:project,Values=stackpilot" \
  --query "SecurityGroups[*].[GroupId,GroupName]" \
  --output table | tee -a "$LOG_DIR/cleanup.txt"

echo "NOTE: tables should be empty."
echo "PASS: cleanup-check"
