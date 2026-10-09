// Every source implements: { id, name, license, needsKey?, search(query, opts) -> [Result], fetch(id, opts) -> {paths:[...]} }
// Result = { id, source, title, thumb, license, author, url, kind: 'pack'|'image'|'palette'|'font' }
import * as kenney from './kenney.js';
import * as opengameart from './opengameart.js';
import * as gameicons from './gameicons.js';
import * as lospec from './lospec.js';
import * as local from './local.js';
import * as fonts from './fonts.js';

export const SOURCES = { kenney, opengameart, gameicons, lospec, fonts, local };

export function getSource(id) {
  const s = SOURCES[id];
  if (!s) throw new Error(`unknown source "${id}". Known: ${Object.keys(SOURCES).join(', ')}`);
  return s;
}

export function describeSources() {
  return Object.values(SOURCES).map(s => ({ id: s.id, name: s.name, license: s.license, about: s.about, kinds: s.kinds }));
}
