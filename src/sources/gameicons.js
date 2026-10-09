// game-icons.net: ~4000 CC-BY 3.0 SVG icons (swords, potions, skulls, UI glyphs). Mirrored on GitHub.
// We pull the repo tree once (cached), search names locally, and fetch single SVGs on demand.
import fs from 'node:fs/promises';
import path from 'node:path';
import { DIRS } from '../paths.js';
import { download, saveAsset } from '../library.js';

export const id = 'gameicons';
export const name = 'game-icons.net';
export const license = 'CC-BY-3.0 (credit the author and game-icons.net)';
export const about = '4000+ crisp SVG icons for items, UI, logos. Recolor freely.';
export const kinds = ['image'];

// Offline fallback (verified to exist) so search still works when api.github.com is unreachable.
const FALLBACK = ["lorc/potion-ball", "lorc/crossed-swords", "lorc/heart-bottle", "lorc/campfire", "lorc/scorpion", "lorc/wolf-head", "lorc/dragon-head", "lorc/treasure-map", "lorc/key", "lorc/locked-chest", "lorc/gems", "lorc/meat", "lorc/mushroom-gills", "lorc/mushroom", "lorc/moon", "lorc/sun", "lorc/sunrise", "lorc/crown", "lorc/bird-claw", "lorc/snake", "lorc/frog", "lorc/lizardman", "lorc/footprint", "lorc/broken-bone", "lorc/arrow-cluster", "lorc/lantern", "delapouite/brick-wall", "delapouite/stairs", "lorc/wooden-door", "lorc/droplets", "lorc/wave-crest", "lorc/whirlwind", "lorc/tornado", "lorc/hourglass", "lorc/padlock", "lorc/hand", "lorc/run", "delapouite/walk", "lorc/scarab-beetle", "delapouite/ant", "delapouite/fly", "lorc/spider-web", "lorc/cog", "lorc/sword-wound", "lorc/sprout", "lorc/pine-tree", "lorc/flower-pot", "lorc/fishing-hook", "lorc/sharp-crown", "lorc/sunbeams", "lorc/on-target", "delapouite/info", "delapouite/speaker", "delapouite/settings-knobs"].map(p => p + '.svg');

const TREE = 'https://api.github.com/repos/game-icons/icons/git/trees/master?recursive=1';
const RAW = 'https://raw.githubusercontent.com/game-icons/icons/master/';

async function loadIndex() {
  const file = path.join(DIRS.cache, 'gameicons-index.json');
  try { return JSON.parse(await fs.readFile(file, 'utf8')); } catch {}
  let res;
  try { res = await globalThis.fetch(TREE, { headers: { 'user-agent': 'the-warehouse/0.1', accept: 'application/vnd.github+json' } }); } catch (e) { res = { ok: false, status: e.message }; }
  if (!res.ok) { console.warn(`game-icons: GitHub tree ${res.status}; using built-in fallback list (${FALLBACK.length} icons). Any author/name.svg path still fetches.`); return FALLBACK; }
  const json = await res.json();
  const icons = json.tree.filter(t => t.type === 'blob' && t.path.endsWith('.svg')).map(t => t.path);
  await fs.mkdir(DIRS.cache, { recursive: true });
  await fs.writeFile(file, JSON.stringify(icons));
  return icons;
}

export async function search(query, { limit = 60 } = {}) {
  const icons = await loadIndex();
  const q = query.toLowerCase().split(/\s+/).filter(Boolean);
  const hits = icons.filter(p => { const n = p.toLowerCase(); return q.every(t => n.includes(t)); }).slice(0, limit);
  return hits.map(p => {
    const [author, file] = p.split('/');
    const iconName = file.replace(/\.svg$/, '');
    return { id: p, source: id, title: iconName, kind: 'image', license: 'CC-BY-3.0', author, url: `https://game-icons.net/1x1/${author}/${iconName}.html`, thumb: RAW + p };
  });
}

export async function fetch(iconPath) {
  const buf = await download(RAW + iconPath);
  const [author] = iconPath.split('/');
  const p = await saveAsset(buf, { source: id, pack: author, name: path.basename(iconPath), license: 'CC-BY-3.0', author, url: `https://game-icons.net/` });
  return { paths: [p], count: 1 };
}
