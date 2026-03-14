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

# ── Preflight checks ─────────────────────────────────────────────────────────

if ! command -v docker &> /dev/null; then
    echo "ERROR: 'docker' not found." >&2
    echo "  Install Docker Desktop: https://docs.docker.com/get-docker/" >&2
    exit 1
fi

if ! docker info &> /dev/null; then
    echo "ERROR: Docker daemon is not running." >&2
    echo "  macOS/Windows: open Docker Desktop" >&2
    echo "  Linux: sudo systemctl start docker" >&2
    exit 1
fi

if ! docker compose version &> /dev/null; then
    echo "ERROR: 'docker compose' (v2) not found." >&2
    echo "  Update Docker Desktop, or install the compose plugin:" >&2
    echo "  https://docs.docker.com/compose/install/" >&2
    exit 1
fi

if ! command -v curl &> /dev/null; then
    echo "ERROR: 'curl' not found. Install it and try again." >&2
    exit 1
fi

if ! command -v python3 &> /dev/null; then
    echo "ERROR: 'python3' not found. Install Python 3.10+." >&2
    exit 1
fi

if ! python3 -c "import rich" &> /dev/null; then
    echo "ERROR: Python package 'rich' not installed." >&2
    echo "  Run: python3 -m pip install -r agent/requirements.txt" >&2
    exit 1
fi

if [[ "$MODE" == "guarded" || "$MODE" == "both" ]]; then
    if ! python3 -c "import runcycles" &> /dev/null; then
        echo "ERROR: Python package 'runcycles' not installed." >&2
        echo "  Run: python3 -m pip install -r agent/requirements.txt" >&2
        exit 1
    fi
fi

# ── Start the Cycles stack ────────────────────────────────────────────────────

# Reset stack to ensure clean budget state on every run.
echo "Resetting stack (clean budget state)..."
docker compose down -v 2>/dev/null || true

# After teardown, check for port conflicts from external processes
for PORT_INFO in "6379:Redis" "7878:Cycles server" "7979:Cycles admin"; do
    PORT="${PORT_INFO%%:*}"
    NAME="${PORT_INFO##*:}"
    if python3 -c "import socket; s=socket.socket(); s.settimeout(1); s.connect(('localhost',$PORT)); s.close()" 2>/dev/null; then
        echo "ERROR: Port $PORT is already in use (needed for $NAME)." >&2
        echo "  Find what's using it: lsof -i :$PORT" >&2
        echo "  Stop that process and try again." >&2
        exit 1
    fi
done

echo "Starting Cycles stack..."
if ! docker compose up -d --pull=missing 2>&1; then
    echo "" >&2
    echo "ERROR: Failed to start the Cycles stack." >&2
    echo "  Check Docker logs: docker compose logs" >&2
    echo "  Try manually:      docker compose up" >&2
    exit 1
fi

echo ""
echo "Waiting for services to be healthy..."
bash scripts/wait_healthy.sh 7878 "Cycles server"
bash scripts/wait_healthy.sh 7979 "Cycles admin"
echo ""

echo "Provisioning tenant and budget..."
API_KEY=$(bash scripts/provision.sh)
export CYCLES_API_KEY="$API_KEY"
export CYCLES_BASE_URL="http://localhost:7878"
export CYCLES_TENANT="demo-tenant"
echo ""

# ── Run the demo ──────────────────────────────────────────────────────────────

if [[ "$MODE" == "unguarded" || "$MODE" == "both" ]]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  MODE 1: Without Cycles"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    python3 agent/unguarded.py && true
    UNGUARDED_EXIT=$?
    if [ $UNGUARDED_EXIT -ne 0 ] && [ $UNGUARDED_EXIT -ne 130 ]; then
        echo ""
        echo "WARNING: Unguarded agent exited with code $UNGUARDED_EXIT." >&2
        echo "  This is not expected. Check the output above for errors." >&2
        echo ""
    fi
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
echo "  Admin UI:     http://localhost:7979/swagger-ui.html"
echo "  Re-run:       ./demo.sh"
echo "  Stop stack:   ./teardown.sh"
