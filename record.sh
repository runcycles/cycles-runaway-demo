#!/usr/bin/env bash
set -euo pipefail

# ── Check prerequisites ──────────────────────────────────────────────────────

if ! command -v vhs &> /dev/null; then
    echo "ERROR: 'vhs' not found." >&2
    echo "  Install it: brew install vhs" >&2
    exit 1
fi

# ── Ensure the Cycles stack is running ────────────────────────────────────────

if curl -sf http://localhost:7878/actuator/health > /dev/null 2>&1; then
    echo "Cycles stack is already running."
else
    echo "Cycles stack not running — starting it..."
    docker compose up -d
    echo "Waiting for services to be healthy..."
    bash scripts/wait_healthy.sh 7878 "Cycles server"
    bash scripts/wait_healthy.sh 7979 "Cycles admin"
    echo "Stack is healthy."
fi

# ── Record the demo ──────────────────────────────────────────────────────────

echo ""
echo "Recording demo.tape → demo.gif ..."
vhs demo.tape
echo "Done — demo.gif created."
