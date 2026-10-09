// Local server: serves the UI, shared render modules, repo files, and a small JSON API.
// Everything the UI does ends up as files in scenes/, ideas/, sprites/, library/ so Claude can read it.
import http from 'node:http';
import fs from 'node:fs/promises';
import path from 'node:path';
import { exec } from 'node:child_process';
import { DIRS, ROOT, safeJoin, rel } from './paths.js';
import { listScenes, loadScene, saveScene, deleteScene, sceneMtime, listIdeas, loadIdeas, saveIdeas, ideasMtime, sceneName } from './store.js';
import { getSource, describeSources } from './sources/index.js';
import { listLocal as listPalettes } from './sources/lospec.js';
import { listLibrary, saveAsset } from './library.js';
import { makeNodeEnv } from './node-env.js';
import { renderScene } from './render.js';
import { buildRoblox } from './build.js';
import { FONTS, ensureFontFile } from './fonts.js';
import { validateScene } from './scene.js';

const MIME = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.css': 'text/css; charset=utf-8', '.json': 'application/json; charset=utf-8', '.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.gif': 'image/gif', '.webp': 'image/webp', '.svg': 'image/svg+xml', '.txt': 'text/plain; charset=utf-8', '.md': 'text/markdown; charset=utf-8', '.ttf': 'font/ttf', '.lua': 'text/plain; charset=utf-8' };

export function startServer({ port = 4242, open = true } = {}) {
  const server = http.createServer((req, res) => handle(req, res).catch(e => json(res, 500, { error: e.message })));
  server.listen(port, '127.0.0.1', () => {
    const url = `http://localhost:${port}`;
    console.log(`The Warehouse is open at ${url}\n  scenes/ ideas/ sprites/ library/ are the shared workspace. Ctrl+C to stop.`);
    if (open) openBrowser(url);
  });
  return server;
}

function openBrowser(url) {
  const cmd = process.platform === 'win32' ? `start "" "${url}"` : process.platform === 'darwin' ? `open "${url}"` : `xdg-open "${url}"`;
  exec(cmd, () => {});
}

