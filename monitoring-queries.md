# Cloudflare Worker Analytics - SQL Monitoring Queries

This document provides comprehensive SQL queries for monitoring the routing worker using Cloudflare Analytics Engine.

## Quick Access

**Cloudflare Dashboard Access**: 
- Dev: Workers & Pages → routing-backend-dev → Analytics
- Prod: Workers & Pages → routing-backend-production → Analytics

**Datasets**:
- Dev: `routing_metrics_dev`
- Prod: `routing_metrics_prod`

---

## 📊 Real-Time Health Monitoring

### System Health Overview (Last 10 Minutes)
```sql
SELECT 
  event_type,
  COUNT(*) as count,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) as percentage
FROM routing_metrics_dev 
WHERE timestamp > now() - INTERVAL '10' MINUTE
GROUP BY event_type
ORDER BY count DESC;
```

### Worker Response Time Analysis
```sql
SELECT 
  ROUND(AVG(response_time_ms), 2) as avg_response_time,
  ROUND(MIN(response_time_ms), 2) as min_response_time,
  ROUND(MAX(response_time_ms), 2) as max_response_time,
  ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY response_time_ms), 2) as median_response_time,
  ROUND(PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY response_time_ms), 2) as p95_response_time
FROM routing_metrics_dev 
WHERE timestamp > now() - INTERVAL '1' HOUR
  AND response_time_ms > 0;
```

---

## 🚦 Traffic Routing Analysis

### Current Canary Distribution (Last 5 Minutes)
```sql
SELECT 
  routed,
  COUNT(*) as requests,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) as percentage,
  ROUND(AVG(response_time_ms), 2) as avg_response_time
FROM routing_metrics_dev 
WHERE event_type = 'routing_decision' 
  AND path LIKE '/backend%'
  AND timestamp > now() - INTERVAL '5' MINUTE
GROUP BY routed
ORDER BY routed DESC;
```

### Hourly Traffic Pattern
```sql
SELECT 
  DATE_TRUNC('hour', timestamp) as hour,
  SUM(CASE WHEN routed = true THEN 1 ELSE 0 END) as routed_requests,
  SUM(CASE WHEN routed = false THEN 1 ELSE 0 END) as passthrough_requests,
  COUNT(*) as total_requests,
  ROUND(SUM(CASE WHEN routed = true THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as routing_percentage
FROM routing_metrics_dev 
WHERE timestamp > now() - INTERVAL '24' HOUR
  AND event_type = 'routing_decision'
GROUP BY hour
ORDER BY hour DESC
LIMIT 24;
```

### Route Performance by Category
```sql
SELECT 
  route_category,
  COUNT(*) as requests,
  ROUND(AVG(response_time_ms), 2) as avg_response_time,
  ROUND(AVG(CASE WHEN routed = true THEN 1.0 ELSE 0.0 END) * 100, 2) as routing_rate,
  COUNT(DISTINCT client_ip) as unique_users
FROM routing_metrics_dev 
WHERE timestamp > now() - INTERVAL '1' HOUR
  AND route_category IS NOT NULL
GROUP BY route_category
ORDER BY requests DESC;
```

---

## ⚠️ Error Monitoring & Alerts

### Critical Error Summary (Last 30 Minutes)
```sql
SELECT 
  'Server Errors (5xx)' as error_type,
  COUNT(*) as error_count,
  ROUND(COUNT(*) * 100.0 / (
    SELECT COUNT(*) FROM routing_metrics_dev 
    WHERE routed = true AND timestamp > now() - INTERVAL '30' MINUTE
  ), 2) as error_rate_percent
FROM routing_metrics_dev 
WHERE response_status >= 500 
  AND routed = true
  AND timestamp > now() - INTERVAL '30' MINUTE

UNION ALL

SELECT 
  'Client Errors (4xx)' as error_type,
  COUNT(*) as error_count,
  ROUND(COUNT(*) * 100.0 / (
    SELECT COUNT(*) FROM routing_metrics_dev 
    WHERE routed = true AND timestamp > now() - INTERVAL '30' MINUTE
  ), 2) as error_rate_percent
FROM routing_metrics_dev 
WHERE response_status >= 400 AND response_status < 500
  AND routed = true
  AND timestamp > now() - INTERVAL '30' MINUTE

UNION ALL

SELECT 
  'Network Fallbacks' as error_type,
  COUNT(*) as error_count,
  ROUND(COUNT(*) * 100.0 / (
    SELECT COUNT(*) FROM routing_metrics_dev 
    WHERE timestamp > now() - INTERVAL '30' MINUTE
  ), 2) as error_rate_percent
FROM routing_metrics_dev 
WHERE event_type = 'fallback'
  AND timestamp > now() - INTERVAL '30' MINUTE;
```

