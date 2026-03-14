#!/usr/bin/env bash
set -euo pipefail
docker compose down -v
echo "Stack stopped and volumes removed."
