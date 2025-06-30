# Request Tracking & Observability Guide

## 🎯 **Achieved: Complete Request Visibility**

Your worker now tracks **every request** with full origin details and routing decisions.

## 📊 **Where to View Request Data**

### 1. **Cloudflare Workers Logs** (Real-time)
**Location**: Cloudflare Dashboard → Workers → routing-backend → Logs

**What You'll See**:
```
ROUTING: 8a1b2c3d4e5f6789 | 203.0.113.1 | /backend/v1/experts → BACKEND | 200 | 245ms | US
PASSTHROUGH: 9f8e7d6c5b4a3210 | 198.51.100.1 | /backend/health → FRONTEND | CA  
FALLBACK: 1a2b3c4d5e6f7890 | 192.0.2.1 | /backend/v1/users → FRONTEND | ERROR: Network timeout
```

**Data Fields**:
- **CF-Ray ID**: Unique request identifier  
- **Client IP**: Request origin
- **Path**: Requested URL path
- **Destination**: BACKEND (routed) or FRONTEND (pass-through)
- **Status Code**: HTTP response
- **Response Time**: Processing time in milliseconds
- **Country**: Request origin country

### 2. **Live Health Dashboard** (npm run dashboard)
Shows real-time system status, routing percentages, and backend health.

### 3. **Analytics Engine** (Advanced)
Your detailed metrics are stored with:
- Request headers (User-Agent, Referer)
- Geographic data (Country, Data Center, ASN)
- Performance metrics (Response times)
- Route categorization (experts-api, api-v1, etc.)

## 🔍 **Query Examples**

### Cloudflare GraphQL Analytics API
```graphql
query {
  viewer {
    zones(filter: {zoneTag: "YOUR_ZONE_ID"}) {
      httpRequests1hGroups(
        filter: {
          date_gt: "2024-01-01"
          clientCountryName_in: ["US", "CA", "GB"]
        }
        limit: 100
      ) {
        sum {
          requests
          bytes
        }
        dimensions {
          clientCountryName
          clientIP
          edgeResponseStatus
        }
      }
    }
  }
}
```

### Analytics Engine SQL (Raw Data)
```sql
-- Total routing decisions by country (if blob mapping done)
SELECT 
  blob4 as country,  -- cf_country field
  blob5 as routed,   -- routing decision  
  COUNT() as requests
FROM routing_backend_dev 
WHERE timestamp > now() - INTERVAL '1' HOUR
GROUP BY blob4, blob5
```

## 🚀 **How to Use This**

### Real-time Monitoring:
```bash
# Live dashboard
npm run dashboard

# Watch logs in Cloudflare Dashboard
# Workers → routing-backend → Logs (auto-refresh)
```

### Debugging Specific Requests:
1. Find CF-Ray ID in logs: `8a1b2c3d4e5f6789`
2. Search Cloudflare logs for that Ray ID
3. See complete request trace with routing decision

### Traffic Analysis:
- **Origin Analysis**: See which countries/IPs are being routed
- **Performance Monitoring**: Track response times by destination
- **Error Tracking**: Monitor fallback events and network issues
- **Canary Validation**: Verify routing percentages match settings

## 📈 **Key Metrics to Track**

- **Routing Rate**: % of requests sent to backend vs frontend
- **Geographic Distribution**: Which countries use which path
- **Error Rates**: Fallback events indicate backend issues
- **Performance**: Response time differences between routing paths
- **User Agents**: Track which clients (mobile/desktop/bots) get routed

Your observability is now **production-ready** with complete request tracking! 🎯