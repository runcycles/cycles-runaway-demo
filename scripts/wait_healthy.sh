#!/usr/bin/env bash
set -euo pipefail

PORT=$1
LABEL="${2:-port $PORT}"
TIMEOUT=60
ELAPSED=0

printf "  Waiting for %s ..." "$LABEL" >&2
until curl -sf "http://localhost:$PORT/actuator/health" > /dev/null 2>&1; do
  if [ $ELAPSED -ge $TIMEOUT ]; then
    echo " FAILED (${TIMEOUT}s timeout)" >&2
    exit 1
  fi
  sleep 1
  ELAPSED=$((ELAPSED + 1))
done
echo " ready (${ELAPSED}s)" >&2
