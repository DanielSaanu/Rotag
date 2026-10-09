// Whatever is already in library/ and sprites/. Drop your own PNGs into library/local/<anything>/.
import { listLibrary } from '../library.js';
export const id = 'local';
export const name = 'Library (already downloaded)';
export const license = 'see index';
export const about = 'Everything on disk in library/ and sprites/.';
export const kinds = ['image'];
export async function search(query = '', { limit = 400 } = {}) {
  const items = await listLibrary(query);
  return items.slice(0, limit).map(i => ({ id: i.path, source: id, title: i.name, kind: 'image', license: i.license, author: i.author, url: i.url, thumb: '/files/' + i.path, path: i.path, pack: i.pack, origin: i.source }));
}
export async function fetch(p) { return { paths: [p], count: 1 }; }
