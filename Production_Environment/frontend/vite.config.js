import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [react()],
  base: '/',
  server: {
    host: '0.0.0.0',
    port: 5173,
    strictPort: true,
    watch: {
      usePolling: true, // Ensure file watching works in Docker volumes
    },
    hmr: {
      overlay: false, // Disable HMR overlay to see the actual app
    },
  },
  resolve: {
    alias: {
      '@shared': '/app/src/shared', // Alias for shared theme from Shared_Environment
    },
  },
  define: {
    'import.meta.env.VITE_API_BASE_URL': JSON.stringify(process.env.VITE_API_BASE_URL || '/api'),
  },
})
