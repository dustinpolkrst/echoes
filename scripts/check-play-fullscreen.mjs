// Headed Chrome check for the Play page fullscreen control.
// Serves devblog/content/play.md with devblog/static/css/site.css. The iframe is web/index.html,
// plus a capture listener that cancels Escape the way love.js does, so the browser will not
// leave fullscreen unless the page exits on purpose. In-game F stays the handler in web/index.html.

import { createRequire } from 'node:module';
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const require = createRequire(import.meta.url);
const puppeteer = require('puppeteer-core');

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const playMd = fs.readFileSync(path.join(root, 'devblog/content/play.md'), 'utf8');
const start = playMd.indexOf('<div class="game">');
const end = playMd.indexOf('</script>');
if (start < 0 || end < 0) {
  console.error('play page markup not found');
  process.exit(1);
}
const fragment = playMd.slice(start, end + '</script>'.length);
const pageHtml = `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Play Echoes</title>
<link rel="stylesheet" href="/css/site.css">
</head>
<body>
<main class="wrap">
${fragment}
</main>
</body>
</html>
`;

const gameHtml = fs.readFileSync(path.join(root, 'web/index.html'), 'utf8').replace(
  '</body>',
  `<script>
window.addEventListener('keydown', function (e) {
  if (e.key === 'Escape') {
    e.preventDefault();
    window.__echoesKeys = (window.__echoesKeys || '') + 'Escape';
  } else if ((e.key === 'f' || e.key === 'F') && !e.repeat) {
    window.__echoesKeys = (window.__echoesKeys || '') + 'f';
  }
}, true);
</script>
</body>`
);

const mime = {
  '.css': 'text/css',
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript',
  '.png': 'image/png',
  '.svg': 'image/svg+xml',
  '.woff2': 'font/woff2',
};

function staticFile(urlPath) {
  const rel = path.normalize(decodeURIComponent(urlPath)).replace(/^(\.\.(\/|\\|$))+/, '');
  const file = path.join(root, 'devblog/static', rel);
  if (!file.startsWith(path.join(root, 'devblog/static'))) return null;
  return fs.existsSync(file) && fs.statSync(file).isFile() ? file : null;
}

const server = http.createServer((req, res) => {
  const url = req.url.split('?')[0];
  if (url === '/play') {
    res.writeHead(302, { Location: '/play/' });
    res.end();
    return;
  }
  if (url === '/play/' || url === '/play/index.html') {
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
    res.end(pageHtml);
    return;
  }
  if (url === '/play/game' || url === '/play/game/' || url === '/play/game/index.html') {
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
    res.end(gameHtml);
    return;
  }
  const file = staticFile(url);
  if (!file) {
    res.writeHead(404);
    res.end('not found');
    return;
  }
  res.writeHead(200, { 'Content-Type': mime[path.extname(file)] || 'application/octet-stream' });
  res.end(fs.readFileSync(file));
});

await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
const port = server.address().port;
const base = `http://127.0.0.1:${port}`;

const chrome = process.env.CHROME_PATH || '/usr/bin/google-chrome';
const browser = await puppeteer.launch({
  executablePath: chrome,
  headless: false,
  args: ['--no-sandbox', '--disable-dev-shm-usage', '--window-size=1100,520'],
  defaultViewport: { width: 1100, height: 520 },
});