### Error Details with Context
```sql
SELECT 
  timestamp,
  response_status,
  route_category,
  client_ip,
  cf_country,
  cf_colo,
  response_time_ms,
  error_message
FROM routing_metrics_dev 
WHERE (response_status >= 400 OR event_type = 'error' OR event_type = 'fallback')
  AND timestamp > now() - INTERVAL '1' HOUR
ORDER BY timestamp DESC
LIMIT 50;
```

### Top Error Sources
```sql
SELECT 
  cf_country,
  cf_colo,
  COUNT(*) as error_count,
  COUNT(DISTINCT client_ip) as unique_ips,
  ROUND(AVG(response_time_ms), 2) as avg_response_time
FROM routing_metrics_dev 
WHERE (response_status >= 400 OR event_type = 'error')
  AND timestamp > now() - INTERVAL '24' HOUR
GROUP BY cf_country, cf_colo
HAVING COUNT(*) >= 5
ORDER BY error_count DESC
LIMIT 20;
```

---

## 🌍 Geographic & Performance Analysis

### Traffic by Country (Last 24 Hours)
```sql
SELECT 
  cf_country,
  COUNT(*) as requests,
  COUNT(DISTINCT client_ip) as unique_users,
  ROUND(AVG(response_time_ms), 2) as avg_response_time,
  ROUND(SUM(CASE WHEN routed = true THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as routing_percentage,
  ROUND(SUM(CASE WHEN response_status >= 400 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as error_rate
FROM routing_metrics_dev 
WHERE timestamp > now() - INTERVAL '24' HOUR
  AND cf_country IS NOT NULL
GROUP BY cf_country
HAVING COUNT(*) >= 10
ORDER BY requests DESC
LIMIT 20;
```

### Data Center Performance
```sql
SELECT 
  cf_colo,
  COUNT(*) as requests,
  ROUND(AVG(response_time_ms), 2) as avg_response_time,
  ROUND(MIN(response_time_ms), 2) as min_response_time,
  ROUND(MAX(response_time_ms), 2) as max_response_time,
  ROUND(PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY response_time_ms), 2) as p95_response_time
FROM routing_metrics_dev 
WHERE timestamp > now() - INTERVAL '24' HOUR
  AND cf_colo IS NOT NULL
  AND response_time_ms > 0
GROUP BY cf_colo
HAVING COUNT(*) >= 20
ORDER BY avg_response_time ASC
LIMIT 15;
```

---

## 📈 Business Intelligence Queries

### Peak Traffic Hours Analysis
```sql
SELECT 
  EXTRACT(hour FROM timestamp) as hour_of_day,
  COUNT(*) as total_requests,
  ROUND(AVG(response_time_ms), 2) as avg_response_time,
  COUNT(DISTINCT client_ip) as unique_users,
  ROUND(SUM(CASE WHEN routed = true THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as routing_percentage
FROM routing_metrics_dev 
WHERE timestamp > now() - INTERVAL '7' DAY
  AND event_type = 'routing_decision'
GROUP BY hour_of_day
ORDER BY hour_of_day;
```

### User Behavior Analysis
```sql
SELECT 
  route_category,
  COUNT(DISTINCT client_ip) as unique_users,
  COUNT(*) as total_requests,
  ROUND(COUNT(*) * 1.0 / COUNT(DISTINCT client_ip), 2) as avg_requests_per_user,
  ROUND(AVG(response_time_ms), 2) as avg_response_time
FROM routing_metrics_dev 
WHERE timestamp > now() - INTERVAL '24' HOUR
  AND route_category IS NOT NULL
GROUP BY route_category
ORDER BY unique_users DESC;
```

