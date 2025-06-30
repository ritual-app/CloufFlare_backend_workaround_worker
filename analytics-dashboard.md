# Analytics Dashboard Queries

Copy these queries directly into your Cloudflare Analytics dashboard to get instant visibility into your worker routing.

## 1. Real-Time Routing Overview

```sql
-- Request flow in last hour
SELECT 
  timestamp,
  route_category,
  routed,
  response_status,
  response_time_ms,
  cf_country,
  client_ip
FROM routing_metrics_dev 
WHERE timestamp > now() - INTERVAL '1' HOUR
  AND event_type = 'routing_decision'
ORDER BY timestamp DESC
LIMIT 100;
```

## 2. Canary Performance Dashboard

```sql
-- Routing vs Pass-through comparison
SELECT 
  routed,
  route_category,
  COUNT(*) as total_requests,
  AVG(response_time_ms) as avg_response_time,
  PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY response_time_ms) as p95_response_time,
  COUNT(CASE WHEN response_status >= 400 THEN 1 END) as error_count,
  COUNT(CASE WHEN response_status >= 400 THEN 1 END) * 100.0 / COUNT(*) as error_rate_percent
FROM routing_metrics_dev 
WHERE timestamp > now() - INTERVAL '1' HOUR
  AND event_type = 'routing_decision'
GROUP BY routed, route_category
ORDER BY total_requests DESC;
```

## 3. Geographic Request Distribution

```sql
-- Traffic by country and data center
SELECT 
  cf_country,
  cf_colo,
  COUNT(*) as requests,
  AVG(response_time_ms) as avg_response_time,
  SUM(CASE WHEN routed THEN 1 ELSE 0 END) as routed_requests,
  SUM(CASE WHEN routed THEN 1 ELSE 0 END) * 100.0 / COUNT(*) as routing_percentage
FROM routing_metrics_dev 
WHERE timestamp > now() - INTERVAL '1' HOUR
  AND event_type = 'routing_decision'
GROUP BY cf_country, cf_colo
ORDER BY requests DESC
LIMIT 20;
```

## 4. Error Monitoring (Critical)

```sql
-- 5xx Error Rate (Alert if > 5%)
SELECT 
  DATE_TRUNC('minute', timestamp) as minute,
  COUNT(*) as total_requests,
  SUM(CASE WHEN response_status >= 500 THEN 1 ELSE 0 END) as server_errors,
  SUM(CASE WHEN response_status >= 500 THEN 1 ELSE 0 END) * 100.0 / COUNT(*) as error_rate_percent
FROM routing_metrics_dev 
WHERE routed = true 
  AND timestamp > now() - INTERVAL '1' HOUR
  AND event_type = 'routing_decision'
GROUP BY minute
ORDER BY minute DESC;
```

## 5. Source Tracking Analysis

```sql
-- Request sources and referrers
SELECT 
  referer,
  COUNT(*) as requests,
  COUNT(DISTINCT client_ip) as unique_ips,
  AVG(response_time_ms) as avg_response_time,
  SUM(CASE WHEN routed THEN 1 ELSE 0 END) as routed_count
FROM routing_metrics_dev 
WHERE timestamp > now() - INTERVAL '1' HOUR
  AND event_type = 'routing_decision'
  AND referer != 'direct'
GROUP BY referer
ORDER BY requests DESC
LIMIT 10;
```

## 6. Route Category Performance

```sql
-- Performance by route type
SELECT 
  route_category,
  COUNT(*) as requests,
  AVG(response_time_ms) as avg_response_time,
  PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY response_time_ms) as p95_response_time,
  COUNT(CASE WHEN response_status >= 400 THEN 1 END) as errors,
  SUM(CASE WHEN routed THEN 1 ELSE 0 END) as routed_requests
FROM routing_metrics_dev 
WHERE timestamp > now() - INTERVAL '1' HOUR
  AND event_type = 'routing_decision'
GROUP BY route_category
ORDER BY requests DESC;
```

## 7. Fallback Monitoring (Network Issues)

```sql
-- Network failures and fallback events
SELECT 
  DATE_TRUNC('minute', timestamp) as minute,
  COUNT(*) as fallback_count,
  error_message
FROM routing_metrics_dev 
WHERE event_type = 'fallback'
  AND timestamp > now() - INTERVAL '1' HOUR
GROUP BY minute, error_message
ORDER BY minute DESC;
```

## 8. Live Traffic Stream

```sql
-- Real-time request stream (refresh every 30 seconds)
SELECT 
  timestamp,
  path,
  method,
  cf_country,
  routed,
  response_status,
  response_time_ms,
  route_category
FROM routing_metrics_dev 
WHERE timestamp > now() - INTERVAL '5' MINUTE
  AND event_type = 'routing_decision'
ORDER BY timestamp DESC
LIMIT 50;
```

## Quick Health Check

```sql
-- System health summary (last 5 minutes)
SELECT 
  COUNT(*) as total_requests,
  AVG(response_time_ms) as avg_response_time,
  SUM(CASE WHEN routed THEN 1 ELSE 0 END) as routed_requests,
  SUM(CASE WHEN response_status >= 400 THEN 1 ELSE 0 END) as errors,
  SUM(CASE WHEN event_type = 'fallback' THEN 1 ELSE 0 END) as fallbacks
FROM routing_metrics_dev 
WHERE timestamp > now() - INTERVAL '5' MINUTE;
```

## Usage Instructions

1. **Access**: Go to Cloudflare Dashboard → Workers → Analytics
2. **Query**: Copy any query above and paste into the Analytics QL interface
3. **Refresh**: Most queries work best with auto-refresh every 30-60 seconds
4. **Filter**: Change `routing_metrics_dev` to `routing_metrics_prod` for production
5. **Alerts**: Set up alerts when error rates exceed thresholds

## Key Metrics to Monitor

- **Error Rate**: Should be < 5% for 5xx errors, < 20% for 4xx errors
- **Response Time**: Should be < 2s average, < 5s p95
- **Fallback Rate**: Should be < 1% (indicates backend issues)
- **Routing Distribution**: Should match your canary percentage