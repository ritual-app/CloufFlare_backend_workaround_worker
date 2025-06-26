/**
 * Cloudflare Worker: Backend Routing Proxy
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
 */
export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    // Health check endpoint - always available regardless of routing settings
    // Returns current worker status and configuration
    if (url.pathname === "/worker-health") {
      const isRoutingEnabled = env?.ROUTING_ENABLED !== "false";
      const canaryPercent = parseInt(env?.CANARY_PERCENT || "0");
      return new Response(JSON.stringify({
        status: "healthy",
        routing_enabled: isRoutingEnabled,
        canary_percent: canaryPercent,
        timestamp: new Date().toISOString(),
        worker_version: "1.0.0"
      }), {
        headers: { "Content-Type": "application/json" },
        status: 200
      });
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
      // Canary deployment: Gradually route traffic based on CANARY_PERCENT
      // CANARY_PERCENT=0: No routing (0% of traffic)
      // CANARY_PERCENT=50: Route 50% of traffic randomly  
      // CANARY_PERCENT=100: Route all traffic (default)
      const canaryPercent = parseInt(env?.CANARY_PERCENT || "100");
      const shouldRoute = Math.random() * 100 < canaryPercent;
      
      if (!shouldRoute) {
        // Canary: Don't route this request, pass through to original destination
        return fetch(request);
      }

      // Transform URL: Remove /backend prefix and route to management-dev
      // Example: /backend/v1/experts/ → https://management-dev.ritual-app.co/v1/experts/
      let newPath = url.pathname.replace(/^\/backend/, "") || "/";
      const newUrl = `https://management-dev.ritual-app.co${newPath}${url.search}`;

      try {
        // Proxy the request with all original properties preserved
        const response = await fetch(newUrl, {
          method: request.method,
          headers: request.headers,
          body: request.body,
        });
        return response;
      } catch (error) {
        // Network failure fallback: If management-dev is unreachable,
        // automatically fall back to original destination to prevent outages
        console.error("Upstream request failed, falling back:", error);
        return fetch(request);
      }
    }

    // All other paths: Pass through unchanged to original destination
    // Preserves existing functionality for non-backend routes
    return fetch(request);
  },
};
