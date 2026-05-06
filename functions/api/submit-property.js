export async function onRequestPost(context) {
  const { request, env } = context;

  try {
    const data = await request.json();

    const WP_URL = 'https://philippine-properties.com';
    const auth = btoa(`${env.WP_USERNAME}:${env.WP_APP_PASSWORD}`);

    // Build ACF fields from submitted data
    const photoUrls = (data.photo_urls && data.photo_urls !== 'Local files attached')
      ? data.photo_urls.split(', ').filter(Boolean)
      : [];

    const acfFields = {
      listing_type:      data.listing_type  || '',
      property_type:     data.property_type || '',
      price:             data.price         || '',
      location_city:     data.city          || '',
      location_province: data.province      || '',
      bedrooms:          data.bedrooms      || '',
      bathrooms:         data.bathrooms     || '',
      floor_area:        data.floor_area    || '',
      full_address:      data.address       || '',
      agent_name:        data.name          || '',
      agent_phone:       data.phone         || '',
      agent_email:       data.email         || '',
    };

    // Attach any URL-based photos to ACF image fields
    ['photo_2','photo_3','photo_4','photo_5'].forEach((key, i) => {
      if (photoUrls[i + 1]) acfFields[key] = photoUrls[i + 1];
    });

    const postBody = {
      title:   data.title || 'New Property Submission',
      status:  'draft',
      content: [
        data.description || '',
        data.photo_urls === 'Local files attached'
          ? '\n\n[Photos: submitted as local files — attach manually after upload]'
          : '',
        `\n\n---\nSubmitted by: ${data.name} | ${data.phone} | ${data.email}`,
      ].join(''),
      acf: acfFields,
    };

    const wpRes = await fetch(`${WP_URL}/wp-json/wp/v2/property`, {
      method: 'POST',
      headers: {
        'Authorization': `Basic ${auth}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(postBody),
    });

    const wpData = await wpRes.json();

    if (!wpRes.ok) {
      return new Response(
        JSON.stringify({ success: false, message: wpData.message || 'WordPress rejected the request' }),
        { status: 500, headers: { 'Content-Type': 'application/json' } }
      );
    }

    return new Response(
      JSON.stringify({ success: true, id: wpData.id }),
      { headers: { 'Content-Type': 'application/json' } }
    );

  } catch (err) {
    return new Response(
      JSON.stringify({ success: false, message: err.message || 'Server error' }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    );
  }
}
