#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ── Check prerequisites ──────────────────────────────────────────────────────

if ! command -v vhs &> /dev/null; then
    echo "ERROR: 'vhs' not found." >&2
    echo "  Install it: brew install vhs" >&2
    exit 1
fi

if [[ -z "${VIRTUAL_ENV:-}" && -f "$SCRIPT_DIR/.venv/bin/activate" ]]; then
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR/.venv/bin/activate"
fi

# ── Bring the Cycles stack to a clean, provisioned state ─────────────────────
#
# The recording assumes:
#   - the stack is healthy
#   - a fresh tenant + $1.00 budget are provisioned
#   - CYCLES_BASE_URL / CYCLES_API_KEY / CYCLES_TENANT are exported
#
# Reset every time so the guarded run starts at $0 of $1.00 spent.

echo "Resetting stack for a clean budget..."
docker compose down -v 2>/dev/null || true

echo "Starting Cycles stack..."
docker compose up -d --pull=missing > /dev/null

echo "Waiting for services to be healthy..."
bash scripts/wait_healthy.sh 7878 "Cycles server"
bash scripts/wait_healthy.sh 7979 "Cycles admin"

echo "Provisioning tenant and budget..."
API_KEY=$(bash scripts/provision.sh)
export CYCLES_API_KEY="$API_KEY"
export CYCLES_BASE_URL="http://localhost:7878"
export CYCLES_TENANT="demo-tenant"

# ── Record the demo ──────────────────────────────────────────────────────────

echo ""
echo "Recording demo.tape → demo.gif ..."
vhs demo.tape
echo "Done — demo.gif created."
