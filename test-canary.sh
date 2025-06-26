#!/bin/bash

# Canary Verification Script
# Tests CANARY_PERCENT distribution for routing worker

echo "=== CANARY VERIFICATION SCRIPT ==="
echo ""

# Configuration
URL="https://ritualx-dev.ritual-app.co/backend/health_check"
REQUESTS=20

echo "Testing URL: $URL"
echo "Number of requests: $REQUESTS"
echo ""

# Counters
django_count=0
frontend_count=0
other_count=0

echo "Running $REQUESTS requests..."
echo "D = Django (HTTP 200), F = Frontend (HTTP 404), ? = Other"
echo ""

for i in $(seq 1 $REQUESTS); do
  http_status=$(curl -s -w "%{http_code}" -o /dev/null "$URL")
  
  if [ "$http_status" = "200" ]; then
    echo -n "D"  # Django (routed to backend)
    ((django_count++))
  elif [ "$http_status" = "404" ]; then
    echo -n "F"  # Frontend (pass-through)
    ((frontend_count++))
  else
    echo -n "?"  # Other
    ((other_count++))
  fi
done

echo ""
echo ""

# Calculate percentages
django_percent=$((django_count * 100 / REQUESTS))
frontend_percent=$((frontend_count * 100 / REQUESTS))
other_percent=$((other_count * 100 / REQUESTS))

echo "=== RESULTS ==="
echo "Django (routed):     $django_count/$REQUESTS ($django_percent%)"
echo "Frontend (pass-through): $frontend_count/$REQUESTS ($frontend_percent%)"
echo "Other responses:     $other_count/$REQUESTS ($other_percent%)"
echo ""

# Get current canary setting
echo "=== CURRENT CONFIGURATION ==="
echo "Worker health:"
curl -s https://ritualx-dev.ritual-app.co/worker-health | jq . 2>/dev/null || curl -s https://ritualx-dev.ritual-app.co/worker-health
echo ""

echo "Environment variables:"
CLOUDFLARE_ACCOUNT_ID=19c2ad706ef9998b3c6d9a2acc68a1fd wrangler secret list 2>/dev/null || echo "Unable to fetch (wrangler not available)"
echo ""

# Get expected canary from health endpoint
echo "=== PASS/FAIL ANALYSIS ==="
expected_canary=$(curl -s https://ritualx-dev.ritual-app.co/worker-health | grep -o '"canary_percent":[0-9]*' | cut -d: -f2 2>/dev/null || echo "unknown")

if [ "$expected_canary" != "unknown" ]; then
  echo "Expected CANARY_PERCENT: $expected_canary%"
  echo "Actual Django routing: $django_percent%"
  
  # Allow ±15% tolerance for randomness
  tolerance=15
  lower_bound=$((expected_canary - tolerance))
  upper_bound=$((expected_canary + tolerance))
  
  if [ $django_percent -ge $lower_bound ] && [ $django_percent -le $upper_bound ]; then
    echo ""
    echo "🎯 PASS: Canary distribution within expected range ($lower_bound%-$upper_bound%)"
    exit 0
  else
    echo ""
    echo "❌ FAIL: Canary distribution outside expected range ($lower_bound%-$upper_bound%)"
    exit 1
  fi
else
  echo "⚠️  Cannot determine expected canary percentage from health endpoint"
  echo ""
  echo "Manual verification:"
  echo "- CANARY_PERCENT=0:   Expected ~0-15% Django"
  echo "- CANARY_PERCENT=50:  Expected ~35-65% Django"  
  echo "- CANARY_PERCENT=100: Expected ~85-100% Django"
fi