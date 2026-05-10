export async function onRequestPost(context) {
  const { request } = context;
  const WP_URL = 'https://philippine-properties.com';

  const authHeader = request.headers.get('Authorization') || '';
  if (!authHeader.startsWith('Bearer ')) {
    return new Response(JSON.stringify({ error: 'Unauthorized' }), {
      status: 401, headers: { 'Content-Type': 'application/json' },
    });
  }

  try {
    const formData = await request.formData();
    const file = formData.get('file');
    if (!file) {
      return new Response(JSON.stringify({ error: 'No file provided' }), {
        status: 400, headers: { 'Content-Type': 'application/json' },
      });
    }

    const fd = new FormData();
    fd.append('file', file);

    const wpRes = await fetch(`${WP_URL}/wp-json/wp/v2/media`, {
      method: 'POST',
      headers: { 'Authorization': authHeader },
      body: fd,
    });

    const data = await wpRes.json();

    return new Response(JSON.stringify(data), {
      status: wpRes.status,
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: err.message || 'Upload failed' }), {
      status: 500, headers: { 'Content-Type': 'application/json' },
    });
  }
}
