# Cloudflare Worker Routing Project

## Objective
Implement a Cloudflare Worker to route requests from `ritualx-dev.ritual-app.co/backend/*` to `management-dev.ritual-app.co/*` while preserving all other functionality.

## Current Status
- ✅ Worker code implemented with full routing logic
- ✅ Health check endpoint (`/worker-health`) added
- ✅ Rollback mechanisms implemented
- ✅ Worker deployed to Cloudflare
- ✅ DNS routing ACTIVE (domain uses proxied mode)
- ✅ CANARY rollout mechanism implemented
- ✅ Backend routing working: `/backend/*` → `management-dev.ritual-app.co`

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
- **Worker Name**: `routing-backend`
- **Current Version**: `8a147818-1e4f-447a-a44b-1080ea3ef64e`

### Environment Variables (✅ CONFIGURED)
- **`ROUTING_ENABLED`**: `true` - Master toggle for all routing
- **`CANARY_PERCENT`**: `0` - Percentage of `/backend/*` traffic to route (safe start)

**Control Commands**:
```bash
# Check current variables
CLOUDFLARE_ACCOUNT_ID=19c2ad706ef9998b3c6d9a2acc68a1fd wrangler secret list

# Change canary percentage (0=no routing, 100=full routing)
echo "25" | CLOUDFLARE_ACCOUNT_ID=19c2ad706ef9998b3c6d9a2acc68a1fd wrangler secret put CANARY_PERCENT --env=""

# Emergency disable
echo "false" | CLOUDFLARE_ACCOUNT_ID=19c2ad706ef9998b3c6d9a2acc68a1fd wrangler secret put ROUTING_ENABLED --env=""
```

### Route Configuration
- **Pattern**: `ritualx-dev.ritual-app.co/backend/*`
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
# Deploy worker
CLOUDFLARE_ACCOUNT_ID=19c2ad706ef9998b3c6d9a2acc68a1fd wrangler deploy

# Check deployments
CLOUDFLARE_ACCOUNT_ID=19c2ad706ef9998b3c6d9a2acc68a1fd wrangler deployments list

# Rollback if needed
CLOUDFLARE_ACCOUNT_ID=19c2ad706ef9998b3c6d9a2acc68a1fd wrangler rollback

# Update triggers
CLOUDFLARE_ACCOUNT_ID=19c2ad706ef9998b3c6d9a2acc68a1fd wrangler triggers deploy
```

## Testing URLs
- **Worker Health**: `https://routing-backend.ritual-co.workers.dev/worker-health`
- **Target Route**: `https://ritualx-dev.ritual-app.co/backend/health_check` (not active yet)
- **Health Check**: `https://ritualx-dev.ritual-app.co/worker-health` (not active yet)