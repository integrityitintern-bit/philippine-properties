// @ts-check
import { defineConfig } from 'astro/config';
import tailwindcss from '@tailwindcss/vite';
import sitemap from '@astrojs/sitemap';

export default defineConfig({
  site: 'https://stalwart-kashata-382a41.netlify.app',
  integrations: [sitemap()],
  vite: {
    plugins: [tailwindcss()]
  }
});