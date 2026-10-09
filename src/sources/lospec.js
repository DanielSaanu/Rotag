// LoSpec palette list. Palettes are the cheapest way to make borrowed sprites look like one game:
// fetch a palette, then recolor layers to it.
import fs from 'node:fs/promises';
import path from 'node:path';
import { DIRS } from '../paths.js';
import { fetchText } from '../library.js';

export const id = 'lospec';
export const name = 'LoSpec palettes';
export const license = 'free to use';
export const about = 'Pixel art color palettes. Fetch one, then recolor sprites to it.';
export const kinds = ['palette'];

export async function search(query, { page = 0 } = {}) {
  const url = `https://lospec.com/palette-list/load?colorNumberFilterType=any&colorNumber=8&page=${page}&tag=${encodeURIComponent(query)}&sortingType=default`;
  const json = JSON.parse(await fetchText(url, { accept: 'application/json' }));
  return (json.palettes || []).map(p => ({
    id: p.slug, source: id, title: p.title, kind: 'palette', license: 'free', author: p.user?.name || '', url: `https://lospec.com/palette-list/${p.slug}`,
    colors: (p.colors || []).map(c => '#' + c.replace('#', '')), thumb: '',
  }));
}

export async function fetch(slug) {
  const json = JSON.parse(await fetchText(`https://lospec.com/palette-list/${slug}.json`, { accept: 'application/json' }));
  const pal = { name: json.name, slug, author: json.author, colors: json.colors.map(c => '#' + c.toLowerCase()) };
  const dir = path.join(DIRS.library, 'palettes');
  await fs.mkdir(dir, { recursive: true });
  const file = path.join(dir, slug + '.json');
  await fs.writeFile(file, JSON.stringify(pal, null, 2) + '\n');
  return { paths: ['library/palettes/' + slug + '.json'], count: 1, palette: pal };
}

export async function listLocal() {
  const dir = path.join(DIRS.library, 'palettes');
  let files = [];
  try { files = await fs.readdir(dir); } catch { return []; }
  const out = [];
  for (const f of files) if (f.endsWith('.json')) out.push(JSON.parse(await fs.readFile(path.join(dir, f), 'utf8')));
  return out;
}
