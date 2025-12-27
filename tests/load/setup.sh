#!/bin/bash
#
# Setup script for k6 load testing
# Creates test users and prepares the environment
#

set -e

BASE_URL="${BASE_URL:-http://localhost:8080}"
NUM_USERS="${NUM_USERS:-100}"
TENANT_ID="${TENANT_ID:-11111111-1111-1111-1111-111111111111}"

echo "=== ClovaLink Load Test Setup ==="
echo "Base URL: $BASE_URL"
echo "Creating $NUM_USERS test users..."
echo ""

# Check if k6 is installed
if ! command -v k6 &> /dev/null; then
    echo "k6 is not installed. Install it with:"
    echo "  brew install k6"
    echo "  # or"
    echo "  docker pull grafana/k6"
    exit 1
fi

# Check if server is running
echo "Checking server connectivity..."
if ! curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/api/health" | grep -q "200"; then
    echo "Warning: Server health check failed. Make sure the backend is running."
    echo "Continuing anyway..."
fi

# Create test users in batches
echo ""
echo "Creating test users..."

for i in $(seq 1 $NUM_USERS); do
    EMAIL="loadtest_user_${i}@test.local"
    PASSWORD="LoadTest123!"
    NAME="Load Test User $i"
    
    RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/auth/register" \
        -H "Content-Type: application/json" \
        -d "{\"email\": \"$EMAIL\", \"password\": \"$PASSWORD\", \"name\": \"$NAME\"}")
    
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    
    if [ "$HTTP_CODE" = "201" ] || [ "$HTTP_CODE" = "200" ]; then
        echo "  Created user $i: $EMAIL"
    elif [ "$HTTP_CODE" = "409" ]; then
        echo "  User $i already exists: $EMAIL"
    else
        echo "  Failed to create user $i: HTTP $HTTP_CODE"
    fi
    
    # Small delay to avoid overwhelming the server
    if [ $((i % 10)) -eq 0 ]; then
        sleep 0.1
    fi
done

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Run the load test with:"
echo "  k6 run tests/load/virus_scan_load.js"
echo ""
echo "Quick test (100 VUs for 1 minute):"
echo "  k6 run --vus 100 --duration 1m tests/load/virus_scan_load.js"
echo ""
echo "Full stress test (1000 VUs):"
echo "  k6 run tests/load/virus_scan_load.js"
echo ""
echo "With custom base URL:"
echo "  k6 run --env BASE_URL=http://your-server:8080 tests/load/virus_scan_load.js"



