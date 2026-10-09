// Node implementation of the renderer environment. Resolves repo-relative paths and URLs.
import { createCanvas, loadImage as napiLoad, GlobalFonts } from '@napi-rs/canvas';
import fs from 'node:fs/promises';
import path from 'node:path';
import { ROOT, safeJoin } from './paths.js';
import { ensureFontFile, FONTS } from './fonts.js';

const registered = new Set();

export function makeNodeEnv() {
  return {
    createCanvas,
    async loadImage(src) {
      if (/^https?:\/\//i.test(src)) {
        const res = await fetch(src);
        if (!res.ok) throw new Error(`fetch ${src}: ${res.status}`);
        return napiLoad(Buffer.from(await res.arrayBuffer()));
      }
      const buf = await fs.readFile(safeJoin(ROOT, src));
      return napiLoad(buf);
    },
    async readText(src) {
      if (/^https?:\/\//i.test(src)) return (await fetch(src)).text();
      return fs.readFile(safeJoin(ROOT, src), 'utf8');
    },
    async ensureFont(family) {
      if (registered.has(family)) return;
      const spec = FONTS[family];
      if (!spec) { registered.add(family); return; } // system font or unknown, let canvas fall back
      try {
        const file = await ensureFontFile(family);
        GlobalFonts.registerFromPath(file, family);
      } catch (e) {
        console.warn(`font "${family}" unavailable (${e.message}); falling back`);
      }
      registered.add(family);
    },
  };
}

export async function savePng(canvas, outPath) {
  await fs.mkdir(path.dirname(outPath), { recursive: true });
  await fs.writeFile(outPath, canvas.toBuffer('image/png'));
}
