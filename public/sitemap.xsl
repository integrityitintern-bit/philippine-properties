<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="2.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:sm="http://www.sitemaps.org/schemas/sitemap/0.9">
  <xsl:output method="html" version="1.0" encoding="UTF-8" indent="yes"/>
  <xsl:template match="/">
    <html lang="en">
      <head>
        <meta charset="UTF-8"/>
        <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
        <title>Sitemap — Philippine Real Estate Properties</title>
        <style>
          * { box-sizing: border-box; margin: 0; padding: 0; }
          body { font-family: system-ui, sans-serif; background: #f9fafb; color: #111827; }
          header { background: #8B0000; color: white; padding: 2rem 1.5rem; }
          header h1 { font-size: 1.5rem; font-weight: 700; }
          header p { font-size: 0.85rem; opacity: 0.8; margin-top: 0.25rem; }
          .container { max-width: 860px; margin: 2rem auto; padding: 0 1.5rem; }
          .stats { display: flex; gap: 1rem; margin-bottom: 1.5rem; flex-wrap: wrap; }
          .stat { background: white; border: 1px solid #e5e7eb; border-radius: 12px; padding: 1rem 1.5rem; flex: 1; min-width: 140px; }
          .stat-num { font-size: 1.75rem; font-weight: 700; color: #8B0000; }
          .stat-label { font-size: 0.75rem; color: #6b7280; margin-top: 0.25rem; text-transform: uppercase; letter-spacing: 0.05em; }
          table { width: 100%; border-collapse: collapse; background: white; border-radius: 12px; overflow: hidden; border: 1px solid #e5e7eb; }
          thead { background: #8B0000; color: white; }
          th { padding: 0.75rem 1rem; text-align: left; font-size: 0.75rem; text-transform: uppercase; letter-spacing: 0.05em; font-weight: 600; }
          td { padding: 0.75rem 1rem; font-size: 0.85rem; border-bottom: 1px solid #f3f4f6; }
          tr:last-child td { border-bottom: none; }
          tr:hover td { background: #fff7f7; }
          a { color: #8B0000; text-decoration: none; }
          a:hover { text-decoration: underline; }
          .badge { display: inline-block; font-size: 0.7rem; padding: 0.2rem 0.6rem; border-radius: 999px; font-weight: 600; }
          .badge-daily { background: #fef3c7; color: #92400e; }
          .badge-weekly { background: #dbeafe; color: #1e40af; }
          .badge-monthly { background: #f3f4f6; color: #6b7280; }
          .priority-high { color: #8B0000; font-weight: 700; }
          .priority-mid { color: #374151; font-weight: 600; }
          .priority-low { color: #9ca3af; }
          footer { text-align: center; padding: 2rem; color: #9ca3af; font-size: 0.8rem; }
        </style>
      </head>
      <body>
        <header>
          <h1>XML Sitemap</h1>
          <p>Philippine Real Estate Properties — <xsl:value-of select="count(sm:urlset/sm:url)"/> URLs indexed</p>
        </header>
        <div class="container">
          <div class="stats">
            <div class="stat">
              <div class="stat-num"><xsl:value-of select="count(sm:urlset/sm:url)"/></div>
              <div class="stat-label">Total URLs</div>
            </div>
            <div class="stat">
              <div class="stat-num"><xsl:value-of select="count(sm:urlset/sm:url[sm:changefreq='daily'])"/></div>
              <div class="stat-label">Updated Daily</div>
            </div>
            <div class="stat">
              <div class="stat-num"><xsl:value-of select="count(sm:urlset/sm:url[contains(sm:loc,'/property/')])"/></div>
              <div class="stat-label">Property Pages</div>
            </div>
          </div>
          <table>
            <thead>
              <tr>
                <th>URL</th>
                <th>Last Modified</th>
                <th>Frequency</th>
                <th>Priority</th>
              </tr>
            </thead>
            <tbody>
              <xsl:for-each select="sm:urlset/sm:url">
                <tr>
                  <td>
                    <a href="{sm:loc}"><xsl:value-of select="sm:loc"/></a>
                  </td>
                  <td><xsl:value-of select="sm:lastmod"/></td>
                  <td>
                    <xsl:choose>
                      <xsl:when test="sm:changefreq='daily'">
                        <span class="badge badge-daily">Daily</span>
                      </xsl:when>
                      <xsl:when test="sm:changefreq='weekly'">
                        <span class="badge badge-weekly">Weekly</span>
                      </xsl:when>
                      <xsl:otherwise>
                        <span class="badge badge-monthly">Monthly</span>
                      </xsl:otherwise>
                    </xsl:choose>
                  </td>
                  <td>
                    <xsl:choose>
                      <xsl:when test="sm:priority >= 0.9">
                        <span class="priority-high"><xsl:value-of select="sm:priority"/></span>
                      </xsl:when>
                      <xsl:when test="sm:priority >= 0.7">
                        <span class="priority-mid"><xsl:value-of select="sm:priority"/></span>
                      </xsl:when>
                      <xsl:otherwise>
                        <span class="priority-low"><xsl:value-of select="sm:priority"/></span>
                      </xsl:otherwise>
                    </xsl:choose>
                  </td>
                </tr>
              </xsl:for-each>
            </tbody>
          </table>
        </div>
        <footer>Generated by Philippine Real Estate Properties</footer>
      </body>
    </html>
  </xsl:template>
</xsl:stylesheet>
