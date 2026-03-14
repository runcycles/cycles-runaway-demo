#!/usr/bin/env bash
set -euo pipefail

PORT=$1
TIMEOUT=60
ELAPSED=0

until curl -sf "http://localhost:$PORT/actuator/health" > /dev/null 2>&1; do
  if [ $ELAPSED -ge $TIMEOUT ]; then
    echo "ERROR: Port $PORT not healthy after ${TIMEOUT}s" >&2
    exit 1
  fi
  sleep 1
  ELAPSED=$((ELAPSED + 1))
done