### Weekly Trend Analysis
```sql
SELECT 
  DATE_TRUNC('day', timestamp) as date,
  COUNT(*) as total_requests,
  COUNT(DISTINCT client_ip) as unique_users,
  SUM(CASE WHEN routed = true THEN 1 ELSE 0 END) as routed_requests,
  ROUND(AVG(response_time_ms), 2) as avg_response_time,
  SUM(CASE WHEN response_status >= 400 THEN 1 ELSE 0 END) as error_requests
FROM routing_metrics_dev 
WHERE timestamp > now() - INTERVAL '7' DAY
GROUP BY date
ORDER BY date DESC;
```

---

## 🔧 Operational Queries

### Recent Activity Log (Live Monitoring)
```sql
SELECT 
  timestamp,
  event_type,
  route_category,
  routed,
  response_status,
  response_time_ms,
  cf_country,
  client_ip
FROM routing_metrics_dev 
WHERE timestamp > now() - INTERVAL '5' MINUTE
ORDER BY timestamp DESC
LIMIT 100;
```

### Health Check Status
```sql
SELECT 
  DATE_TRUNC('minute', timestamp) as minute,
  COUNT(*) as health_checks,
  ROUND(AVG(response_time_ms), 2) as avg_response_time,
  COUNT(CASE WHEN response_status != 200 THEN 1 END) as failed_checks
FROM routing_metrics_dev 
WHERE event_type = 'health_check'
  AND timestamp > now() - INTERVAL '1' HOUR
GROUP BY minute
ORDER BY minute DESC
LIMIT 60;
```

### Request Volume by Minute (Real-time)
```sql
SELECT 
  DATE_TRUNC('minute', timestamp) as minute,
  COUNT(*) as requests_per_minute,
  SUM(CASE WHEN routed = true THEN 1 ELSE 0 END) as routed_requests,
  SUM(CASE WHEN routed = false THEN 1 ELSE 0 END) as passthrough_requests
FROM routing_metrics_dev 
WHERE timestamp > now() - INTERVAL '1' HOUR
  AND event_type = 'routing_decision'
GROUP BY minute
ORDER BY minute DESC
LIMIT 60;
```

---

## 🚨 Alert Threshold Queries

### 5xx Error Rate Alert (Copy for Notifications)
```sql
SELECT 
  COUNT(*) as error_count,
  ROUND(COUNT(*) * 100.0 / (
    SELECT COUNT(*) FROM routing_metrics_dev 
    WHERE routed = true AND timestamp > now() - INTERVAL '5' MINUTE
  ), 2) as error_rate_percent
FROM routing_metrics_dev 
WHERE response_status >= 500 
  AND routed = true
  AND timestamp > now() - INTERVAL '5' MINUTE;
-- ALERT IF: error_rate_percent > 5
```

### Backend Fallback Alert (Copy for Notifications)
```sql
SELECT COUNT(*) as fallback_count
FROM routing_metrics_dev
WHERE event_type = 'fallback'
  AND timestamp > now() - INTERVAL '5' MINUTE;
-- ALERT IF: fallback_count > 3
```

### High Response Time Alert (Copy for Notifications)
```sql
SELECT ROUND(AVG(response_time_ms), 2) as avg_response_time
FROM routing_metrics_dev 
WHERE timestamp > now() - INTERVAL '5' MINUTE
  AND response_time_ms > 0;
-- ALERT IF: avg_response_time > 5000
```

---

## 📋 Query Usage Tips

1. **Replace Dataset**: Change `routing_metrics_dev` to `routing_metrics_prod` for production monitoring
2. **Time Ranges**: Adjust `INTERVAL` values (5 MINUTE, 1 HOUR, 24 HOUR, 7 DAY) based on needs
3. **Thresholds**: Modify `HAVING COUNT(*) >= X` to filter out low-volume data
4. **Live Monitoring**: Use 1-5 minute intervals for real-time dashboards
5. **Historical Analysis**: Use 1-7 day intervals for trend analysis

## 🔗 Related Documentation

- **Dashboard Script**: `npm run dashboard` for CLI monitoring
- **Health Check**: `https://ritualx-dev.ritual-app.co/worker-health`
- **Deployment**: `npm run deploy:dev` or `npm run deploy:prod`
- **Configuration**: Edit `wrangler.jsonc` vars section for canary settings