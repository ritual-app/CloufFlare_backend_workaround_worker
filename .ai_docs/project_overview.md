# Cloudflare Worker Routing Project

## Objective
Implement a Cloudflare Worker to route requests from `ritualx-dev.ritual-app.co/backend/*` to `management-dev.ritual-app.co/*` while preserving all other functionality.

## Current Status
- ✅ Worker code implemented with full routing logic
- ✅ Health check endpoint (`/worker-health`) added  
- ✅ Rollback mechanisms implemented
- ✅ Worker deployed to Cloudflare (dev environment)
- ✅ DNS routing ACTIVE (domain uses proxied mode)
- ✅ CANARY rollout mechanism implemented and tested
- ✅ Backend routing WORKING: `/backend/*` → `management-dev.ritual-app.co`
- ✅ Analytics Engine integration with environment-specific datasets
- ✅ Multi-environment configuration (dev/prod) with explicit declarations

## Architecture

### Current Setup (ACTIVE)
```
Client → Cloudflare Proxy → Worker → {
  /backend/* → [CANARY %] → management-dev.ritual-app.co
  /worker-health → Worker health status
  everything else → Pass through → ritualx-dev app
}
```

### Previous Setup
```
Client → DNS (grey cloud) → GCP CDN (34.160.18.209) → ritualx-dev app
```

## Routing Rules
- `https://ritualx-dev.ritual-app.co/backend/v1/experts/` → `https://management-dev.ritual-app.co/v1/experts/`
- `https://ritualx-dev.ritual-app.co/backend/health_check` → `https://management-dev.ritual-app.co/health_check`
- `https://ritualx-dev.ritual-app.co/worker-health` → Worker health status (JSON)
- All other paths → Pass through unchanged

## Rollback Mechanisms
1. **Environment Variable**: Set `ROUTING_ENABLED=false` in Cloudflare dashboard
2. **DNS Rollback**: Switch DNS record back to grey cloud (30 seconds)
3. **Worker Rollback**: `wrangler rollback` to previous version
4. **Upstream Fallback**: Automatic fallback on network errors

## Backend Validation
- ✅ `management-dev.ritual-app.co/health_check` → `{}` (working)
- ✅ `management-dev.ritual-app.co/v1/experts/` → 401 (auth required, reachable)
- Note: 4xx responses are expected (auth/permissions) - focus on successful routing

## Worker Configuration
- **Account ID**: `19c2ad706ef9998b3c6d9a2acc68a1fd`
- **Zone ID**: `3e2ce72324e38b61ff1b83501f47d6d1`
- **Worker Name**: `routing-backend-dev` (dev environment)
- **Current Version**: `aebc7673-7fbc-437e-bd7c-99413380f065`

### Environment Variables (✅ CONFIGURED)
- **`ROUTING_ENABLED`**: `true` - Master toggle for all routing
- **`CANARY_PERCENT`**: `50` - Percentage of `/backend/*` traffic to route (currently testing)

**Control Commands**:
```bash
# Check current variables
CLOUDFLARE_ACCOUNT_ID=19c2ad706ef9998b3c6d9a2acc68a1fd wrangler secret list --env dev

# Change canary percentage (0=no routing, 100=full routing)
npm run canary:0   # Disable routing
npm run canary:50  # 50% traffic
npm run canary:100 # Full routing

# Emergency disable
echo "false" | CLOUDFLARE_ACCOUNT_ID=19c2ad706ef9998b3c6d9a2acc68a1fd wrangler secret put ROUTING_ENABLED --env dev
```

### Route Configuration
- **Patterns**: 
  - `ritualx-dev.ritual-app.co/backend/*` (routing requests)
  - `ritualx-dev.ritual-app.co/worker-health` (health endpoint)
- **Zone**: `ritual-app.co` 
- **Type**: Worker Route (triggers worker for matching requests)

### Page Rules (✅ CONFIGURED)
- **URL**: `ritualx-dev.ritual-app.co/*`
- **Setting**: Cache Level = Bypass
- **Purpose**: Ensures worker receives traffic (not bypassed by caching)
- **Critical**: Required for worker to activate and receive requests

### Triggers
- **Route Pattern**: Automatically triggers worker for `/backend/*` paths
- **Health Check**: `/worker-health` always triggers worker regardless of canary
- **Fallback**: Non-matching paths pass through unchanged

## Deployment Commands
```bash
# Deploy to dev environment (current)
npm run deploy:dev

# Deploy to production (future)
npm run deploy:prod

# Check deployments
CLOUDFLARE_ACCOUNT_ID=19c2ad706ef9998b3c6d9a2acc68a1fd wrangler deployments list --env dev

# Rollback if needed
CLOUDFLARE_ACCOUNT_ID=19c2ad706ef9998b3c6d9a2acc68a1fd wrangler rollback --env dev
```

## Analytics & Monitoring

### Analytics Engine Integration (✅ ACTIVE)
- **Dev Dataset**: `routing_metrics_dev` 
- **Prod Dataset**: `routing_metrics_prod` (ready for production)
- **Binding**: `ANALYTICS` (available in worker code)

