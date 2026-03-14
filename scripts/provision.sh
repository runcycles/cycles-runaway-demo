#!/usr/bin/env bash
set -euo pipefail

ADMIN_URL="http://localhost:7979/v1/admin"
ADMIN_KEY="demo-admin-key"

# Use a unique run ID so each demo run gets a fresh budget scope.
# This avoids the "budget already spent from a previous run" problem.
RUN_ID="run-$(date +%s)"
TENANT_ID="demo-tenant"
BUDGET_SCOPE="agent:${TENANT_ID}/${RUN_ID}"

# 1. Create tenant (ignore 409 = already exists)
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$ADMIN_URL/tenants" \
  -H "Content-Type: application/json" \
  -H "X-Admin-API-Key: $ADMIN_KEY" \
  -d "{\"tenant_id\": \"$TENANT_ID\", \"name\": \"Demo Tenant\"}")

if [ "$HTTP_CODE" != "200" ] && [ "$HTTP_CODE" != "201" ] && [ "$HTTP_CODE" != "409" ]; then
  echo "ERROR: Failed to create tenant (HTTP $HTTP_CODE)" >&2
  exit 1
fi
echo "Tenant: $TENANT_ID" >&2

# 2. Create API key
API_KEY_RESPONSE=$(curl -s -X POST "$ADMIN_URL/api-keys" \
  -H "Content-Type: application/json" \
  -H "X-Admin-API-Key: $ADMIN_KEY" \
  -d "{
    \"tenant_id\": \"$TENANT_ID\",
    \"name\": \"demo-key-$RUN_ID\",
    \"permissions\": [\"reservations:create\",\"reservations:commit\",\"reservations:release\",\"reservations:extend\",\"balances:read\"]
  }")

API_KEY=$(echo "$API_KEY_RESPONSE" | grep -o '"key_secret":"[^"]*"' | cut -d'"' -f4)

if [ -z "$API_KEY" ]; then
  echo "ERROR: Failed to extract API key from response: $API_KEY_RESPONSE" >&2
  exit 1
fi
echo "API key: created" >&2

# 3. Create budget ($1.00 = 100,000,000 microcents)
# Uses a unique scope per run so re-runs always start with a fresh $1.00 budget.
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$ADMIN_URL/budgets" \
  -H "Content-Type: application/json" \
  -H "X-Cycles-API-Key: $API_KEY" \
  -d "{\"scope\": \"$BUDGET_SCOPE\", \"unit\": \"USD_MICROCENTS\", \"allocated\": {\"amount\": 100000000, \"unit\": \"USD_MICROCENTS\"}}")

if [ "$HTTP_CODE" != "200" ] && [ "$HTTP_CODE" != "201" ] && [ "$HTTP_CODE" != "409" ]; then
  echo "ERROR: Failed to create budget (HTTP $HTTP_CODE)" >&2
  exit 1
fi
echo "Budget: \$1.00 (scope: $BUDGET_SCOPE)" >&2

# Print only the API key to stdout
echo "$API_KEY"
