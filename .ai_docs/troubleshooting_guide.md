# Troubleshooting Guide

## Common Issues and Solutions

### 1. Worker Not Intercepting Requests

**Symptoms:**
- `curl https://ritualx-dev.ritual-app.co/worker-health` returns HTML instead of JSON
- Backend routing not working
- Domain still serves original content

**Diagnosis:**
```bash
# Check if domain is proxied
dig ritualx-dev.ritual-app.co
# Should return Cloudflare IPs, not GCP IPs (34.160.18.209)

# Check worker deployment
CLOUDFLARE_ACCOUNT_ID=19c2ad706ef9998b3c6d9a2acc68a1fd wrangler deployments list

# Test worker directly
curl https://routing-backend.ritual-co.workers.dev/worker-health
```

**Solutions:**
1. Ensure DNS record is orange cloud (proxied), not grey cloud
2. Wait for DNS propagation (up to 5 minutes)
3. Redeploy triggers: `wrangler triggers deploy`
4. Verify zone ID matches in `wrangler.toml`

### 2. SSL Certificate Errors (525 Errors)

**Symptoms:**
- "SSL handshake failed" errors
- Browser shows certificate warnings
- 525 error from Cloudflare

**Diagnosis:**
```bash
# Check SSL certificate
curl -I https://ritualx-dev.ritual-app.co

# Verify certificate chain
openssl s_client -connect ritualx-dev.ritual-app.co:443 -servername ritualx-dev.ritual-app.co
```

**Solutions:**
1. Wait for Cloudflare Universal SSL provisioning (up to 24 hours)
2. Check SSL/TLS settings in Cloudflare dashboard
3. Ensure origin server supports SNI
4. Consider using Full (strict) SSL mode

### 3. CORS Issues

**Symptoms:**
- Browser console shows CORS errors
- Preflight OPTIONS requests fail
- API calls from frontend fail

**Diagnosis:**
```bash
# Test OPTIONS request
curl -X OPTIONS -H "Origin: https://example.com" https://ritualx-dev.ritual-app.co/backend/v1/experts/

# Check CORS headers
curl -H "Origin: https://example.com" -I https://ritualx-dev.ritual-app.co/backend/v1/experts/
```

**Solutions:**
1. Update worker to preserve CORS headers
2. Configure Cloudflare to not cache OPTIONS responses
3. Add CORS headers in worker response
4. Check origin server CORS configuration

### 4. Backend Routing Fails

**Symptoms:**
- `/backend/*` requests return 5xx errors
- Upstream connection failures
- Requests not reaching Django backend

**Diagnosis:**
```bash
# Test direct backend access
curl -I https://management-dev.ritual-app.co/health_check

# Check worker logs (if available)
wrangler tail routing-backend

# Test specific endpoints
curl https://ritualx-dev.ritual-app.co/backend/health_check
curl https://ritualx-dev.ritual-app.co/backend/v1/experts/
```

**Solutions:**
1. Verify Django backend is accessible
2. Check worker error handling in try-catch blocks
3. Verify network connectivity from Cloudflare to backend
4. Test worker fallback mechanism

### 5. Performance Issues

**Symptoms:**
- Slow response times
- Timeouts
- High latency

**Diagnosis:**
```bash
# Test response times
time curl https://ritualx-dev.ritual-app.co/
time curl https://ritualx-dev.ritual-app.co/backend/health_check

# Compare with direct backend
time curl https://management-dev.ritual-app.co/health_check
```

**Solutions:**
1. Optimize worker code
2. Configure Cloudflare caching rules
3. Check for double CDN conflicts
4. Monitor Cloudflare Analytics

### 6. Cache Issues

**Symptoms:**
- Stale content served
- Changes not reflecting
- Inconsistent responses

**Diagnosis:**
```bash
# Check cache headers
curl -I https://ritualx-dev.ritual-app.co/

# Test with cache bypass
curl -H "Cache-Control: no-cache" https://ritualx-dev.ritual-app.co/
```

**Solutions:**
1. Purge Cloudflare cache
2. Configure appropriate cache rules
3. Set proper cache headers in worker
4. Use Development Mode for testing

## Emergency Procedures

### Immediate Rollback
```bash
# 1. Switch DNS back to grey cloud (DNS only)
# Go to Cloudflare Dashboard → DNS → ritualx-dev.ritual-app.co → Click orange cloud → Grey cloud

# 2. OR disable routing via environment variable
# Go to Cloudflare Dashboard → Workers → routing-backend → Settings → Environment Variables
# Add: ROUTING_ENABLED = false

# 3. OR rollback worker version
CLOUDFLARE_ACCOUNT_ID=19c2ad706ef9998b3c6d9a2acc68a1fd wrangler rollback
```

### Health Check Commands
```bash
# Quick health check
curl -s https://ritualx-dev.ritual-app.co/worker-health | jq .

# Full functionality test
curl -I https://ritualx-dev.ritual-app.co/
curl -I https://ritualx-dev.ritual-app.co/backend/health_check
curl -I https://ritualx-dev.ritual-app.co/backend/v1/experts/
```

### Monitoring Commands
```bash
# Check current deployment
CLOUDFLARE_ACCOUNT_ID=19c2ad706ef9998b3c6d9a2acc68a1fd wrangler deployments list

# Check DNS resolution
dig ritualx-dev.ritual-app.co

# Test SSL
curl -I https://ritualx-dev.ritual-app.co

# Worker direct test
curl https://routing-backend.ritual-co.workers.dev/worker-health
```

## Logging and Debugging

### Worker Logs
```bash
# Tail worker logs (real-time)
CLOUDFLARE_ACCOUNT_ID=19c2ad706ef9998b3c6d9a2acc68a1fd wrangler tail routing-backend

# Filter specific requests
CLOUDFLARE_ACCOUNT_ID=19c2ad706ef9998b3c6d9a2acc68a1fd wrangler tail routing-backend --grep "backend"
```

### Analytics
- Check Cloudflare Analytics dashboard
- Monitor response codes and error rates
- Review security events
- Check bandwidth usage

### Common Log Messages
- `"Upstream request failed, falling back"` - Backend connectivity issue
- `"routing_enabled: false"` - Routing disabled via environment variable
- `"status: healthy"` - Worker health check successful

## Contact Information
- **Primary Developer**: [Contact]
- **DevOps Team**: [Contact]
- **Cloudflare Support**: [Portal link]
- **Emergency Escalation**: [Contact]