import type { APIRoute } from 'astro';
import { WP_API } from '../config.js';

export const GET: APIRoute = async () => {
  const SITE = 'https://philippine-properties.com';

  let properties: any[] = [];
  try {
    const res = await fetch(`${WP_API}/property?per_page=100&status=publish&_fields=slug,modified`);
    properties = await res.json();
    if (!Array.isArray(properties)) properties = [];
  } catch {}

  const staticPages = [
    { path: '', priority: '1.0', freq: 'daily' },
    { path: '/search', priority: '0.9', freq: 'daily' },
    { path: '/agents', priority: '0.8', freq: 'weekly' },
    { path: '/resources', priority: '0.8', freq: 'weekly' },
    { path: '/about', priority: '0.7', freq: 'monthly' },
    { path: '/contact', priority: '0.7', freq: 'monthly' },
    { path: '/faq', priority: '0.7', freq: 'monthly' },
    { path: '/list-property', priority: '0.8', freq: 'monthly' },
  ];

  const today = new Date().toISOString().split('T')[0];

  const xml = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
${staticPages.map(p => `  <url>
    <loc>${SITE}${p.path}</loc>
    <lastmod>${today}</lastmod>
    <changefreq>${p.freq}</changefreq>
    <priority>${p.priority}</priority>
  </url>`).join('\n')}
${properties.map(p => `  <url>
    <loc>${SITE}/property/${p.slug}</loc>
    <lastmod>${p.modified ? p.modified.split('T')[0] : today}</lastmod>
    <changefreq>monthly</changefreq>
    <priority>0.7</priority>
  </url>`).join('\n')}
</urlset>`;

  return new Response(xml, {
    headers: { 'Content-Type': 'application/xml; charset=utf-8' }
  });
};
