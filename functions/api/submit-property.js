const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
  'Content-Type': 'application/json',
};

export async function onRequestOptions() {
  return new Response(null, { status: 204, headers: CORS });
}

export async function onRequestPost({ request, env }) {
  const WP_USER = env.WP_APP_USER;
  const WP_PASS = env.WP_APP_PASS;

  if (!WP_USER || !WP_PASS) {
    return new Response(JSON.stringify({ error: 'Server not configured.' }), { status: 500, headers: CORS });
  }

  let body;
  try {
    body = await request.json();
  } catch {
    return new Response(JSON.stringify({ error: 'Invalid request body.' }), { status: 400, headers: CORS });
  }

  const credentials = btoa(`${WP_USER}:${WP_PASS.replace(/\s/g, '')}`);

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
    const wpRes = await fetch('https://philippine-properties.com/wp-json/wp/v2/property', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Basic ${credentials}`,
      },
      body: JSON.stringify(payload),
    });

    const result = await wpRes.json();

    if (!wpRes.ok) {
      const msg = result.message || result.code || JSON.stringify(result);
      return new Response(JSON.stringify({ error: `WP ${wpRes.status}: ${msg}` }), { status: wpRes.status, headers: CORS });
    }

    return new Response(JSON.stringify({ success: true, id: result.id }), { status: 200, headers: CORS });
  } catch (err) {
    return new Response(JSON.stringify({ error: 'Could not connect to WordPress: ' + err.message }), { status: 500, headers: CORS });
  }
}
