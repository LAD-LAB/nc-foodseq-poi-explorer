export default function handler(req, res) {
  if (req.method !== 'POST') {
    res.status(405).end('Method not allowed');
    return;
  }

  const password = req.body?.password || '';
  const sitePassword = process.env.SITE_PASSWORD || 'ladlab';

  if (password === sitePassword) {
    // Set auth cookie — expires in 7 days, httpOnly so JS can't read it
    res.setHeader('Set-Cookie', `site_auth=1; Path=/; HttpOnly; SameSite=Lax; Max-Age=${7 * 24 * 60 * 60}`);
    res.writeHead(302, { Location: '/' });
    res.end();
  } else {
    res.writeHead(302, { Location: '/?error=1' });
    res.end();
  }
}
