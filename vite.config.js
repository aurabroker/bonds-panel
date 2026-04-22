import { defineConfig } from 'vite';

export default defineConfig({
  root: '.',
  build: {
    outDir: 'dist',
    emptyOutDir: true,
    rollupOptions: {
      input: {
        main: 'index.html',
        analityka: 'analityka.html'
      }
    },
    // Generuje SRI hash automatycznie przy produkcyjnym buildzie
    cssCodeSplit: true,
    minify: 'esbuild'
  },
  server: {
    port: 5173,
    open: true
  },
  preview: {
    port: 4173
  }
});
