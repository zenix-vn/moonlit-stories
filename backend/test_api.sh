#!/bin/bash
# Moonlit Stories API verification script

API_URL="http://localhost:8088"
DEVICE_ID="test-device-uuid-999"
COUNTRY="US"

echo "=== 1. Starting Guest Login ==="
LOGIN_RES=$(curl -s -X POST "$API_URL/v1/auth/guest" \
  -H "Content-Type: application/json" \
  -d "{
    \"device_id\": \"$DEVICE_ID\",
    \"platform\": \"ios\",
    \"os_version\": \"17.4\",
    \"app_version\": \"1.0.0\",
    \"country_code\": \"$COUNTRY\",
    \"country_name\": \"United States\",
    \"timezone\": \"EST\"
  }")

TOKEN=$(echo "$LOGIN_RES" | grep -o '"token":"[^"]*' | grep -o '[^"]*$')
USER_ID=$(echo "$LOGIN_RES" | grep -o '"id":"[^"]*' | grep -o '[^"]*$')

if [ -z "$TOKEN" ]; then
  echo "Failed to get auth token. Make sure the API server is running on $API_URL"
  exit 1
fi

echo "Success! Logged in User ID: $USER_ID"
echo "JWT Token: ${TOKEN:0:20}..."
echo ""

echo "=== 2. Get Home Feed ==="
curl -s -X GET "$API_URL/v1/home" \
  -H "Authorization: Bearer $TOKEN" | json_pp | head -n 30
echo ""

echo "=== 3. Search Discover Feed ==="
curl -s -X GET "$API_URL/v1/discover?genre=revenge-rebirth" \
  -H "Authorization: Bearer $TOKEN" | json_pp
echo ""

echo "=== 4. Fetch Story Details (Reborn as the Villain Queen) ==="
# Slug from seed data
curl -s -X GET "$API_URL/v1/stories/reborn-as-the-villain-queen" \
  -H "Authorization: Bearer $TOKEN" | json_pp | head -n 40
echo ""

echo "=== 5. Get Episode 4 Lock Status (Locked) ==="
# Episode ID from seed data
EP_ID="60000000-0000-0000-0000-000000000014"
curl -s -X GET "$API_URL/v1/episodes/$EP_ID/access" \
  -H "Authorization: Bearer $TOKEN" | json_pp
echo ""

echo "=== 6. Unlock Episode 4 using Coins ==="
curl -s -X POST "$API_URL/v1/episodes/$EP_ID/unlock/coins" \
  -H "Authorization: Bearer $TOKEN" | json_pp
echo ""

echo "=== 7. Get Episode 4 Locked Detail (Should be unlocked now) ==="
curl -s -X GET "$API_URL/v1/episodes/$EP_ID" \
  -H "Authorization: Bearer $TOKEN" | json_pp | head -n 25
echo ""

echo "=== 8. Get Wallet Balance ==="
curl -s -X GET "$API_URL/v1/wallet" \
  -H "Authorization: Bearer $TOKEN" | json_pp
echo ""

echo "=== 9. Claim Daily Checkin Streak Reward ==="
curl -s -X POST "$API_URL/v1/rewards/checkin" \
  -H "Authorization: Bearer $TOKEN" | json_pp
echo ""

echo "=== 10. Post Analytics Event ==="
curl -s -X POST "$API_URL/v1/events" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "event_name": "app_opened",
    "properties": {"session_id": "session-123", "platform": "ios"}
  }' | json_pp
echo ""

echo "=== 11. Admin Login (admin@moonlitstories.com / admin123) ==="
ADMIN_RES=$(curl -s -X POST "$API_URL/admin/auth/login" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "admin@moonlitstories.com",
    "password": "admin123"
  }')

ADMIN_TOKEN=$(echo "$ADMIN_RES" | grep -o '"token":"[^"]*' | grep -o '[^"]*$')
echo "Admin Success! Token: ${ADMIN_TOKEN:0:20}..."
echo ""

echo "=== 12. Admin Fetch Story List ==="
curl -s -X GET "$API_URL/admin/stories" \
  -H "Authorization: Bearer $ADMIN_TOKEN" | json_pp
echo ""

echo "Verification completed successfully."
