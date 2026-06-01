const LOGIN_HTML = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>NC FoodSeq — Access Required</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Geist:wght@400;500;600;700&display=swap" rel="stylesheet">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: 'Geist', -apple-system, BlinkMacSystemFont, sans-serif;
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      background: #0f172a;
      color: #e2e8f0;
    }
    .lock-card {
      background: #1e293b;
      border: 1px solid #334155;
      border-radius: 16px;
      padding: 48px 40px;
      max-width: 400px;
      width: 90%;
      text-align: center;
      box-shadow: 0 25px 50px rgba(0,0,0,0.4);
    }
    .lock-icon {
      font-size: 48px;
      margin-bottom: 16px;
    }
    h1 {
      font-size: 20px;
      font-weight: 600;
      margin-bottom: 8px;
      color: #f8fafc;
    }
    p {
      font-size: 14px;
      color: #94a3b8;
      margin-bottom: 28px;
    }
    form { display: flex; flex-direction: column; gap: 12px; }
    input[type="password"] {
      padding: 12px 16px;
      border-radius: 8px;
      border: 1px solid #475569;
      background: #0f172a;
      color: #f8fafc;
      font-size: 15px;
      font-family: inherit;
      outline: none;
      transition: border-color 0.2s;
    }
    input[type="password"]:focus { border-color: #3b82f6; }
    button {
      padding: 12px;
      border-radius: 8px;
      border: none;
      background: #1e3a8a;
      color: #fff;
      font-size: 15px;
      font-weight: 600;
      font-family: inherit;
      cursor: pointer;
      transition: background 0.2s;
    }
    button:hover { background: #2563eb; }
    .error {
      color: #f87171;
      font-size: 13px;
      margin-top: 4px;
      display: none;
    }
  </style>
</head>
<body>
  <div class="lock-card">
    <div class="lock-icon">&#128274;</div>
    <h1>NC FoodSeq Explorer</h1>
    <p>This site is under development.<br>Enter the password to continue.</p>
    <form method="POST" action="/api/login">
      <input type="password" name="password" placeholder="Password" autofocus required>
      <button type="submit">Enter</button>
    </form>
    <div class="error" id="err">Incorrect password. Try again.</div>
  </div>
  <script>
    if (location.search.includes('error=1')) {
      document.getElementById('err').style.display = 'block';
    }
  </script>
</body>
</html>`;

export default function middleware(request) {
  const url = new URL(request.url);

  // Always allow the login API through
  if (url.pathname === '/api/login') {
    return undefined; // pass through to the API route
  }

  // Check for auth cookie
  const cookie = request.headers.get('cookie') || '';
  const hasAuth = cookie.split(';').some(c => c.trim().startsWith('site_auth='));

  if (hasAuth) {
    return undefined; // authenticated, pass through
  }

  // Not authenticated — show login page
  return new Response(LOGIN_HTML, {
    status: 200,
    headers: { 'Content-Type': 'text/html; charset=utf-8' },
  });
}

export const config = {
  matcher: ['/((?!_next|favicon.ico).*)'],
};
