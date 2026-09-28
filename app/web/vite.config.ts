import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// In Docker the API is reachable at http://api:8080. Outside Docker it is
// http://localhost:8080. Vite forwards every /api call there, so the browser
// only ever talks to one address. CloudFront will do the same job on AWS.
const apiUrl = process.env.API_URL ?? "http://localhost:8080";

export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    proxy: {
      "/api": apiUrl,
    },
  },
});
