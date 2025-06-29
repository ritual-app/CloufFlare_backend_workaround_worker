# DNS Migration Plan: Grey Cloud → Proxied Mode

## Overview
Switch `ritualx-dev.ritual-app.co` from DNS-only (grey cloud) to Proxied mode (orange cloud) to enable Cloudflare Worker routing.

## Prerequisites Checklist
- [ ] Lower DNS TTL to 300 seconds (5 minutes before migration)
- [ ] Verify Cloudflare Universal SSL covers `ritualx-dev.ritual-app.co`
- [ ] Test worker functionality on direct URL
- [ ] Set up monitoring alerts for the domain
- [ ] Document current GCP CDN configuration
- [ ] Prepare communication for stakeholders

## Migration Phases

### Phase 1: Preparation (30 minutes before)
1. **Lower DNS TTL**
   ```
   In Cloudflare Dashboard:
   DNS → ritualx-dev.ritual-app.co → Edit → TTL: 5 minutes
   Wait 30 minutes for TTL to propagate
   ```

2. **Verify SSL Coverage**
   ```bash
   curl -I https://ritualx-dev.ritual-app.co
   # Verify SSL certificate is valid
   ```

3. **Test Worker Functionality**
   ```bash
   curl https://routing-backend.ritual-co.workers.dev/worker-health
   # Should return: {"status":"healthy"...}
   ```

4. **Set Up Monitoring**
   - Monitor `ritualx-dev.ritual-app.co` availability
   - Set up alerts for 5xx errors
   - Prepare to check CORS functionality

### Phase 2: DNS Switch (2-3 minutes)
1. **Switch to Proxied Mode**
   ```
   Cloudflare Dashboard → DNS → ritualx-dev.ritual-app.co
   Click grey cloud → Change to orange cloud (Proxied)
   Save changes
   ```

2. **Immediate Verification (within 30 seconds)**
   ```bash
   # Test worker health check
   curl https://ritualx-dev.ritual-app.co/worker-health
   
   # Test backend routing
   curl https://ritualx-dev.ritual-app.co/backend/health_check
   
   # Test main site still works
   curl -I https://ritualx-dev.ritual-app.co/
   ```

### Phase 3: Validation (5-10 minutes)
1. **Functional Testing**
   ```bash
   # Test routing works
   curl https://ritualx-dev.ritual-app.co/backend/v1/experts/
   # Should return 401 from Django backend
   
   # Test main site unchanged
   curl https://ritualx-dev.ritual-app.co/
   # Should return RitualX HTML
   
   # Test worker health
   curl https://ritualx-dev.ritual-app.co/worker-health
   # Should return worker status JSON
   ```

2. **CORS Testing**
   - Test any frontend CORS requests
   - Verify API endpoints work from browser
   - Check OPTIONS requests work correctly

3. **SSL/TLS Verification**
   ```bash
   # Check SSL certificate chain
   openssl s_client -connect ritualx-dev.ritual-app.co:443 -servername ritualx-dev.ritual-app.co
   ```

### Phase 4: Monitoring (24 hours)
1. **Continuous Monitoring**
   - Watch for 5xx errors
   - Monitor response times
   - Check for any CORS issues
   - Verify SSL certificate renewals

2. **Performance Validation**
   - Compare response times before/after
   - Check cache hit rates
   - Monitor GCP CDN utilization changes

## Rollback Procedures

### Immediate Rollback (30 seconds)
**If any critical issues detected:**
```
Cloudflare Dashboard → DNS → ritualx-dev.ritual-app.co
Click orange cloud → Change to grey cloud (DNS only)
Save changes
```

### Emergency Rollback Options
1. **DNS Rollback**: Switch back to grey cloud
2. **Worker Disable**: Set `ROUTING_ENABLED=false`
3. **Worker Rollback**: Deploy previous version
4. **Complete Bypass**: Remove route pattern temporarily

## Risk Assessment

### High Risk Issues
- **SSL Handshake Failures**: 525 errors
- **CORS Breaking**: Frontend API calls fail
- **Performance Degradation**: Slow response times
- **Cache Conflicts**: Stale content served

### Medium Risk Issues
- **Header Changes**: Custom headers modified
- **Compression Issues**: Content encoding problems
- **Analytics Disruption**: Tracking code issues

### Low Risk Issues
- **Minor Latency**: Slight response time changes
- **Cache Invalidation**: Need to purge caches
- **Monitoring Adjustments**: Update monitoring rules

## Success Criteria
- [ ] Worker health check responds correctly
- [ ] Backend routing works (returns 401 from Django)
- [ ] Main site functionality unchanged
- [ ] CORS requests work properly
- [ ] SSL certificate valid and secure
- [ ] No 5xx errors in logs
- [ ] Response times within acceptable range

## Emergency Contacts
- **Cloudflare Support**: [Support portal]
- **Team Lead**: [Contact info]
- **DevOps Team**: [Contact info]

## Post-Migration Tasks
- [ ] Update monitoring dashboards
- [ ] Document lessons learned
- [ ] Update runbooks
- [ ] Schedule performance review
- [ ] Plan for production migration (if applicable)

## Expected Downtime
- **Planned**: 0 seconds (seamless switch)
- **Actual**: 30-60 seconds for DNS propagation
- **Rollback Time**: 30 seconds (if needed)

## Timeline
```
T-30 min: Lower TTL, prepare monitoring
T-0 min:  Switch to proxied mode
T+1 min:  Verify basic functionality
T+5 min:  Complete validation testing
T+1 hour: Monitor for issues
T+24 hr:  Performance review
```