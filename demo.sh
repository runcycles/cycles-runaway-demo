#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-both}"

if [[ "$MODE" != "unguarded" && "$MODE" != "guarded" && "$MODE" != "both" ]]; then
    echo "Usage: $0 [unguarded|guarded|both]" >&2
    exit 1
fi

echo ""
echo "⚡ RunCycles — Runaway Agent Demo"
echo ""

# Preflight checks
if ! command -v docker &> /dev/null; then
    echo "ERROR: docker is not installed. Install Docker Desktop or Docker Engine first." >&2
    exit 1
fi
if ! docker info &> /dev/null; then
    echo "ERROR: Docker daemon is not running. Start Docker and try again." >&2
    exit 1
fi
if ! command -v python3 &> /dev/null; then
    echo "ERROR: python3 is not installed. Install Python 3.10+ first." >&2
    exit 1
fi
if ! python3 -c "import rich" &> /dev/null; then
    echo "ERROR: 'rich' package not found. Run: python3 -m pip install -r agent/requirements.txt" >&2
    exit 1
fi
if [[ "$MODE" == "guarded" || "$MODE" == "both" ]]; then
    if ! python3 -c "import runcycles" &> /dev/null; then
        echo "ERROR: 'runcycles' package not found. Run: python3 -m pip install -r agent/requirements.txt" >&2
        exit 1
    fi
fi

echo "Starting Cycles stack..."
docker compose up -d --pull=missing
bash scripts/wait_healthy.sh 7878 "Cycles server"
bash scripts/wait_healthy.sh 7979 "Cycles admin"
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
