import { FONTS, ensureFontFile } from '../fonts.js';
export const id = 'fonts';
export const name = 'Fonts';
export const license = 'OFL / Apache';
export const about = 'Curated free fonts for logos and UI text. Use the name in a text layer.';
export const kinds = ['font'];
export async function search(query = '') {
  const q = query.toLowerCase();
  return Object.entries(FONTS).filter(([n, s]) => !q || `${n} ${s.style}`.toLowerCase().includes(q))
    .map(([n, s]) => ({ id: n, source: id, title: n, kind: 'font', license: s.license, url: s.url, thumb: '', style: s.style }));
}
export async function fetch(family) { const file = await ensureFontFile(family); return { paths: [file], count: 1 }; }
