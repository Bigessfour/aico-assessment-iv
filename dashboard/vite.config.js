// Vite build config for the ops dashboard.
//   - The react plugin compiles JSX; `npm run build` emits static files to dist/,
//     which the Dockerfile copies into an nginx image (no Node in the runtime).
//   - server.port only affects `npm run dev` on a laptop. In the cluster nginx
//     serves on port 80 and the dashboard is reached via port-forward.
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    port: 3000
  }
})
