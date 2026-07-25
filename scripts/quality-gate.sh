#!/usr/bin/env bash
set -euo pipefail

METRICS_FILE="${1:?Usage: quality-gate.sh metrics.json MIN_R2}"
MIN_R2="${2:?Usage: quality-gate.sh metrics.json MIN_R2}"

R2=$(python3 -c "import json; print(json.load(open('$METRICS_FILE'))['r2_score'])")

echo "Model R2 score: $R2"
echo "Minimum required: $MIN_R2"

python3 -c "
import sys
r2 = float('$R2')
min_r2 = float('$MIN_R2')
if r2 < min_r2:
    print(f'QUALITY GATE FAILED: R2 {r2} < {min_r2}')
    sys.exit(1)
print(f'QUALITY GATE PASSED: R2 {r2} >= {min_r2}')
"
