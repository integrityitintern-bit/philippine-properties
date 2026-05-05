const https = require('https');

function wpRequest(path, credentials, payload) {
  return new Promise((resolve, reject) => {
    const body = JSON.stringify(payload);
    const auth = Buffer.from(credentials).toString('base64');
    const url = new URL('https://philippine-properties.com' + path);

    const options = {
      hostname: url.hostname,
      path: url.pathname,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Basic ' + auth,
        'Content-Length': Buffer.byteLength(body),
      },
    };

    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, body: JSON.parse(data) });
        } catch {
          resolve({ status: res.statusCode, body: data });
        }
      });
    });

    req.on('error', reject);
    req.write(body);
    req.end();
  });
}

exports.handler = async (event) => {
  const headers = { 'Access-Control-Allow-Origin': '*', 'Content-Type': 'application/json' };

  if (event.httpMethod === 'OPTIONS') return { statusCode: 200, headers };
  if (event.httpMethod !== 'POST') return { statusCode: 405, headers, body: JSON.stringify({ error: 'Method not allowed' }) };

  const WP_USER = process.env.WP_APP_USER;
  const WP_PASS = process.env.WP_APP_PASS;

  if (!WP_USER || !WP_PASS) {
    return { statusCode: 500, headers, body: JSON.stringify({ error: 'Server not configured.' }) };
  }

  let body;
  try { body = JSON.parse(event.body); }
  catch { return { statusCode: 400, headers, body: JSON.stringify({ error: 'Invalid request body.' }) }; }

  const credentials = `${WP_USER}:${WP_PASS.replace(/\s/g, '')}`;

  const payload = {
    title:   body.title || 'Untitled Property',
    status:  'pending',
    content: body.description || '',
    acf: {
      listing_type:      body.listing_type || '',
      property_type:     body.property_type || '',
      price:             body.price || '',
      location_city:     body.city || '',
      location_province: body.province || '',
      address:           body.address || '',
      bedrooms:          body.bedrooms || '',
      bathrooms:         body.bathrooms || '',
      floor_area:        body.floor_area || '',
      agent_name:        body.name || '',
      agent_phone:       body.phone || '',
      agent_email:       body.email || '',
    },
  };

  try {
    const result = await wpRequest('/wp-json/wp/v2/property', credentials, payload);
    if (result.status < 200 || result.status >= 300) {
      const msg = (result.body && (result.body.message || result.body.code || JSON.stringify(result.body))) || 'WordPress rejected the request.';
      return { statusCode: result.status, headers, body: JSON.stringify({ error: `WP ${result.status}: ${msg}` }) };
    }
    return { statusCode: 200, headers, body: JSON.stringify({ success: true, id: result.body.id }) };
  } catch (err) {
    return { statusCode: 500, headers, body: JSON.stringify({ error: 'Could not connect to WordPress: ' + err.message }) };
  }
};