### Data Collection
The worker automatically logs:
- ✅ Health check events
- ✅ Routing decisions (routed vs pass-through)
- ✅ Error events and fallbacks
- ✅ Response times and performance metrics
- ✅ User location data (country, CF-Ray)

### Monitoring Queries
Access via **Cloudflare Dashboard → Workers & Pages → routing-backend-dev → Analytics**:

**Quick Status Check** (copy/paste into dashboard):
```sql
SELECT 
  event_type,
  COUNT(*) as count
FROM routing_metrics_dev 
WHERE timestamp > now() - INTERVAL '10' MINUTE
GROUP BY event_type
ORDER BY count DESC;
```

**Canary Distribution** (copy/paste into dashboard):
```sql
SELECT 
  routed,
  COUNT(*) as requests
FROM routing_metrics_dev 
WHERE event_type = 'routing_decision' 
  AND path LIKE '/backend%'
  AND timestamp > now() - INTERVAL '10' MINUTE
GROUP BY routed;
```

**Recent Activity** (copy/paste into dashboard):
```sql
SELECT 
  timestamp,
  event_type,
  path,
  routed,
  response_status
FROM routing_metrics_dev 
WHERE timestamp > now() - INTERVAL '10' MINUTE
ORDER BY timestamp DESC
LIMIT 20;
```

**Error Monitoring** (copy/paste into dashboard):
```sql
SELECT 
  COUNT(*) as total_errors,
  AVG(response_time_ms) as avg_response_time
FROM routing_metrics_dev 
WHERE event_type = 'error'
  AND timestamp > now() - INTERVAL '1' HOUR;
```

## Cloudflare Alerts → Slack Integration

### Setup Instructions
1. **Go to Cloudflare Dashboard** → Notifications → Create
2. **Select Alert Types** (configure all below)
3. **Add Slack Webhook** → Connect your Slack workspace

### Critical Alerts to Configure

**1. Worker Health Alert**
- **Type**: Custom Event → Analytics Engine Query
- **Query**: 
  ```sql
  SELECT COUNT(*) as errors FROM routing_metrics_dev 
  WHERE event_type = 'error' AND timestamp > now() - INTERVAL '5' MINUTE
  ```
- **Threshold**: `errors > 5` 
- **Slack Message**: `🚨 CRITICAL: routing-backend-dev worker errors detected`

**2. Backend Failure Alert**  
- **Type**: Custom Event → Analytics Engine Query
- **Query**:
  ```sql
  SELECT COUNT(*) as fallbacks FROM routing_metrics_dev 
  WHERE event_type = 'fallback' AND timestamp > now() - INTERVAL '5' MINUTE
  ```
- **Threshold**: `fallbacks > 3`
- **Slack Message**: `🔥 CRITICAL: Backend management-dev.ritual-app.co unreachable`

**3. High Error Rate Alert**
- **Type**: Custom Event → Analytics Engine Query  
- **Query**:
  ```sql
  SELECT 
    SUM(CASE WHEN response_status >= 500 THEN 1 ELSE 0 END) * 100.0 / COUNT(*) as error_rate
  FROM routing_metrics_dev 
  WHERE routed = true AND timestamp > now() - INTERVAL '5' MINUTE
  ```
- **Threshold**: `error_rate > 10`
- **Slack Message**: `⚠️ HIGH: 5xx error rate above 10% in routing-backend-dev`

**4. Worker Route Failure**
- **Type**: Zone Alert → Workers → Script Error Rate
- **Worker**: `routing-backend-dev`
- **Threshold**: `> 5%` error rate in 5 minutes
- **Slack Message**: `🚨 Worker routing-backend-dev script errors detected`

## Testing URLs
- **Worker Health**: `https://ritualx-dev.ritual-app.co/worker-health` ✅ ACTIVE
- **Backend Route**: `https://ritualx-dev.ritual-app.co/backend/health_check` ✅ ACTIVE  
- **Backend API**: `https://ritualx-dev.ritual-app.co/backend/v1/experts/` ✅ ACTIVE
- **Canary Test**: Run `npm run canary:test` to verify distribution

## Current Test Results
```json
{
  "status": "healthy",
  "environment": "dev", 
  "routing_enabled": true,
  "canary_percent": 50,
  "backend_healthy": true,
  "backend_response_time_ms": 272,
  "worker_response_time_ms": 272,
  "timestamp": "2025-06-29T13:51:10.241Z",
  "worker_version": "1.0.0"
}
```

## Production Readiness Checklist
- ✅ Dev environment fully functional
- ✅ Analytics Engine configured for both environments  
- ✅ Multi-environment wrangler configuration
- ✅ Canary deployment mechanism tested
- ✅ Error handling and fallback mechanisms
- ✅ Health monitoring endpoints
- ✅ Simple SQL queries ready for dashboard monitoring
- 🔄 **Waiting for production deployment approval**

## Next Steps
1. **Monitor dev environment** using the SQL queries above
2. **Deploy to production** when ready: `npm run deploy:prod`
3. **Production monitoring** will use `routing_metrics_prod` dataset
4. **Update DNS** for `ritualx.ritual-app.co` (production domain)