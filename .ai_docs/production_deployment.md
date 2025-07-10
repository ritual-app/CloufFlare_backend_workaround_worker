# Production Deployment Plan

## Overview
Deploy the routing worker to production domain `ritualx.ritual-app.co` (without `-dev`).

## Configuration Changes

### Production vs Development
- **Dev**: `ritualx-dev.ritual-app.co/backend/*` → `management-dev.ritual-app.co/*`
- **Prod**: `ritualx.ritual-app.co/backend/*` → `management.ritual-app.co/*`

### Worker Configuration
The worker automatically detects environment based on hostname:
```typescript
const backendDomain = url.hostname.includes('-dev') ? 
  'management-dev.ritual-app.co' : 
  'management.ritual-app.co';
```

## Deployment Steps

### 1. Verify Production Backend
```bash
# Test production backend connectivity
curl -I https://management.ritual-app.co/health_check

# Test production API endpoint
curl https://management.ritual-app.co/v1/experts/
# Should return 401 (auth required) or API response
```

### 2. Deploy to Production Environment
```bash
# Deploy to production environment
npm run deploy:prod

# Verify deployment
wrangler deployments list --env production
```

### 3. DNS Configuration
**Critical**: Production domain must be set to **orange cloud** (proxied mode) in Cloudflare DNS.

```
Cloudflare Dashboard → DNS → ritualx.ritual-app.co
- Current: Grey cloud (DNS only) 
- Required: Orange cloud (Proxied)
```

### 4. Environment Variables
Set using npm scripts for production environment:
```bash
npm run enable:prod       # Set ROUTING_ENABLED=true
npm run canary:prod:0     # Set CANARY_PERCENT=0 (gradual rollout)
```

## Production Testing

### 1. Pre-Deployment Verification
```bash
# Health check (should work regardless of routing)
npm run health:prod

# Backend routing test (with CANARY_PERCENT=0, should pass through)
curl https://ritualx.ritual-app.co/backend/health_check
# Should return RitualX frontend (not Django)

# Main site (should be unchanged)
curl https://ritualx.ritual-app.co/
# Should return RitualX application
```

### 2. Gradual Rollout
```bash
# Step 1: 0% canary (no routing impact)
npm run canary:prod:0

# Step 2: 5% canary (low risk testing)
npm run canary:prod:5

# Step 3: 25% canary (moderate testing)
npm run canary:prod:25

# Step 4: 100% canary (full migration)
npm run canary:prod:100
```

### 3. Monitoring During Rollout
```bash
# Critical health check (should always work)
npm run health:prod

# Live production dashboard
npm run dashboard:prod

# Check environment variables
npm run vars:prod
```

## Rollback Procedures

### 1. Immediate Rollback (Emergency)
```bash
# Option 1: Disable routing completely
npm run disable:prod

# Option 2: DNS rollback (fastest)
# Change ritualx.ritual-app.co to grey cloud (DNS only)

# Option 3: Canary rollback
npm run canary:prod:0
```

### 2. Worker Rollback
```bash
# Rollback to previous worker version
wrangler rollback --env production
```

## Production Routes Configuration

**wrangler.jsonc**:
```json
{
  "env": {
    "production": {
      "routes": [
        { "pattern": "ritualx.ritual-app.co/backend/*", "zone_name": "ritual-app.co" }
      ]
    }
  }
}
```

## Success Criteria

### 1. Zero Impact Deployment
- Main RitualX site continues to work normally
- No 5xx errors or downtime
- Worker health endpoint responds correctly

### 2. Routing Functionality
- `/backend/*` requests route correctly based on CANARY_PERCENT
- Health checks work for both dev and prod environments
- Error handling and fallbacks function properly

### 3. Monitoring
- Worker health endpoint accessible
- Error tracking working
- Canary mechanism controllable via environment variables

## Production Environment Differences

### 1. Backend Endpoints
- **Dev**: `management-dev.ritual-app.co`
- **Prod**: `management.ritual-app.co`

### 2. Domain Configuration
- **Dev**: `ritualx-dev.ritual-app.co` (already proxied)
- **Prod**: `ritualx.ritual-app.co` (needs to be proxied)

### 3. Traffic Volume
- **Dev**: Low traffic, testing environment
- **Prod**: High traffic, business critical

## Risk Assessment

### High Risk
- DNS change for production domain
- Traffic routing to new backend
- Potential impact on live users

### Mitigation
- Start with CANARY_PERCENT=0 (no impact)
- Gradual rollout with monitoring
- Multiple rollback options available
- Comprehensive health checks

### Low Risk
- Worker deployment (no immediate impact)
- Environment variable changes
- Health endpoint additions

## Timeline

### Phase 1: Preparation (30 minutes)
1. Verify production backend connectivity
2. Test worker deployment in production mode
3. Prepare monitoring and alerting

### Phase 2: Deployment (15 minutes)
1. Deploy worker to production environment
2. Set environment variables (ROUTING_ENABLED=true, CANARY_PERCENT=0)
3. Change DNS to proxied mode

### Phase 3: Verification (15 minutes)
1. Test worker health endpoint
2. Verify main site functionality
3. Confirm routing passthrough behavior

### Phase 4: Gradual Rollout (Hours/Days)
1. Increase CANARY_PERCENT gradually (5% → 25% → 100%)
2. Monitor at each step for issues
3. Complete migration when confident

## Emergency Contacts
- **On-call engineer**: [Contact info]
- **Backend team**: [Contact info]
- **DevOps team**: [Contact info]

## Prerequisites Checklist
- [ ] Production backend (`management.ritual-app.co`) is accessible
- [ ] Cloudflare account has proper permissions
- [ ] Monitoring alerts are configured
- [ ] Team is aware of deployment window
- [ ] Rollback procedures tested and ready