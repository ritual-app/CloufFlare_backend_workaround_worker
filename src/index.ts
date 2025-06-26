export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    // Health check endpoint for the worker
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

    // Only handle ritualx-dev.ritual-app.co
    if (url.hostname !== "ritualx-dev.ritual-app.co") {
      return fetch(request);
    }

    // Check if routing is disabled via environment variable
    const isRoutingEnabled = env?.ROUTING_ENABLED !== "false";
    if (!isRoutingEnabled) {
      return fetch(request);
    }

    // Handle ONLY /backend/* requests
    if (url.pathname.startsWith("/backend")) {
      // Check canary rollout percentage
      const canaryPercent = parseInt(env?.CANARY_PERCENT || "100");
      const shouldRoute = Math.random() * 100 < canaryPercent;
      
      if (!shouldRoute) {
        // Canary: Don't route, pass through to original destination
        return fetch(request);
      }

      // Remove /backend from path
      let newPath = url.pathname.replace(/^\/backend/, "") || "/";
      const newUrl = `https://management-dev.ritual-app.co${newPath}${url.search}`;

      try {
        // Proxy the request
        const response = await fetch(newUrl, {
          method: request.method,
          headers: request.headers,
          body: request.body,
        });
        return response;
      } catch (error) {
        // On network failure, fallback to original destination
        console.error("Upstream request failed, falling back:", error);
        return fetch(request);
      }
    }

    // All other paths - pass through unharmed to original destination
    return fetch(request);
  },
};
