/**
 * Cloudflare Worker: Backend Routing Proxy with Critical Monitoring
 * 
 * Purpose: Route requests from ritualx-dev.ritual-app.co/backend/* to management-dev.ritual-app.co
 * while preserving all other functionality and supporting gradual rollout via canary deployment.
 * 
 * Environment Variables:
 * - ROUTING_ENABLED: Master toggle for all routing (true/false, default: true)
 * - CANARY_PERCENT: Percentage of /backend/* traffic to route (0-100, default: 100)
 * 
 * Routes:
 * - /worker-health → Worker health status (always available)
 * - /backend/* → [CANARY %] → management-dev.ritual-app.co/* (with /backend prefix removed)
 * - /* → Pass through unchanged to original destination
 * 
 * Rollback Mechanisms:
 * 1. Set ROUTING_ENABLED=false (emergency disable)
 * 2. Set CANARY_PERCENT=0 (gradual disable)
 * 3. Network errors automatically fall back to original destination
 * 4. DNS rollback: Switch domain back to grey cloud (DNS-only mode)
 * 
 * Monitoring:
 * - Analytics Engine for custom metrics and alerts
 * - Structured logging for debugging and audit trails
 * - Real-time health status with performance metrics
 * - Error tracking and automatic fallback monitoring
 */

interface Env {
  ROUTING_ENABLED?: string;
  CANARY_PERCENT?: string;
  ANALYTICS?: AnalyticsEngineDataset;
}

interface RoutingMetrics {
  timestamp: string;
  event_type: 'routing_decision' | 'health_check' | 'error' | 'fallback';
  path: string;
  method: string;
  routing_enabled: boolean;
  canary_percent: number;
  routed: boolean;
  response_status?: number;
  response_time_ms?: number;
  error_message?: string;
  user_agent?: string;
  cf_ray?: string;
  cf_country?: string;
}

/**
 * Log metrics to Analytics Engine for monitoring and alerting
 */
async function logMetrics(env: Env, request: Request, metrics: Partial<RoutingMetrics>) {
  if (!env.ANALYTICS) return;
  
  const cf = request.cf as any;
  const timestamp = new Date().toISOString();
  
  const fullMetrics: RoutingMetrics = {
    timestamp,
    event_type: 'routing_decision',
    path: new URL(request.url).pathname,
    method: request.method,
    routing_enabled: env?.ROUTING_ENABLED !== "false",
    canary_percent: parseInt(env?.CANARY_PERCENT || "100"),
    routed: false,
    user_agent: request.headers.get('user-agent') || 'unknown',
    cf_ray: request.headers.get('cf-ray') || 'unknown',
    cf_country: cf?.country || 'unknown',
    ...metrics
  };

  try {
    env.ANALYTICS.writeDataPoint(fullMetrics);
  } catch (error) {
    console.error('Failed to log metrics:', error);
  }
}

/**
 * Enhanced health check with performance metrics and system status
 */
async function getHealthStatus(env: Env, request: Request) {
  const startTime = Date.now();
  const isRoutingEnabled = env?.ROUTING_ENABLED !== "false";
  const canaryPercent = parseInt(env?.CANARY_PERCENT || "0");

  // Test backend connectivity
  let backendHealthy = false;
  let backendResponseTime = 0;
  
  try {
    const backendStart = Date.now();
    const backendResponse = await fetch('https://management-dev.ritual-app.co/health_check', {
      method: 'HEAD',
      headers: { 'User-Agent': 'RoutingWorker-HealthCheck/1.0' }
    });
    backendResponseTime = Date.now() - backendStart;
    backendHealthy = backendResponse.ok;
  } catch (error) {
    console.error('Backend health check failed:', error);
  }

  const responseTime = Date.now() - startTime;
  
  const healthData = {
    status: "healthy",
    routing_enabled: isRoutingEnabled,
    canary_percent: canaryPercent,
    backend_healthy: backendHealthy,
    backend_response_time_ms: backendResponseTime,
    worker_response_time_ms: responseTime,
    timestamp: new Date().toISOString(),
    worker_version: "1.0.0"
  };

  // Log health check metrics
  await logMetrics(env, request, {
    event_type: 'health_check',
    response_time_ms: responseTime,
    routed: false
  });

  return healthData;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    const startTime = Date.now();

    // Health check endpoint - enhanced with backend connectivity and performance metrics
    if (url.pathname === "/worker-health") {
      try {
        const healthData = await getHealthStatus(env, request);
        return new Response(JSON.stringify(healthData), {
          headers: { "Content-Type": "application/json" },
          status: 200
        });
      } catch (error) {
        await logMetrics(env, request, {
          event_type: 'error',
          error_message: `Health check failed: ${error}`,
          response_status: 500
        });
        
        return new Response(JSON.stringify({
          status: "error",
          error: "Health check failed",
          timestamp: new Date().toISOString()
        }), {
          headers: { "Content-Type": "application/json" },
          status: 500
        });
      }
    }

    // Only handle requests for our target domain
    // All other domains pass through unchanged
    if (url.hostname !== "ritualx-dev.ritual-app.co") {
      return fetch(request);
    }

    // Emergency routing disable: ROUTING_ENABLED=false bypasses all routing logic
    // Useful for immediate rollback without changing DNS or redeploying worker
    const isRoutingEnabled = env?.ROUTING_ENABLED !== "false";
    if (!isRoutingEnabled) {
      return fetch(request);
    }

    // Backend routing logic: Handle ONLY /backend/* requests
    if (url.pathname.startsWith("/backend")) {
      const canaryPercent = parseInt(env?.CANARY_PERCENT || "100");
      const shouldRoute = Math.random() * 100 < canaryPercent;
      
      if (!shouldRoute) {
        // Canary: Don't route this request, pass through to original destination
        await logMetrics(env, request, {
          event_type: 'routing_decision',
          routed: false,
          response_status: 200
        });
        return fetch(request);
      }

      // Transform URL: Remove /backend prefix and route to management-dev
      let newPath = url.pathname.replace(/^\/backend/, "") || "/";
      const newUrl = `https://management-dev.ritual-app.co${newPath}${url.search}`;

      try {
        // Proxy the request with performance monitoring
        const proxyStartTime = Date.now();
        const response = await fetch(newUrl, {
          method: request.method,
          headers: request.headers,
          body: request.body,
        });
        const responseTime = Date.now() - startTime;

        // Log successful routing metrics
        await logMetrics(env, request, {
          event_type: 'routing_decision',
          routed: true,
          response_status: response.status,
          response_time_ms: responseTime
        });

        return response;
      } catch (error) {
        // Network failure fallback with error logging
        const errorMessage = `Upstream request failed: ${error}`;
        console.error(errorMessage);
        
        await logMetrics(env, request, {
          event_type: 'fallback',
          routed: false,
          error_message: errorMessage,
          response_time_ms: Date.now() - startTime
        });

        return fetch(request);
      }
    }

    // All other paths: Pass through unchanged to original destination
    // Preserves existing functionality for non-backend routes
    return fetch(request);
  },
};
