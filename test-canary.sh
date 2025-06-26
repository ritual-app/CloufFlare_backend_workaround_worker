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

# Interpretation
echo "=== INTERPRETATION ==="
if [ $django_percent -ge 45 ] && [ $django_percent -le 55 ]; then
  echo "✅ CANARY ~50%: Distribution looks correct for 50% canary"
elif [ $django_percent -le 10 ]; then
  echo "✅ CANARY ~0%: Most traffic passing through (low/no routing)"
elif [ $django_percent -ge 90 ]; then
  echo "✅ CANARY ~100%: Most traffic routing to Django backend"
else
  echo "⚠️  CANARY $django_percent%: Verify if this matches your expected CANARY_PERCENT setting"
fi

echo ""
echo "Expected behavior:"
echo "- CANARY_PERCENT=0:   ~0% Django, ~100% Frontend"
echo "- CANARY_PERCENT=50:  ~50% Django, ~50% Frontend"  
echo "- CANARY_PERCENT=100: ~100% Django, ~0% Frontend"