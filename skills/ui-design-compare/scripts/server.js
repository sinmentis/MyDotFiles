'use strict';

const crypto = require('crypto');
const fs = require('fs');
const http = require('http');
const path = require('path');
const { spawn } = require('child_process');

const sessionDir = process.env.UI_COMPARE_DIR;
if (!sessionDir) {
  throw new Error('UI_COMPARE_DIR is required');
}

const host = process.env.UI_COMPARE_HOST || '127.0.0.1';
const urlHost = process.env.UI_COMPARE_URL_HOST || (host === '127.0.0.1' ? 'localhost' : host);
const idleTimeoutMs = Number(process.env.UI_COMPARE_IDLE_TIMEOUT_MS || 14400000);
const shouldOpen = process.env.UI_COMPARE_OPEN === 'true';
const contentDir = path.join(sessionDir, 'content');
const stateDir = path.join(sessionDir, 'state');
const eventsFile = path.join(stateDir, 'events');
const serverInfoFile = path.join(stateDir, 'server-info');
const stoppedFile = path.join(stateDir, 'server-stopped');
const pidFile = path.join(stateDir, 'server.pid');
const token = crypto.randomBytes(32).toString('hex');
const frameTemplate = fs.readFileSync(path.join(__dirname, 'frame-template.html'), 'utf8');
const helperScript = fs.readFileSync(path.join(__dirname, 'helper.js'), 'utf8');

let lastActivity = Date.now();

function safeEqual(left, right) {
  const a = Buffer.from(String(left || ''));
  const b = Buffer.from(String(right || ''));
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}

function authorize(requestUrl) {
  return safeEqual(requestUrl.searchParams.get('key'), token);
}

function cookieValue(request, name) {
  const cookies = String(request.headers.cookie || '').split(';');
  for (const cookie of cookies) {
    const separator = cookie.indexOf('=');
    if (separator === -1) continue;
    if (cookie.slice(0, separator).trim() === name) {
      const value = cookie.slice(separator + 1).trim();
      try {
        return decodeURIComponent(value);
      } catch (error) {
        return value;
      }
    }
  }
  return null;
}

function isAuthorized(request, requestUrl) {
  return authorize(requestUrl) || safeEqual(cookieValue(request, 'ui-compare-key'), token);
}

function latestScreen() {
  const candidates = fs.readdirSync(contentDir, { withFileTypes: true })
    .filter((entry) => entry.isFile() && entry.name.endsWith('.html'))
    .map((entry) => {
      const file = path.join(contentDir, entry.name);
      const stat = fs.statSync(file);
      return { file, name: entry.name, mtimeMs: stat.mtimeMs, size: stat.size };
    })
    .sort((left, right) => right.mtimeMs - left.mtimeMs || right.name.localeCompare(left.name));

  return candidates[0] || null;
}

function screenVersion(screen) {
  return screen ? `${screen.name}:${screen.mtimeMs}:${screen.size}` : 'waiting';
}

function scriptJson(value) {
  return JSON.stringify(value).replace(/</g, '\\u003c');
}

function injectRuntime(document, version) {
  const runtime = [
    '<script>',
    `window.__UI_COMPARE_VERSION=${scriptJson(version)};`,
    helperScript,
    '</script>'
  ].join('\n');

  if (document.includes('</body>')) {
    return document.replace('</body>', `${runtime}\n</body>`);
  }
  return `${document}\n${runtime}`;
}

function renderPage() {
  const screen = latestScreen();
  const version = screenVersion(screen);
  const content = screen
    ? fs.readFileSync(screen.file, 'utf8')
    : [
        '<header class="screen-intro">',
        '<p class="eyebrow">Companion ready</p>',
        '<h1>Waiting for design options.</h1>',
        '<p>The browser will refresh when the first comparison screen is written.</p>',
        '</header>'
      ].join('');

  const isDocument = /^\s*(<!doctype|<html)/i.test(content);
  const document = isDocument
    ? content
    : frameTemplate.replace('<!-- CONTENT -->', content);

  return { html: injectRuntime(document, version), version };
}

function contentType(file) {
  const types = {
    '.css': 'text/css; charset=utf-8',
    '.gif': 'image/gif',
    '.html': 'text/html; charset=utf-8',
    '.jpeg': 'image/jpeg',
    '.jpg': 'image/jpeg',
    '.js': 'application/javascript; charset=utf-8',
    '.json': 'application/json; charset=utf-8',
    '.png': 'image/png',
    '.svg': 'image/svg+xml'
  };
  return types[path.extname(file).toLowerCase()] || 'application/octet-stream';
}

function send(response, status, body, type, extraHeaders = {}) {
  response.writeHead(status, {
    'cache-control': 'no-store',
    'content-type': type,
    'referrer-policy': 'no-referrer',
    'x-content-type-options': 'nosniff',
    'x-frame-options': 'DENY',
    ...extraHeaders
  });
  response.end(body);
}

