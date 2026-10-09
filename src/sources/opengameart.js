// OpenGameArt.org: the big community sprite dump. Licenses VARY per entry (CC0, CC-BY, CC-BY-SA, GPL, OGA-BY).
// We scrape the search page and the entry page. Best effort: if the site changes its HTML, search will
// come back empty and you can still paste an entry URL into fetch().
import { unzipSync } from 'fflate';
import { download, fetchText, saveAsset } from '../library.js';

export const id = 'opengameart';
export const name = 'OpenGameArt';
export const license = 'varies (shown per result)';
export const about = 'Community sprites and tilesets. Check the license badge on each result.';
export const kinds = ['pack', 'image'];

const BASE = 'https://opengameart.org';

export async function search(query, { page = 0 } = {}) {
  const url = `${BASE}/art-search-advanced?keys=${encodeURIComponent(query)}&field_art_type_tid%5B%5D=9&sort_by=score&sort_order=DESC&page=${page}`;
  const html = await fetchText(url);
  const results = [];
  // Result cards are <div class="art-preview"> ... <a href="/content/slug"> ... <img src="...">
  for (const card of html.split(/class="[^"]*art-preview[^"]*"/).slice(1)) {
    const slug = (card.match(/href="\/content\/([^"?#]+)"/) || [])[1];
    if (!slug) continue;
    const title = decode((card.match(/title="([^"]+)"/) || card.match(/>([^<]{3,80})<\/a>/) || [])[1] || slug);
    const thumb = (card.match(/<img[^>]+src="([^"]+)"/) || [])[1] || '';
    const lic = [...card.matchAll(/license[^>]*title="([^"]+)"|alt="((?:CC|GPL|OGA)[^"]*)"/gi)].map(m => m[1] || m[2]).filter(Boolean);
    results.push({ id: slug, source: id, title, kind: 'pack', license: lic.join(', ') || 'see page', url: `${BASE}/content/${slug}`, thumb });
  }
  return results;
}

/** Fetch every attached file from an entry page. id may be a slug or a full URL. */
export async function fetch(slugOrUrl, { onProgress = () => {} } = {}) {
  const url = /^https?:/.test(slugOrUrl) ? slugOrUrl : `${BASE}/content/${slugOrUrl}`;
  const slug = url.split('/content/')[1].replace(/[?#].*$/, '');
  const html = await fetchText(url);
  const title = decode((html.match(/<title>([^<|]+)/) || [])[1] || slug).trim();
  const author = decode((html.match(/field-name-field-art-author[\s\S]*?>([^<]+)<\/a>/) || html.match(/class="username"[^>]*>([^<]+)</) || [])[1] || '');
  const licenses = [...html.matchAll(/field-name-field-art-licenses[\s\S]*?<\/div>\s*<\/div>/g)]
    .flatMap(m => [...m[0].matchAll(/>([^<]*(?:CC|GPL|OGA|Public Domain)[^<]*)</gi)].map(x => x[1].trim()));
  const lic = [...new Set(licenses)].join(', ') || 'unknown (check page)';
  const files = [...html.matchAll(/field-name-field-art-files[\s\S]*?(?=field-name-field-art-|$)/g)]
    .flatMap(m => [...m[0].matchAll(/href="(https?:\/\/opengameart\.org\/sites\/default\/files\/[^"]+)"/g)].map(x => x[1]));
  const urls = [...new Set(files)];
  if (!urls.length) throw new Error(`no attachments found on ${url}`);
  const meta = { source: id, pack: slug, license: lic, author, url, title };
  const paths = [];
  for (const f of urls) {
    onProgress(`downloading ${f}`);
    const buf = await download(f);
    const fname = decodeURIComponent(f.split('/').pop());
    if (/\.zip$/i.test(fname)) {
      const entries = unzipSync(new Uint8Array(buf));
      for (const [n, data] of Object.entries(entries)) {
        if (!/\.(png|svg|jpe?g|gif)$/i.test(n) || n.includes('__MACOSX')) continue;
        paths.push(await saveAsset(Buffer.from(data), { ...meta, name: n.split('/').filter(Boolean).slice(-2).join('__') }));
      }
    } else if (/\.(png|svg|jpe?g|gif)$/i.test(fname)) {
      paths.push(await saveAsset(buf, { ...meta, name: fname }));
    }
  }
  return { paths, count: paths.length, license: lic, author, title };
}

function decode(s) { return String(s).replace(/&amp;/g, '&').replace(/&quot;/g, '"').replace(/&#039;/g, "'").replace(/&lt;/g, '<').replace(/&gt;/g, '>'); }
