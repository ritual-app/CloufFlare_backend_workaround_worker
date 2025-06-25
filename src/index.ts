export default {
  async fetch(request) {
    const url = new URL(request.url);

    // Only handle ritualx-dev.ritual-app.co
    if (url.hostname !== "ritualx-dev.ritual-app.co") {
      return fetch(request);
    }

    // Handle ONLY /backend/* requests
    if (url.pathname.startsWith("/backend")) {
      // Remove /backend from path
      let newPath = url.pathname.replace(/^\/backend/, "") || "/";
      const newUrl = `https://management-dev.ritual-app.co${newPath}${url.search}`;

      // Proxy the request
      return fetch(newUrl, {
        method: request.method,
        headers: request.headers,
        body: request.body,
      });
    }

    // All other paths - pass through unharmed to original destination
    return fetch(request);
  },
};
