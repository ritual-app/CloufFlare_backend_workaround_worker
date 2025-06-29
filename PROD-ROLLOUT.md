# Production Rollout Steps

## Quick Production Deployment

### 1. Pre-flight Check (2 mins)
```bash
# Verify production backend is accessible
curl -I https://management.ritual-app.co/health_check

# Current dev system working?
npm run canary:test
```

### 2. Deploy to Production (1 min)
```bash
# Deploy worker to production environment
npm run deploy:prod

# Set production environment variables
echo "true" | CLOUDFLARE_ACCOUNT_ID=19c2ad706ef9998b3c6d9a2acc68a1fd wrangler secret put ROUTING_ENABLED --env=production
echo "0" | CLOUDFLARE_ACCOUNT_ID=19c2ad706ef9998b3c6d9a2acc68a1fd wrangler secret put CANARY_PERCENT --env=production
```

### 3. DNS Switch + Page Rule (30 seconds)
```
Cloudflare Dashboard → DNS → ritualx.ritual-app.co
Change from grey cloud (DNS only) to orange cloud (Proxied)
```

**⚠️ IMPORTANT**: Add Page Rule to activate worker:
```
Cloudflare Dashboard → Rules → Page Rules
URL: ritualx.ritual-app.co/*
Setting: Cache Level = Bypass
```
*This ensures the worker receives traffic and isn't bypassed by caching.*

### 4. Verify (2 mins)
```bash
# Health check should work
curl https://ritualx.ritual-app.co/worker-health

# Backend requests should pass through (CANARY=0)
curl https://ritualx.ritual-app.co/backend/health_check
# Should return 404 from RitualX (not routing yet)

# Main site should be unchanged
curl https://ritualx.ritual-app.co/
```

### 5. Gradual Rollout (Optional)
```bash
# When ready, gradually increase routing
echo "25" | CLOUDFLARE_ACCOUNT_ID=19c2ad706ef9998b3c6d9a2acc68a1fd wrangler secret put CANARY_PERCENT --env=production
echo "50" | CLOUDFLARE_ACCOUNT_ID=19c2ad706ef9998b3c6d9a2acc68a1fd wrangler secret put CANARY_PERCENT --env=production  
echo "100" | CLOUDFLARE_ACCOUNT_ID=19c2ad706ef9998b3c6d9a2acc68a1fd wrangler secret put CANARY_PERCENT --env=production
```

## Emergency Rollback
```bash
# Option 1: Disable routing
echo "false" | CLOUDFLARE_ACCOUNT_ID=19c2ad706ef9998b3c6d9a2acc68a1fd wrangler secret put ROUTING_ENABLED --env=production

# Option 2: DNS rollback (fastest)
# Cloudflare Dashboard → DNS → Change to grey cloud
```

## Key Differences: Dev vs Prod
- **Dev**: `ritualx-dev.ritual-app.co/backend/*` → `management-dev.ritual-app.co/*`
- **Prod**: `ritualx.ritual-app.co/backend/*` → `management.ritual-app.co/*`

Worker automatically detects environment based on hostname.