function sendJson(response, status, value) {
  send(response, status, JSON.stringify(value), 'application/json; charset=utf-8');
}

function readBody(request, limit = 65536) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let size = 0;
    request.on('data', (chunk) => {
      size += chunk.length;
      if (size > limit) {
        reject(new Error('request body too large'));
        request.destroy();
        return;
      }
      chunks.push(chunk);
    });
    request.on('end', () => resolve(Buffer.concat(chunks).toString('utf8')));
    request.on('error', reject);
  });
}

function serveFile(response, pathname) {
  let relative;
  try {
    relative = decodeURIComponent(pathname.slice('/files/'.length));
  } catch (error) {
    sendJson(response, 400, { error: 'invalid path' });
    return;
  }

  const target = path.resolve(contentDir, relative);
  const root = path.resolve(contentDir);
  if (target !== root && !target.startsWith(`${root}${path.sep}`)) {
    sendJson(response, 403, { error: 'forbidden' });
    return;
  }
  if (!fs.existsSync(target) || !fs.statSync(target).isFile()) {
    sendJson(response, 404, { error: 'not found' });
    return;
  }
  send(response, 200, fs.readFileSync(target), contentType(target));
}

const server = http.createServer(async (request, response) => {
  lastActivity = Date.now();
  let requestUrl;
  try {
    requestUrl = new URL(request.url, 'http://localhost');
  } catch (error) {
    sendJson(response, 400, { error: 'invalid request URL' });
    return;
  }

  if (!isAuthorized(request, requestUrl)) {
    send(
      response,
      403,
      '<!doctype html><title>Access denied</title><h1>Complete keyed URL required</h1>',
      'text/html; charset=utf-8'
    );
    return;
  }

  if (request.method === 'GET' && requestUrl.pathname === '/') {
    const page = renderPage();
    const headers = authorize(requestUrl)
      ? { 'set-cookie': `ui-compare-key=${encodeURIComponent(token)}; HttpOnly; SameSite=Strict; Path=/` }
      : {};
    send(response, 200, page.html, 'text/html; charset=utf-8', headers);
    return;
  }

  if (request.method === 'GET' && requestUrl.pathname === '/meta') {
    const screen = latestScreen();
    sendJson(response, 200, { version: screenVersion(screen), screen: screen?.name || null });
    return;
  }

  if (request.method === 'GET' && requestUrl.pathname.startsWith('/files/')) {
    serveFile(response, requestUrl.pathname);
    return;
  }

  if (request.method === 'POST' && requestUrl.pathname === '/events') {
    try {
      const event = JSON.parse(await readBody(request));
      event.serverTimestamp = Date.now();
      fs.appendFileSync(eventsFile, `${JSON.stringify(event)}\n`, { mode: 0o600 });
      sendJson(response, 202, { status: 'recorded' });
    } catch (error) {
      sendJson(response, 400, { error: error.message });
    }
    return;
  }

  sendJson(response, 404, { error: 'not found' });
});

function openBrowser(url) {
  if (!shouldOpen) return;
  const command = process.env.BROWSER || 'xdg-open';
  try {
    const child = spawn(command, [url], { detached: true, stdio: 'ignore' });
    child.unref();
  } catch (error) {
    // The URL is still printed for remote or headless environments.
  }
}

function stop(reason) {
  const record = JSON.stringify({ reason, timestamp: Date.now() });
  try {
    fs.writeFileSync(stoppedFile, `${record}\n`, { mode: 0o600 });
    fs.rmSync(serverInfoFile, { force: true });
    fs.rmSync(pidFile, { force: true });
  } finally {
    server.close(() => process.exit(0));
    setTimeout(() => process.exit(0), 1000).unref();
  }
}

server.listen(0, host, () => {
  const address = server.address();
  const displayHost = urlHost.includes(':') && !urlHost.startsWith('[') ? `[${urlHost}]` : urlHost;
  const url = `http://${displayHost}:${address.port}/?key=${token}`;
  const info = {
    type: 'server-started',
    port: address.port,
    url,
    session_dir: sessionDir,
    screen_dir: contentDir,
    state_dir: stateDir
  };

  fs.writeFileSync(pidFile, `${process.pid}\n`, { mode: 0o600 });
  fs.writeFileSync(serverInfoFile, `${JSON.stringify(info)}\n`, { mode: 0o600 });
  process.stdout.write(`${JSON.stringify(info)}\n`);
  openBrowser(url);
});

server.on('error', (error) => {
  process.stderr.write(`${error.stack || error.message}\n`);
  process.exit(1);
});

const idleTimer = setInterval(() => {
  if (Date.now() - lastActivity >= idleTimeoutMs) {
    stop('idle_timeout');
  }
}, Math.min(60000, Math.max(1000, Math.floor(idleTimeoutMs / 4))));
idleTimer.unref();

process.on('SIGINT', () => stop('sigint'));
process.on('SIGTERM', () => stop('sigterm'));
