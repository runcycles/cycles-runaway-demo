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

# ── Transcode for homepage embedding ─────────────────────────────────────────

if command -v ffmpeg &> /dev/null; then
    echo ""
    echo "Transcoding demo.gif → demo.mp4 (H.264) ..."
    ffmpeg -y -loglevel error \
        -i demo.gif \
        -movflags +faststart -pix_fmt yuv420p \
        -c:v libx264 -preset slow -crf 22 \
        -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" \
        demo.mp4
    echo "Transcoding demo.gif → demo.webm (VP9) ..."
    ffmpeg -y -loglevel error \
        -i demo.gif \
        -c:v libvpx-vp9 -b:v 0 -crf 32 -row-mt 1 -pix_fmt yuv420p -an \
        demo.webm
    echo "Extracting poster frame → demo-runaway-poster.png ..."
    # Last-frame summary card, captured well into the SUMMARY_HOLD_S window
    # (5s hold, sampled at 29s of a ~33s clip → squarely in the middle).
    ffmpeg -y -loglevel error \
        -ss 29 -i demo.mp4 \
        -vframes 1 \
        demo-runaway-poster.png
    echo ""
    ls -lh demo.gif demo.mp4 demo.webm demo-runaway-poster.png
else
    echo ""
    echo "WARNING: ffmpeg not found — skipping demo.mp4 / demo.webm."
    echo "  Install ffmpeg to regenerate the homepage video assets:"
    echo "    macOS: brew install ffmpeg"
    echo "    Linux: sudo apt install ffmpeg"
fi