async function handle(req, res) {
  const url = new URL(req.url, 'http://x');
  const p = url.pathname;
  if (req.method === 'GET' && (p === '/' || p === '/index.html')) return file(res, path.join(DIRS.ui, 'index.html'));
  if (p === '/favicon.ico') { res.writeHead(204); return res.end(); }
  if (req.method === 'GET' && p.startsWith('/ui/')) return file(res, safeJoin(DIRS.ui, p.slice(4)));
  if (req.method === 'GET' && p.startsWith('/src/')) return file(res, safeJoin(DIRS.src, p.slice(5)));
  if (req.method === 'GET' && p.startsWith('/files/')) {
    const relPath = decodeURIComponent(p.slice(7));
    if (!/^(library|sprites|scenes|exports|ideas)\//.test(relPath)) return json(res, 403, { error: 'only library/ sprites/ scenes/ exports/ ideas/ are served' });
    return file(res, safeJoin(ROOT, relPath));
  }
  if (req.method === 'GET' && p.startsWith('/fonts/')) {
    const family = decodeURIComponent(p.slice(7)).replace(/\.ttf$/, '');
    if (!FONTS[family]) return json(res, 404, { error: 'unknown font' });
    return file(res, await ensureFontFile(family));
  }
  if (!p.startsWith('/api/')) return json(res, 404, { error: 'not found' });
  const route = p.slice(5).split('/').map(decodeURIComponent);
  const body = req.method === 'PUT' || req.method === 'POST' ? await readJson(req) : null;

  switch (route[0]) {
    case 'state': return json(res, 200, { scenes: await listScenes(), ideas: await listIdeas(), sources: describeSources(), fonts: Object.keys(FONTS), palettes: await listPalettes(), root: ROOT });
    case 'scenes': {
      const name = route[1];
      if (!name) return json(res, 200, { scenes: await listScenes() });
      if (req.method === 'GET') {
        const [scene, mtime] = await Promise.all([loadScene(name).catch(() => null), sceneMtime(name)]);
        return scene ? json(res, 200, { scene, mtime }) : json(res, 404, { error: 'no such scene' });
      }
      if (req.method === 'PUT') {
        const errs = validateScene(body.scene);
        if (errs.length && !body.force) return json(res, 400, { error: errs.join('; ') });
        return json(res, 200, { mtime: await saveScene(name, body.scene) });
      }
      if (req.method === 'DELETE') { await deleteScene(name); return json(res, 200, { ok: true }); }
      break;
    }
    case 'ideas': {
      const name = route[1] || 'INBOX';
      if (req.method === 'GET') return json(res, 200, { text: await loadIdeas(name), mtime: await ideasMtime(name) });
      if (req.method === 'PUT') { await saveIdeas(name, body.text || ''); return json(res, 200, { mtime: await ideasMtime(name) }); }
      break;
    }
    case 'search': {
      const source = url.searchParams.get('source') || 'local', q = url.searchParams.get('q') || '';
      try { return json(res, 200, { results: await getSource(source).search(q) }); }
      catch (e) { return json(res, 200, { results: [], error: e.message }); }
    }
    case 'fetch': {
      const log = [];
      try { const r = await getSource(body.source).fetch(body.id, { onProgress: m => log.push(m) }); return json(res, 200, { ...r, log }); }
      catch (e) { return json(res, 500, { error: e.message, log }); }
    }
    case 'library': return json(res, 200, { items: await listLibrary(url.searchParams.get('q') || '') });
    case 'upload': {
      // { name, dataUrl } from a file input or a drag-drop
      const m = String(body.dataUrl || '').match(/^data:(image\/[\w+.-]+);base64,(.+)$/);
      if (!m) return json(res, 400, { error: 'expected a data URL' });
      const buf = Buffer.from(m[2], 'base64');
      const saved = await saveAsset(buf, { source: 'local', pack: body.pack || 'uploads', name: body.name || 'upload.png', license: body.license || 'yours', author: body.author || '' });
      return json(res, 200, { path: saved });
    }
    case 'sprite': {
      // Save a pixels layer as a reusable sprites/<name>.txt
      const name = sceneName(body.name || 'sprite');
      await fs.mkdir(DIRS.sprites, { recursive: true });
      await fs.writeFile(safeJoin(DIRS.sprites, name + '.txt'), body.text || '');
      return json(res, 200, { path: `sprites/${name}.txt` });
    }
    case 'render': {
      // Server-side render of a scene object: what Claude sees. Returns PNG.
      const env = makeNodeEnv();
      const r = await renderScene(body.scene, env, { scale: Number(body.scale) || 1 });
      res.writeHead(200, { 'content-type': 'image/png', 'cache-control': 'no-store' });
      return res.end(r.canvas.toBuffer('image/png'));
    }
    case 'roblox': {
      if (route[1] === 'build') {
        const log = [];
        try { const r = await buildRoblox({ upload: !!body?.upload, log: m => log.push(m) }); return json(res, 200, { ok: true, log, sheets: r.sheets.length, sprites: r.items, assetIds: r.assetIds }); }
        catch (e) { return json(res, 500, { error: e.message, log }); }
      }
      break;
    }
    case 'files': {
      // Generic listing for the library pane.
      const items = await listLibrary(url.searchParams.get('q') || '');
      return json(res, 200, { items });
    }
  }
  return json(res, 404, { error: `no route ${req.method} ${p}` });
}

async function file(res, abs) {
  try {
    const data = await fs.readFile(abs);
    res.writeHead(200, { 'content-type': MIME[path.extname(abs).toLowerCase()] || 'application/octet-stream', 'cache-control': 'no-cache' });
    res.end(data);
  } catch (e) {
    json(res, e.code === 'ENOENT' ? 404 : 500, { error: e.message });
  }
}

function json(res, status, obj) {
  res.writeHead(status, { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store' });
  res.end(JSON.stringify(obj));
}

function readJson(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on('data', c => chunks.push(c));
    req.on('end', () => { try { resolve(chunks.length ? JSON.parse(Buffer.concat(chunks).toString('utf8')) : {}); } catch (e) { reject(new Error('bad JSON body')); } });
    req.on('error', reject);
  });
}
