#!/bin/bash

BASE_URL="https://flavortown.hackclub.com/api/v1"
API_KEY=$1

if [ -z "$API_KEY" ]; then
    echo "Usage: ./test_api.sh YOUR_API_KEY"
    exit 1
fi

echo "--- Testing Flavortown API Connectivity ---"
echo "URL: $BASE_URL"
echo "Key: ${API_KEY:0:4}... (truncated)"
echo ""

endpoints=("/projects" "/store" "/users")

for endpoint in "${endpoints[@]}"; do
    echo "Testing $endpoint..."
    RESPONSE=$(curl -s -w "\n%{http_code}" \
        -H "X-Flavortown-Ext-2532: true" \
        -H "Accept: application/json" \
        -H "Authorization: Bearer $API_KEY" \
        "$BASE_URL$endpoint")
    
    HTTP_STATUS=$(echo "$RESPONSE" | tail -n 1)
    BODY=$(echo "$RESPONSE" | sed '$d')
    
    if [ "$HTTP_STATUS" -eq 200 ]; then
        echo "✅ SUCCESS (200)"
        echo "Response Preview: $(echo $BODY | head -c 100)..."
    else
        echo "❌ FAILED ($HTTP_STATUS)"
        echo "Error: $BODY"
    fi
    echo "-----------------------------------"
done
