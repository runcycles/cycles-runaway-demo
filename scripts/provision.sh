#!/usr/bin/env bash
set -euo pipefail

ADMIN_URL="http://localhost:7979/v1/admin"
ADMIN_KEY="demo-admin-key"
TENANT_ID="demo-tenant"

# 1. Create tenant (ignore 409 = already exists)
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$ADMIN_URL/tenants" \
  -H "Content-Type: application/json" \
  -H "X-Admin-API-Key: $ADMIN_KEY" \
  -d "{\"tenant_id\": \"$TENANT_ID\", \"name\": \"Demo Tenant\"}")

if [ "$HTTP_CODE" != "200" ] && [ "$HTTP_CODE" != "201" ] && [ "$HTTP_CODE" != "409" ]; then
  echo "" >&2
  echo "ERROR: Failed to create tenant (HTTP $HTTP_CODE)." >&2
  echo "  Is the admin server healthy? Try: curl http://localhost:7979/actuator/health" >&2
  echo "  Check logs with: docker compose logs cycles-admin" >&2
  exit 1
fi
echo "  Tenant: $TENANT_ID" >&2

# 2. Create API key
API_KEY_RESPONSE=$(curl -s -X POST "$ADMIN_URL/api-keys" \
  -H "Content-Type: application/json" \
  -H "X-Admin-API-Key: $ADMIN_KEY" \
  -d "{
    \"tenant_id\": \"$TENANT_ID\",
    \"name\": \"demo-key\",
    \"permissions\": [\"reservations:create\",\"reservations:commit\",\"reservations:release\",\"reservations:extend\",\"balances:read\"]
  }")

API_KEY=$(echo "$API_KEY_RESPONSE" | grep -o '"key_secret":"[^"]*"' | cut -d'"' -f4)

if [ -z "$API_KEY" ]; then
  echo "" >&2
  echo "ERROR: Failed to create API key." >&2
  echo "  Server response: $API_KEY_RESPONSE" >&2
  echo "  Check logs with: docker compose logs cycles-admin" >&2
  exit 1
fi
echo "  API key: created" >&2

# 2b. Patch the Redis lookup so the protocol server can find the key.
#     The admin stores the lookup under a 14-char prefix (e.g. cyc_live_Z9Acz)
#     but the server resolves with a 9-char prefix (cyc_live_).
#     Bridge the gap by copying the key_id under the shorter prefix.
SHORT_PREFIX="${API_KEY:0:9}"                      # e.g. "cyc_live_"
LONG_PREFIX=$(echo "$API_KEY_RESPONSE" | grep -o '"key_prefix":"[^"]*"' | cut -d'"' -f4)
KEY_ID=$(echo "$API_KEY_RESPONSE" | grep -o '"key_id":"[^"]*"' | cut -d'"' -f4)

if [ -n "$SHORT_PREFIX" ] && [ -n "$KEY_ID" ]; then
  docker exec cycles-runaway-demo-redis-1 redis-cli set "apikey:lookup:$SHORT_PREFIX" "$KEY_ID" > /dev/null 2>&1 || true
fi

# 3. Create budgets at every scope level the server may check ($1.00 = 100,000,000 microcents)
for SCOPE in \
  "tenant:$TENANT_ID" \
  "tenant:$TENANT_ID/workspace:default" \
  "tenant:$TENANT_ID/workspace:default/app:default" \
  "tenant:$TENANT_ID/workspace:default/app:default/workflow:default" \
  "tenant:$TENANT_ID/workspace:default/app:default/workflow:default/agent:support-bot"; do
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$ADMIN_URL/budgets" \
    -H "Content-Type: application/json" \
    -H "X-Cycles-API-Key: $API_KEY" \
    -d "{\"scope\": \"$SCOPE\", \"unit\": \"USD_MICROCENTS\", \"allocated\": {\"amount\": 100000000, \"unit\": \"USD_MICROCENTS\"}}")

  if [ "$HTTP_CODE" != "200" ] && [ "$HTTP_CODE" != "201" ] && [ "$HTTP_CODE" != "409" ]; then
    echo "" >&2
    echo "ERROR: Failed to create budget (HTTP $HTTP_CODE, scope=$SCOPE)." >&2
    echo "  Check logs with: docker compose logs cycles-admin" >&2
    exit 1
  fi
done
echo "  Budget: \$1.00 (scope: tenant:$TENANT_ID)" >&2

# Print only the API key to stdout
echo "$API_KEY"
