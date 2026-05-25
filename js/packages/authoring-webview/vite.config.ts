import { defineConfig } from 'vite'

export default defineConfig({
  base: './',
  build: {
    assetsDir: '.',
    sourcemap: true,
    rollupOptions: {
      input: 'index.html'
    }
  }
})
