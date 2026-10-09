// The library: every fetched asset lands in library/<source>/<pack>/... with a manifest entry
// recording where it came from and under which license. library/index.json is committed so the
// attribution travels with the repo.
import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import { DIRS, ROOT, rel, safeJoin } from './paths.js';

const INDEX = path.join(DIRS.library, 'index.json');
const IMAGE_RE = /\.(png|jpe?g|gif|webp|svg|txt)$/i;

export async function readIndex() {
  try { return JSON.parse(await fs.readFile(INDEX, 'utf8')); } catch { return { assets: {} }; }
}

export async function writeIndex(idx) {
  await fs.mkdir(DIRS.library, { recursive: true });
  await fs.writeFile(INDEX, JSON.stringify(idx, null, 2) + '\n');
}

/**
 * Record an asset in the index. entry = { path (repo-relative), source, pack, title, license, author, url, tags[] }
 */
export async function addToIndex(entries) {
  const idx = await readIndex();
  for (const e of entries) idx.assets[e.path] = { ...idx.assets[e.path], ...e, addedAt: idx.assets[e.path]?.addedAt || new Date().toISOString() };
  await writeIndex(idx);
  return idx;
}

/** Walk library/ and sprites/, merging index metadata. Returns [{path, name, source, pack, license, ...}] */
export async function listLibrary(filter = '') {
  const idx = await readIndex();
  const files = [];
  for (const base of [DIRS.library, DIRS.sprites]) {
    for (const f of await walk(base)) if (IMAGE_RE.test(f)) files.push(f);
  }
  const q = filter.toLowerCase().split(/\s+/).filter(Boolean);
  const out = [];
  for (const abs of files) {
    const p = rel(abs);
    const meta = idx.assets[p] || {};
    const parts = p.split('/');
    const entry = {
      path: p,
      name: path.basename(p).replace(/\.[^.]+$/, ''),
      source: meta.source || (parts[0] === 'sprites' ? 'sprites' : parts[1] || 'local'),
      pack: meta.pack || (parts[0] === 'library' ? parts[2] || '' : ''),
      license: meta.license || (parts[0] === 'sprites' ? 'ours' : 'unknown'),
      author: meta.author || '', url: meta.url || '', tags: meta.tags || [],
    };
    const hay = `${entry.path} ${entry.pack} ${entry.source} ${entry.tags.join(' ')}`.toLowerCase();
    if (q.every(t => hay.includes(t))) out.push(entry);
  }
  out.sort((a, b) => a.path.localeCompare(b.path));
  return out;
}

export async function walk(dir) {
  const out = [];
  let ents = [];
  try { ents = await fs.readdir(dir, { withFileTypes: true }); } catch { return out; }
  for (const e of ents) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) out.push(...await walk(p));
    else out.push(p);
  }
  return out;
}

/** Save a downloaded buffer into library/<source>/<pack>/<name> and index it. Returns repo-relative path. */
export async function saveAsset(buf, { source, pack, name, ...meta }) {
  const dir = safeJoin(DIRS.library, path.join(slug(source), slug(pack || 'misc')));
  await fs.mkdir(dir, { recursive: true });
  const abs = safeJoin(dir, safeName(name));
  await fs.writeFile(abs, buf);
  const p = rel(abs);
  await addToIndex([{ path: p, source, pack, ...meta }]);
  return p;
}

export function slug(s) { return String(s).toLowerCase().replace(/[^a-z0-9._-]+/g, '-').replace(/^-+|-+$/g, '') || 'x'; }
export function safeName(s) { return path.basename(String(s)).replace(/[^\w.-]+/g, '_'); }
export function sha1(buf) { return crypto.createHash('sha1').update(buf).digest('hex'); }

/** Download with a cache keyed by URL hash under cache/downloads. */
export async function download(url, { headers = {}, force = false } = {}) {
  const dir = path.join(DIRS.cache, 'downloads');
  await fs.mkdir(dir, { recursive: true });
  const file = path.join(dir, sha1(url) + path.extname(new URL(url).pathname).slice(0, 8));
  if (!force) { try { return await fs.readFile(file); } catch {} }
  const res = await fetch(url, { headers: { 'user-agent': 'the-warehouse/0.1 (+asset tool)', ...headers } });
  if (!res.ok) throw new Error(`GET ${url} -> ${res.status}`);
  const buf = Buffer.from(await res.arrayBuffer());
  await fs.writeFile(file, buf);
  return buf;
}

export async function fetchText(url, headers = {}) {
  const res = await fetch(url, { headers: { 'user-agent': 'the-warehouse/0.1 (+asset tool)', accept: 'text/html,application/json,*/*', ...headers } });
  if (!res.ok) throw new Error(`GET ${url} -> ${res.status}`);
  return res.text();
}

export { ROOT };
