// Render the patched renderer in headless Chromium with the Electron bridge stubbed and ALL
// network blocked (only files from the local dist folder are served). Screenshots each route
// and lists any visible text that still contains Chinese characters.
// Usage: node shots.js <distDir> <outDir>
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path');
const [dist, out] = process.argv.slice(2).map(p => path.resolve(p));
fs.mkdirSync(out, { recursive: true });
const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.png': 'image/png', '.svg': 'image/svg+xml', '.ttf': 'font/ttf', '.webm': 'video/webm', '.mp4': 'video/mp4', '.jpg': 'image/jpeg' };
const FAKE_DEVICE = { id: 'dev1', name: 'Scorpio', vid: '3206', pid: '7015', hardwareId: 'USB\\VID_3206&PID_7015', supportVolume: '1', supportLight: '1', type: 'wireless' };

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1280, height: 800 } });
  await page.route('**/*', route => {
    const u = new URL(route.request().url());
    if (u.hostname !== 'app.local') return route.abort();
    const f = path.join(dist, decodeURIComponent(u.pathname === '/' ? '/index.html' : u.pathname));
    if (!f.startsWith(dist) || !fs.existsSync(f)) return route.fulfill({ status: 404, body: '' });
    route.fulfill({ status: 200, contentType: MIME[path.extname(f)] || 'application/octet-stream', body: fs.readFileSync(f) });
  });
  await page.addInitScript(() => {
    const noop = () => {};
    window.process = { resourcesPath: 'C:\\OHUB\\resources', platform: 'win32', env: {}, versions: {} };
    const stubs = {
      path: { join: (...a) => a.join('\\'), resolve: (...a) => a.join('\\'), dirname: x => x, basename: x => x },
      regedit: { setExternalVBSLocation: noop, list: (k, cb) => cb && cb(null, {}), promisified: { list: async () => ({}) } },
      fs: { readFileSync: () => '{}', existsSync: () => false },
      electron: { shell: { openExternal: noop } },
    };
    window.require = (m) => stubs[m] || {};
    const ipc = {
      invoke: async (ch) => {
        if (ch === 'get_device') return { list: [], input: [], output: [], default: {} };
        if (ch === 'get-app-version') return '1.0.10';
        if (/get.*volume/.test(ch)) return 50;
        if (/muted/.test(ch)) return false;
        return { ok: false, success: false, supported: false };
      },
      on: noop, once: noop, removeListener: noop, removeAllListeners: noop, send: noop
    };
    window.electron = { ipcRenderer: ipc }; stubs.electron.ipcRenderer = ipc;
  });
  const errors = [];
  page.on('pageerror', e => errors.push(e.message));
  const logs=[]; page.on('console', m => logs.push(m.type()+': '+m.text().slice(0,200)));
  page.on('requestfailed', r => logs.push('FAILED '+r.url().slice(0,120)));
  const routes = ['device', 'volume', 'mic', 'adjust', 'map', 'flash', 'settings', 'common', 'skin', 'about'];
  const report = {};
  await page.goto('http://app.local/index.html');
  await page.waitForTimeout(2500);
  if (process.env.DEBUG) { console.log(logs.slice(0,40).join('\n')); console.log((await page.content()).slice(0,1500)); }
  for (const r of routes) {
    await page.evaluate(r => { location.hash = '#/' + r; }, r);
    await page.waitForTimeout(1500);
    await page.screenshot({ path: path.join(out, r + '.png') });
    const han = await page.evaluate(() => {
      const res = new Set(); const w = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
      while (w.nextNode()) { const v = w.currentNode.nodeValue.trim(); const el = w.currentNode.parentElement;
        if (v && /[㐀-鿿]/.test(v) && el && el.offsetParent !== null) res.add(v); }
      document.querySelectorAll('[placeholder],[title],[aria-label],[alt]').forEach(e => ['placeholder','title','aria-label','alt'].forEach(a => { const v = e.getAttribute(a); if (v && /[㐀-鿿]/.test(v)) res.add(`@${a}: ${v}`); }));
      return [...res];
    });
    report[r] = { url: page.url(), chinese: han };
  }
  console.log(JSON.stringify(report, null, 1));
  console.log('page errors:', errors.slice(0, 5));
  await browser.close();
})();
