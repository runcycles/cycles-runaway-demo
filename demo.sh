#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-both}"

echo ""
echo "⚡ RunCycles — Runaway Agent Demo"
echo ""
echo "Starting Cycles stack..."
docker compose up -d
bash scripts/wait_healthy.sh 7878
bash scripts/wait_healthy.sh 7979
echo "Stack is up."
echo ""

API_KEY=$(bash scripts/provision.sh)
export CYCLES_API_KEY="$API_KEY"
export CYCLES_BASE_URL="http://localhost:7878"
export CYCLES_TENANT="demo-tenant"

if [[ "$MODE" == "unguarded" || "$MODE" == "both" ]]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  MODE 1: Without Cycles"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    python3 agent/unguarded.py || true
fi

if [[ "$MODE" == "guarded" || "$MODE" == "both" ]]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  MODE 2: With Cycles (budget: \$1.00)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    python3 agent/guarded.py
fi

echo ""
echo "Demo complete."
echo "  Swagger UI:   http://localhost:7878/swagger-ui.html"
echo "  Stop stack:   ./teardown.sh"
