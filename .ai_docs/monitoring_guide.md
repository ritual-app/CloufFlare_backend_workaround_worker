# Critical Monitoring Guide

## Overview
This guide covers the comprehensive monitoring setup for the Cloudflare Worker routing system, including metrics collection, alerting, and troubleshooting procedures.

## Monitoring Components

### 1. Analytics Engine (Custom Metrics)
**Dataset**: `routing_metrics`
**Binding**: `ANALYTICS`

**Collected Metrics**:
- **Routing Decisions**: Every request routing decision with timing
- **Health Checks**: Worker and backend health status
- **Errors**: Failed requests and automatic fallbacks
- **Performance**: Response times and system performance

**Metric Fields**:
```typescript
{
  timestamp: string;           // ISO timestamp
  event_type: string;          // 'routing_decision' | 'health_check' | 'error' | 'fallback'
  path: string;               // Request path
  method: string;             // HTTP method
  routing_enabled: boolean;   // Master routing toggle status
  canary_percent: number;     // Current canary percentage
  routed: boolean;           // Whether request was routed
  response_status?: number;   // HTTP response status
  response_time_ms?: number;  // Request processing time
  error_message?: string;     // Error details (if any)
  user_agent?: string;       // Client user agent
  cf_ray?: string;           // Cloudflare Ray ID
  cf_country?: string;       // Request origin country
}
```

### 2. Enhanced Health Endpoint
**URL**: `https://ritualx-dev.ritual-app.co/worker-health`

**Response Format**:
```json
{
  "status": "healthy",
  "routing_enabled": true,
  "canary_percent": 0,
  "backend_healthy": true,
  "backend_response_time_ms": 45,
  "worker_response_time_ms": 67,
  "timestamp": "2025-06-26T08:55:42.799Z",
  "worker_version": "1.0.0"
}
```

### 3. Structured Logging
**Console Logs**: Available in Cloudflare Worker logs
**Error Tracking**: Automatic fallback scenarios and system errors

## Critical Alerts to Configure

### 1. High Priority Alerts (Page Immediately)

**Backend Failure Rate > 5%**
```sql
-- Analytics Engine Query
SELECT 
  COUNT(*) as failures
FROM routing_metrics
WHERE event_type = 'fallback'
  AND timestamp > datetime('now', '-5 minutes')
HAVING failures > 5
```

**Worker Error Rate > 1%**
```sql
SELECT 
  COUNT(*) as errors
FROM routing_metrics  
WHERE event_type = 'error'
  AND timestamp > datetime('now', '-5 minutes')
HAVING errors > 10
```

**Backend Response Time > 2 seconds**
```sql
SELECT 
  AVG(response_time_ms) as avg_response_time
FROM routing_metrics
WHERE routed = true
  AND timestamp > datetime('now', '-5 minutes')
HAVING avg_response_time > 2000
```

**Health Check Failures**
```bash
# External monitoring (curl-based)
curl -f https://ritualx-dev.ritual-app.co/worker-health || alert
```

### 2. Medium Priority Alerts (Notify Team)

**Canary Percentage Drift**
- Alert if canary percentage changes unexpectedly
- Monitor for manual intervention needs

**High Traffic Volume**
```sql
SELECT 
  COUNT(*) as request_count
FROM routing_metrics
WHERE timestamp > datetime('now', '-5 minutes')
HAVING request_count > 1000
```

**Geographic Anomalies**
- Unusual traffic patterns from specific countries
- Potential DDoS or abuse detection

### 3. Low Priority Alerts (Dashboard Only)

**Performance Degradation**
- Response times 20% above baseline
- Cache hit rate changes

**Configuration Changes**
- ROUTING_ENABLED toggled
- CANARY_PERCENT modified

## Monitoring Dashboards

### 1. Real-Time Operations Dashboard
**Key Metrics**:
- Current routing status (enabled/disabled)
- Canary percentage and traffic split
- Backend health status
- Real-time error rates
- Response time percentiles (p50, p95, p99)

### 2. Performance Dashboard
**Metrics**:
- Request volume trends
- Response time histograms
- Error rate trends
- Geographic distribution
- User agent analysis

### 3. Business Impact Dashboard
**Metrics**:
- Successful routing percentage
- Business logic routing (by endpoint)
- Feature flag impact analysis
- A/B testing results (canary effectiveness)

## Alerting Channels

### 1. Critical Alerts
- **PagerDuty**: Immediate on-call notification
- **Slack**: #alerts-critical channel
- **Email**: Operations team distribution list

### 2. Warning Alerts
- **Slack**: #monitoring channel
- **Email**: Development team

### 3. Info Alerts
- **Dashboard**: Visual indicators only
- **Slack**: #monitoring-info channel

## Troubleshooting Procedures

### 1. High Error Rate
```bash
# Check worker health
curl https://ritualx-dev.ritual-app.co/worker-health

# Check backend directly
curl https://management-dev.ritual-app.co/health_check

# Emergency disable routing
# Set ROUTING_ENABLED=false in Cloudflare dashboard
```

### 2. Backend Connectivity Issues
```bash
# Check DNS resolution
dig management-dev.ritual-app.co

# Test connectivity
curl -I https://management-dev.ritual-app.co/health_check

# Check SSL certificate
openssl s_client -connect management-dev.ritual-app.co:443
```

### 3. Performance Degradation
```bash
# Check worker metrics
curl -w "@curl-format.txt" https://ritualx-dev.ritual-app.co/worker-health

# Analyze routing patterns
# Use Analytics Engine queries to identify bottlenecks

# Consider canary rollback
# Reduce CANARY_PERCENT if backend is slow
```

## Monitoring Best Practices

### 1. Baseline Establishment
- Collect 1 week of metrics before setting alert thresholds
- Establish normal traffic patterns and response times
- Document expected error rates and fallback scenarios

### 2. Alert Fatigue Prevention
- Use appropriate alert thresholds (not too sensitive)
- Implement alert escalation (warn → critical)
- Regular alert threshold review and tuning

### 3. Incident Response
- Document all incidents and resolutions
- Maintain runbooks for common scenarios
- Post-incident reviews and monitoring improvements

## External Monitoring Integration

### 1. Synthetic Monitoring
```bash
# Continuous health checks (every 30 seconds)
curl -f https://ritualx-dev.ritual-app.co/worker-health

# Backend routing test
curl -f https://ritualx-dev.ritual-app.co/backend/health_check
```

### 2. Log Aggregation
- Export Cloudflare Worker logs to centralized logging
- Correlate with application logs from management-dev
- Set up log-based alerting for error patterns

### 3. APM Integration
- Connect to existing APM tools (New Relic, Datadog, etc.)
- Track distributed tracing across worker → backend
- Monitor business metrics and user experience

## Metrics Retention

### 1. Analytics Engine
- **Real-time**: Last 24 hours (detailed metrics)
- **Aggregated**: 30 days (hourly rollups)
- **Historical**: 1 year (daily rollups)

### 2. External Systems
- Export critical metrics to long-term storage
- Maintain historical baselines for capacity planning
- Archive incident data for compliance and analysis

## Emergency Procedures

### 1. Complete System Failure
1. Set `ROUTING_ENABLED=false` (immediate)
2. Monitor error rates decrease
3. Investigate root cause
4. Gradual re-enable with low canary percentage

### 2. Backend Outage
1. Check automatic fallback is working
2. Confirm traffic routing to original destination
3. Monitor user impact
4. Coordinate with backend team for resolution

### 3. Worker Performance Issues
1. Check Cloudflare status page
2. Review recent deployments
3. Consider worker rollback if needed
4. Scale monitoring to identify bottlenecks