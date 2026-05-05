exports.handler = async (event) => {
  if (event.httpMethod !== 'POST') {
    return { statusCode: 405, body: 'Method Not Allowed' };
  }

  const WP_USER = process.env.WP_APP_USER;
  const WP_PASS = process.env.WP_APP_PASS;
  const WP_API  = 'https://philippine-properties.com/wp-json/wp/v2';

  if (!WP_USER || !WP_PASS) {
    return { statusCode: 500, body: JSON.stringify({ error: 'Server not configured.' }) };
  }

  let body;
  try { body = JSON.parse(event.body); }
  catch { return { statusCode: 400, body: JSON.stringify({ error: 'Invalid request.' }) }; }

  const credentials = Buffer.from(`${WP_USER}:${WP_PASS.replace(/\s/g, '')}`).toString('base64');

  const payload = {
    title:  body.title || 'Untitled Property',
    status: 'pending',
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
    }
  };

  try {
    const res = await fetch(`${WP_API}/property`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Basic ${credentials}`,
      },
      body: JSON.stringify(payload),
    });

    const data = await res.json();

    if (!res.ok) {
      return { statusCode: res.status, body: JSON.stringify({ error: data.message || 'WordPress error.' }) };
    }

    return {
      statusCode: 200,
      body: JSON.stringify({ success: true, id: data.id, slug: data.slug }),
    };
  } catch (err) {
    return { statusCode: 500, body: JSON.stringify({ error: 'Failed to connect to WordPress.' }) };
  }
};
