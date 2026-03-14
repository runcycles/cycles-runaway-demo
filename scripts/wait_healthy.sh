#!/usr/bin/env bash
set -euo pipefail

PORT=$1
LABEL="${2:-port $PORT}"
TIMEOUT=60
ELAPSED=0

printf "  Waiting for %s ..." "$LABEL" >&2
until curl -sf "http://localhost:$PORT/actuator/health" > /dev/null 2>&1; do
  if [ $ELAPSED -ge $TIMEOUT ]; then
    echo "" >&2
    echo "" >&2
    echo "ERROR: $LABEL (port $PORT) not healthy after ${TIMEOUT}s." >&2
    echo "" >&2
    echo "  Troubleshooting:" >&2
    echo "    1. Check container status:  docker compose ps" >&2
    echo "    2. Check container logs:    docker compose logs ${LABEL// /-}" >&2
    echo "    3. Check port availability: curl -v http://localhost:$PORT/actuator/health" >&2
    echo "    4. Restart the stack:       docker compose down -v && docker compose up -d" >&2
    exit 1
  fi
  sleep 1
  ELAPSED=$((ELAPSED + 1))
done
echo " ready (${ELAPSED}s)" >&2
