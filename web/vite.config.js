import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  define: {
    // Baked in at build time from the APP_VERSION build arg.
    __APP_VERSION__: JSON.stringify(process.env.APP_VERSION || 'dev'),
  },
  server: {
    proxy: { '/api': 'http://localhost:3000', '/health': 'http://localhost:3000' },
  },
});
