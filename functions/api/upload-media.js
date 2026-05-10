export async function onRequestPost(context) {
  const { request, env } = context;
  const WP_URL = 'https://philippine-properties.com';

  // Require a logged-in user (Bearer token), but upload using app password
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

    // Use Basic auth (app password) — user JWT may lack upload_files capability
    const auth = btoa(`${env.WP_USERNAME}:${env.WP_APP_PASSWORD}`);

    const fd = new FormData();
    fd.append('file', file);

    const wpRes = await fetch(`${WP_URL}/wp-json/wp/v2/media`, {
      method: 'POST',
      headers: { 'Authorization': `Basic ${auth}` },
      body: fd,
    });

    const data = await wpRes.json();

    if (!wpRes.ok) {
      return new Response(
        JSON.stringify({ error: data.message || 'WordPress rejected the upload' }),
        { status: wpRes.status, headers: { 'Content-Type': 'application/json' } }
      );
    }

    return new Response(JSON.stringify(data), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: err.message || 'Upload failed' }), {
      status: 500, headers: { 'Content-Type': 'application/json' },
    });
  }
}
