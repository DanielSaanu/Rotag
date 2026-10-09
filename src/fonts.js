// Curated free fonts (OFL / Apache) fetched from the google/fonts GitHub repo on first use.
import fs from 'node:fs/promises';
import path from 'node:path';
import { DIRS } from './paths.js';

const GF = 'https://raw.githubusercontent.com/google/fonts/main/';
export const FONTS = {
  'Press Start 2P': { url: GF + 'ofl/pressstart2p/PressStart2P-Regular.ttf', license: 'OFL', style: 'pixel, 8px grid' },
  'Silkscreen':     { url: GF + 'ofl/silkscreen/Silkscreen-Regular.ttf', license: 'OFL', style: 'pixel, 8px grid' },
  'Pixelify Sans':  { url: GF + 'ofl/pixelifysans/PixelifySans%5Bwght%5D.ttf', license: 'OFL', style: 'pixel, variable weight' },
  'VT323':          { url: GF + 'ofl/vt323/VT323-Regular.ttf', license: 'OFL', style: 'terminal pixel' },
  'Tiny5':          { url: GF + 'ofl/tiny5/Tiny5-Regular.ttf', license: 'OFL', style: 'pixel, 5px' },
  'Bangers':        { url: GF + 'ofl/bangers/Bangers-Regular.ttf', license: 'OFL', style: 'comic logo' },
  'Luckiest Guy':   { url: GF + 'apache/luckiestguy/LuckiestGuy-Regular.ttf', license: 'Apache-2.0', style: 'chunky cartoon logo' },
  'Fredoka':        { url: GF + 'ofl/fredoka/Fredoka%5Bwdth,wght%5D.ttf', license: 'OFL', style: 'rounded friendly' },
  'Inter':          { url: GF + 'ofl/inter/Inter%5Bopsz,wght%5D.ttf', license: 'OFL', style: 'clean UI' },
};

export async function ensureFontFile(family) {
  const spec = FONTS[family];
  if (!spec) throw new Error(`unknown font ${family}`);
  const dir = path.join(DIRS.cache, 'fonts');
  await fs.mkdir(dir, { recursive: true });
  const file = path.join(dir, family.replace(/\W+/g, '_') + '.ttf');
  try { await fs.access(file); return file; } catch {}
  const res = await fetch(spec.url);
  if (!res.ok) throw new Error(`download ${spec.url}: ${res.status}`);
  await fs.writeFile(file, Buffer.from(await res.arrayBuffer()));
  return file;
}
