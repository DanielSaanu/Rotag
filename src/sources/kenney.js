// Kenney.nl: CC0 game asset packs. No API; we read the public pages and download the pack zip,
// then unpack every PNG into library/kenney/<pack>/.
import { unzipSync } from 'fflate';
import { download, fetchText, saveAsset } from '../library.js';

export const id = 'kenney';
export const name = 'Kenney';
export const license = 'CC0';
export const about = 'Thousands of CC0 sprites, tiles, UI and 3D packs. Fetch a whole pack at once.';
export const kinds = ['pack'];

// Hand-picked packs that fit a 2D pixel Roblox game. Search works without the network for these.
export const CURATED = [
  { id: 'tiny-dungeon', title: 'Tiny Dungeon', tags: 'pixel 16x16 roguelike dungeon characters monsters items tiles' },
  { id: 'tiny-town', title: 'Tiny Town', tags: 'pixel 16x16 town buildings trees roads tiles' },
  { id: 'tiny-battle', title: 'Tiny Battle', tags: 'pixel 16x16 units war strategy tiles' },
  { id: 'tiny-ski', title: 'Tiny Ski', tags: 'pixel 16x16 snow winter tiles' },
  { id: 'micro-roguelike', title: 'Micro Roguelike', tags: 'pixel 8x8 roguelike dungeon tiny' },
  { id: '1-bit-pack', title: '1-Bit Pack', tags: 'pixel 16x16 monochrome roguelike huge tileset' },
  { id: 'pixel-platformer', title: 'Pixel Platformer', tags: 'pixel 18x18 platformer tiles characters' },
  { id: 'pixel-platformer-industrial-expansion', title: 'Pixel Platformer Industrial', tags: 'pixel platformer factory' },
  { id: 'pixel-shmup', title: 'Pixel Shmup', tags: 'pixel ships space shooter' },
  { id: 'pixel-ui-pack', title: 'Pixel UI Pack', tags: 'pixel ui buttons panels icons' },
  { id: 'ui-pack-pixel-adventure', title: 'UI Pack Pixel Adventure', tags: 'pixel ui buttons hud rpg' },
  { id: 'roguelike-caves-dungeons', title: 'Roguelike Caves & Dungeons', tags: 'pixel 16x16 roguelike caves dungeon' },
  { id: 'roguelike-characters', title: 'Roguelike Characters', tags: 'pixel 16x16 roguelike characters clothes' },
  { id: 'roguelike-rpg-pack', title: 'Roguelike RPG Pack', tags: 'pixel 16x16 roguelike rpg environment 1700 tiles' },
  { id: 'roguelike-modern-city', title: 'Roguelike Modern City', tags: 'pixel 16x16 roguelike city urban' },
  { id: 'roguelike-indoors', title: 'Roguelike Indoors', tags: 'pixel 16x16 roguelike interior furniture' },
  { id: 'monochrome-rpg', title: 'Monochrome RPG', tags: 'pixel 16x16 monochrome rpg' },
  { id: 'scribble-dungeons', title: 'Scribble Dungeons', tags: 'sketch dungeon roguelike tiles' },
  { id: 'game-icons', title: 'Game Icons', tags: 'icons ui flat white' },
  { id: 'input-prompts-pixel-16', title: 'Input Prompts Pixel 16', tags: 'pixel keyboard gamepad buttons prompts' },
  { id: 'emotes-pack', title: 'Emotes Pack', tags: 'emotes speech bubbles pixel' },
  { id: 'particle-pack', title: 'Particle Pack', tags: 'particles effects smoke fire' },
  { id: 'simple-space', title: 'Simple Space', tags: 'space ships flat' },
];

export async function search(query = '', { online = true } = {}) {
  const q = query.toLowerCase().split(/\s+/).filter(Boolean);
  let results = CURATED.filter(p => q.every(t => `${p.id} ${p.title} ${p.tags}`.toLowerCase().includes(t)))
    .map(p => ({ id: p.id, source: id, title: p.title, kind: 'pack', license, author: 'Kenney', url: `https://kenney.nl/assets/${p.id}`, thumb: `https://kenney.nl/media/pages/assets/${p.id}/preview.png`, tags: p.tags }));
  if (online && query) {
    try {
      const html = await fetchText(`https://kenney.nl/assets?search=${encodeURIComponent(query)}`);
      const seen = new Set(results.map(r => r.id));
      for (const m of html.matchAll(/href="\/assets\/([a-z0-9-]+)"[^>]*>([\s\S]*?)<\/a>/g)) {
        const slug = m[1];
        if (seen.has(slug) || ['page', 'category'].includes(slug)) continue;
        const title = (m[2].match(/<h3[^>]*>([^<]+)</) || m[2].match(/alt="([^"]+)"/) || [])[1] || slug;
        seen.add(slug);
        results.push({ id: slug, source: id, title: title.trim(), kind: 'pack', license, author: 'Kenney', url: `https://kenney.nl/assets/${slug}`, thumb: '' });
      }
    } catch (e) {
      results.push({ id: '', source: id, title: `(online search failed: ${e.message})`, kind: 'error' });
    }
  }
  return results;
}

/** Download a pack zip and unpack every image into library/kenney/<slug>/ */
export async function fetch(slug, { onProgress = () => {} } = {}) {
  const page = await fetchText(`https://kenney.nl/assets/${slug}`);
  const zipUrl = (page.match(/href=["'](https?:\/\/kenney\.nl\/media\/pages\/assets\/[^"']+\.zip)["']/) || page.match(/href=["']([^"']+\.zip)["']/) || [])[1];
  if (!zipUrl) throw new Error(`no zip link found on https://kenney.nl/assets/${slug}. Open it in a browser, download the zip and drop the PNGs in library/kenney/${slug}/`);
  const abs = zipUrl.startsWith('http') ? zipUrl : new URL(zipUrl, 'https://kenney.nl').href;
  onProgress(`downloading ${abs}`);
  const buf = await download(abs);
  return unpackZip(buf, { source: id, pack: slug, license, author: 'Kenney', url: `https://kenney.nl/assets/${slug}` }, onProgress);
}

export async function unpackZip(buf, meta, onProgress = () => {}) {
  const files = unzipSync(new Uint8Array(buf));
  const paths = [];
  for (const [name, data] of Object.entries(files)) {
    if (!/\.(png|svg|jpe?g)$/i.test(name) || name.includes('__MACOSX') || /preview|sample/i.test(name)) continue;
    // keep the inner folder structure flattened to 2 levels: Tiles/tile_0001.png -> tiles__tile_0001.png
    const flat = name.split('/').filter(Boolean).slice(-2).join('__');
    const p = await saveAsset(Buffer.from(data), { ...meta, name: flat, tags: name.toLowerCase().split(/[\/_.\s-]+/).filter(Boolean) });
    paths.push(p);
    if (paths.length % 50 === 0) onProgress(`${paths.length} files`);
  }
  return { paths, count: paths.length };
}
