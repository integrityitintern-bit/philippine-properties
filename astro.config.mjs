// @ts-check
import { defineConfig } from 'astro/config';
import tailwindcss from '@tailwindcss/vite';
import sitemap from '@astrojs/sitemap';

import cloudflare from '@astrojs/cloudflare';

export default defineConfig({
  site: 'https://philippine-properties.rylleairon.workers.dev',
  integrations: [sitemap()],

  vite: {
    plugins: [tailwindcss()]
  },

  adapter: cloudflare()
});