const checks = [];
function report(name, ok, detail) {
  checks.push(ok);
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}${detail ? '  ' + detail : ''}`);
}

let page;
try {
  page = await browser.newPage();
  page.setDefaultTimeout(8000);
  await page.goto(`${base}/play/`, { waitUntil: 'networkidle0' });
  await page.waitForSelector('#echoes-full');
  await page.waitForFunction(() => {
    const frame = document.getElementById('echoes');
    try {
      return !!(frame && frame.contentDocument && frame.contentDocument.getElementById('canvas'));
    } catch (e) {
      return false;
    }
  });

  const gameFrame = () => page.frames().find((frame) => frame.url().includes('/play/game'));

  async function focusGame() {
    const frame = gameFrame();
    await frame.evaluate(() => {
      window.focus();
      const canvas = document.getElementById('canvas');
      if (canvas) canvas.focus();
    });
    return frame;
  }

  async function snapshot() {
    const frame = gameFrame();
    const parent = await page.evaluate(() => {
      const el = document.fullscreenElement || document.webkitFullscreenElement;
      const btn = document.getElementById('echoes-full');
      const rect = btn.getBoundingClientRect();
      const cx = rect.left + rect.width / 2;
      const cy = rect.top + rect.height / 2;
      return {
        tag: el ? (el.className || el.tagName) : '',
        id: el ? el.id : '',
        buttonInFullscreen: !!(el && el.contains(btn)),
        buttonOnScreen: rect.width > 2 && rect.height > 2 && cx >= 0 && cy >= 0 && cx <= window.innerWidth && cy <= window.innerHeight,
        note: document.getElementById('echoes-note').textContent,
        top: Math.round(rect.top),
        bottom: Math.round(rect.bottom),
        height: window.innerHeight,
      };
    });
    const inner = await frame.evaluate(() => {
      const el = document.fullscreenElement || document.webkitFullscreenElement;
      return { inner: el ? el.tagName : '', keys: window.__echoesKeys || '' };
    });
    return { parent, inner };
  }

  async function hasFs() {
    return page.evaluate(() => !!(document.fullscreenElement || document.webkitFullscreenElement));
  }

  async function waitFs(want, timeout = 2500) {
    const started = Date.now();
    while (Date.now() - started < timeout) {
      if ((await hasFs()) === want) return true;
      await new Promise((resolve) => setTimeout(resolve, 40));
    }
    return (await hasFs()) === want;
  }

  console.log('check-play-fullscreen');
  console.log(`page ${base}/play/`);

  await focusGame();
  await page.keyboard.press('f');
  const fEntered = await waitFs(true);
  let state = await snapshot();
  const fOnIframe = fEntered && state.inner.inner === 'HTML' && state.parent.id === 'echoes';
  report('in-game F fullscreens the iframe document', fOnIframe, `parent=${state.parent.id || state.parent.tag} inner=${state.inner.inner} keys=${state.inner.keys}`);
  console.log('FULLSCREEN afterF ' + JSON.stringify({ parent: state.parent, inner: state.inner }));

  await focusGame();
  await page.keyboard.press('f');
  const fLeft = await waitFs(false);
  state = await snapshot();
  report('in-game F leaves iframe fullscreen', fLeft && state.inner.inner === '' && state.parent.tag === '', `parent=${state.parent.tag || '(none)'} inner=${state.inner.inner || '(none)'} keys=${state.inner.keys}`);

  await page.click('#echoes-full');
  await waitFs(true);
  state = await snapshot();
  console.log('FULLSCREEN first ' + JSON.stringify(state.parent));
  const entered = state.parent.tag !== '' && !state.parent.note.startsWith('This browser would not go fullscreen');
  report('Fullscreen button enters fullscreen', entered, `tag=${state.parent.tag || '(none)'} note=${JSON.stringify(state.parent.note)}`);
  report('Fullscreen button stays on screen', state.parent.buttonInFullscreen && state.parent.buttonOnScreen, `buttonInFullscreen=${state.parent.buttonInFullscreen} buttonOnScreen=${state.parent.buttonOnScreen} top=${state.parent.top} bottom=${state.parent.bottom} height=${state.parent.height}`);

  let secondError = '';
  try {
    await page.click('#echoes-full', { timeout: 3000 });
  } catch (err) {
    secondError = err.message.split('\n')[0];
  }
  const secondLeft = await waitFs(false);
  state = await snapshot();
  console.log('FULLSCREEN secondClick ' + JSON.stringify({ ...state.parent, click: secondError }));
  report('second Fullscreen activation leaves fullscreen', secondLeft && state.parent.tag === '', `tag=${state.parent.tag || '(none)'}${secondError ? ' click=' + secondError : ''}`);

  if (!(await hasFs())) {
    await page.click('#echoes-full');
    await waitFs(true);
  }
  await focusGame();
  await page.keyboard.press('Escape');
  const escLeft = await waitFs(false);
  state = await snapshot();
  console.log('FULLSCREEN escWhilePageFullscreen ' + JSON.stringify({ parent: state.parent.tag, keys: state.inner.keys, buttonInFullscreen: state.parent.buttonInFullscreen }));
  report('Esc leaves page fullscreen', escLeft && state.parent.tag === '', `parent=${state.parent.tag || '(none)'} keys=${state.inner.keys}`);

  const refused = (await page.evaluate(() => document.getElementById('echoes-note').textContent)).startsWith('This browser would not go fullscreen');
  report('fullscreen was not refused', !refused);
} catch (err) {
  console.error('ERROR ' + (err && err.stack ? err.stack : err));
  checks.push(false);
} finally {
  await browser.close();
  server.close();
}

const failed = checks.filter((ok) => !ok).length;
console.log(failed ? `FAILED ${failed}` : 'all checks passed');
process.exit(failed ? 1 : 0);
