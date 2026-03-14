#!/usr/bin/env bash
set -euo pipefail

ADMIN_URL="http://localhost:7979/v1/admin"
ADMIN_KEY="demo-admin-key"

# 1. Create tenant (ignore 409 = already exists)
HTTP_CODE=$(curl -s -o /dev/stderr -w "%{http_code}" -X POST "$ADMIN_URL/tenants" \
  -H "Content-Type: application/json" \
  -H "X-Admin-API-Key: $ADMIN_KEY" \
  -d '{"tenant_id": "demo-tenant", "name": "Demo Tenant"}' 2>/dev/null)

if [ "$HTTP_CODE" != "200" ] && [ "$HTTP_CODE" != "201" ] && [ "$HTTP_CODE" != "409" ]; then
  echo "ERROR: Failed to create tenant (HTTP $HTTP_CODE)" >&2
  exit 1
fi
echo "Tenant created or already exists." >&2

# 2. Create API key
API_KEY_RESPONSE=$(curl -s -X POST "$ADMIN_URL/api-keys" \
  -H "Content-Type: application/json" \
  -H "X-Admin-API-Key: $ADMIN_KEY" \
  -d '{
    "tenant_id": "demo-tenant",
    "name": "demo-key",
    "permissions": ["reservations:create","reservations:commit","reservations:release","reservations:extend","balances:read"]
  }')

API_KEY=$(echo "$API_KEY_RESPONSE" | grep -o '"key_secret":"[^"]*"' | cut -d'"' -f4)

if [ -z "$API_KEY" ]; then
  echo "ERROR: Failed to extract API key from response: $API_KEY_RESPONSE" >&2
  exit 1
fi
echo "API key created." >&2

# 3. Create budget ($1.00 = 100,000,000 microcents) — ignore 409
HTTP_CODE=$(curl -s -o /dev/stderr -w "%{http_code}" -X POST "$ADMIN_URL/budgets" \
  -H "Content-Type: application/json" \
  -H "X-Cycles-API-Key: $API_KEY" \
  -d '{"scope": "tenant:demo-tenant", "unit": "USD_MICROCENTS", "allocated": {"amount": 100000000, "unit": "USD_MICROCENTS"}}' 2>/dev/null)

if [ "$HTTP_CODE" != "200" ] && [ "$HTTP_CODE" != "201" ] && [ "$HTTP_CODE" != "409" ]; then
  echo "ERROR: Failed to create budget (HTTP $HTTP_CODE)" >&2
  exit 1
fi
echo "Budget created (\$1.00)." >&2

# Print only the API key to stdout
echo "$API_KEY"
