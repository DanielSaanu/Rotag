import fs from 'node:fs/promises';
import path from 'node:path';
import { DIRS, ROOT, rel } from './paths.js';
import { makeNodeEnv, savePng } from './node-env.js';
import { renderScene } from './render.js';
import { getSource, describeSources } from './sources/index.js';
import { listLibrary } from './library.js';
import { listScenes, loadScene, saveScene } from './store.js';
import { buildRoblox, setSheetId } from './build.js';
import { uploadFile, resolveImageId } from './roblox.js';
import { startServer } from './server.js';
import { FONTS } from './fonts.js';
import { newScene, newLayer } from './scene.js';
import { imageDataToPixelText, pixelTextFromLayer, parsePixelText } from './pixels.js';

const HELP = `The Warehouse: asset composer for pixel games (Roblox first).

  warehouse serve [--port N]                 open the UI (default http://localhost:4242)
  warehouse sources                          list asset sources
  warehouse search <source> <query>          search a source (kenney, opengameart, gameicons, lospec, fonts, local)
  warehouse fetch <source> <id>              download into library/ (kenney pack slug, OGA slug/url, icon path, palette slug)
  warehouse library [filter]                 list what is on disk
  warehouse scenes                           list scenes
  warehouse new <name> [w] [h]               create an empty scene
  warehouse render <scene|file> [-o out.png] [--scale N] [--layer id]
  warehouse ascii <image|scene> [--max N]    print an image as pixel-text so Claude can read it
  warehouse totxt <image> -o sprites/x.txt   convert a small PNG into an editable pixel-text sprite
  warehouse roblox build [--upload]          pack all scenes -> exports/roblox + roblox/src/shared/Sprites.lua
  warehouse roblox upload <png> [--name X] [--type Decal|Image]   upload one image, print the asset id
  warehouse roblox setid <sheet#> <assetId>  record a manually uploaded sheet id, rewrite Sprites.lua
  warehouse roblox resolve <decalId>         show what Roblox answers when looking up a decal's image id
  warehouse fonts                            list curated fonts
`;

export async function run(argv) {
  const { args, flags } = parseArgs(argv);
  const [cmd, ...rest] = args;
  switch (cmd) {
    case undefined: case 'help': case '-h': case '--help': console.log(HELP); return;
    case 'serve': return startServer({ port: Number(flags.port || process.env.WAREHOUSE_PORT || 4242), open: !flags['no-open'] });
    case 'sources': for (const s of describeSources()) console.log(`${s.id.padEnd(12)} ${s.license.padEnd(28)} ${s.about}`); return;
    case 'search': {
      const [src, ...q] = rest; if (!src) throw new Error('usage: search <source> <query>');
      const results = await getSource(src).search(q.join(' '));
      if (!results.length) console.log('(no results)');
      for (const r of results) console.log(`${(r.id || '').padEnd(48)} ${(r.license || '').padEnd(14)} ${r.title}${r.colors ? '  ' + r.colors.join(' ') : ''}`);
      return;
    }
    case 'fetch': {
      const [src, id] = rest; if (!src || !id) throw new Error('usage: fetch <source> <id>');
      const r = await getSource(src).fetch(id, { onProgress: m => console.log('  ' + m) });
      console.log(`fetched ${r.count} file(s)`); for (const p of r.paths.slice(0, 40)) console.log('  ' + p);
      if (r.paths.length > 40) console.log(`  ... and ${r.paths.length - 40} more`);
      return;
    }
    case 'library': for (const i of await listLibrary(rest.join(' '))) console.log(`${i.path.padEnd(70)} ${i.license}`); return;
    case 'scenes': for (const n of await listScenes()) console.log(n); return;
    case 'new': {
      const [name, w, h] = rest; if (!name) throw new Error('usage: new <name> [w] [h]');
      await saveScene(name, newScene(name, Number(w) || 16, Number(h) || 16));
      console.log(`created scenes/${name}.json`); return;
    }
    case 'render': {
      const [target] = rest; if (!target) throw new Error('usage: render <scene|file> [-o out.png]');
      const env = makeNodeEnv();
      const scene = await loadTarget(target, env);
      const r = await renderScene(scene, env, { scale: Number(flags.scale) || 1, onlyLayer: flags.layer, strict: true });
      const out = flags.o || flags.out || path.join(DIRS.exports, `${scene.name}${flags.scale ? '@' + flags.scale + 'x' : ''}.png`);
      await savePng(r.canvas, path.resolve(ROOT, out));
      console.log(`${rel(path.resolve(ROOT, out))}  ${r.canvas.width}x${r.canvas.height}`);
      for (const l of r.layers) if (l.error) console.log(`  layer ${l.id}: ${l.error}`);
      return;
    }
    case 'ascii': {
      const [target] = rest; if (!target) throw new Error('usage: ascii <image|scene>');
      const env = makeNodeEnv();
      const scene = await loadTarget(target, env);
      const r = await renderScene(scene, env, { strict: true });
      const max = Number(flags.max) || 64;
      const c = r.canvas; const ctx = c.getContext('2d');
      const w = Math.min(c.width, max), h = Math.min(c.height, max);
      const px = imageDataToPixelText(ctx.getImageData(0, 0, w, h));
      console.log(`# ${scene.name}  ${c.width}x${c.height}${(w < c.width || h < c.height) ? ` (showing ${w}x${h})` : ''}`);
      console.log(pixelTextFromLayer(px));
      return;
    }
    case 'totxt': {
      const [img] = rest; const out = flags.o || flags.out; if (!img || !out) throw new Error('usage: totxt <image> -o sprites/name.txt');
      const env = makeNodeEnv();
      const scene = await loadTarget(img, env);
      const r = await renderScene(scene, env, { strict: true });
      const px = imageDataToPixelText(r.canvas.getContext('2d').getImageData(0, 0, r.canvas.width, r.canvas.height));
      await fs.mkdir(path.dirname(path.resolve(ROOT, out)), { recursive: true });
      await fs.writeFile(path.resolve(ROOT, out), pixelTextFromLayer(px, path.basename(out, '.txt')));
      console.log(`wrote ${out} (${px.width}x${px.height}, ${Object.keys(px.palette).length - 1} colors)`); return;
    }
    case 'roblox': {
      const [sub, ...r2] = rest;
      if (sub === 'build') { await buildRoblox({ upload: !!flags.upload }); return; }
      if (sub === 'upload') { const [file] = r2; if (!file) throw new Error('usage: roblox upload <png> [--type Decal|Image]'); const { assetId } = await uploadFile(path.resolve(ROOT, file), { name: flags.name || path.basename(file, '.png'), assetType: flags.type || 'Decal' }); console.log(`asset id: ${assetId} (${flags.type || 'Decal'})\nuse in Lua: "rbxassetid://${assetId}"`); return; }
      if (sub === 'resolve') { const [id] = r2; if (!id) throw new Error('usage: roblox resolve <decalId>'); const r = await resolveImageId(id, { log: console.log }); console.log(r.resolved ? `image id: ${r.imageId}` : `unresolved; Studio command bar fallback:\n  local d = game:GetObjects("rbxassetid://${id}")[1] print(d.Texture)`); return; }
      if (sub === 'setid') { const [idx, assetId] = r2; if (idx == null || !assetId) throw new Error('usage: roblox setid <sheetIndex> <assetId>'); await setSheetId(Number(idx), String(assetId)); await buildRoblox({ upload: false }); return; }
      throw new Error('usage: roblox build [--upload] | roblox upload <png> | roblox setid <sheet#> <assetId>');
    }
    case 'fonts': for (const [n, s] of Object.entries(FONTS)) console.log(`${n.padEnd(16)} ${s.license.padEnd(11)} ${s.style}`); return;
    default: throw new Error(`unknown command "${cmd}". Run: warehouse help`);
  }
}

/** Accept a scene name, a scene json path, a pixel .txt, or an image file: all become a scene. */
async function loadTarget(target, env) {
  if (/\.(png|jpe?g|gif|webp|svg|txt)$/i.test(target)) {
    const src = rel(path.resolve(ROOT, target));
    const img = /\.txt$/i.test(target) ? null : await env.loadImage(src);
    let w = img?.width, h = img?.height;
    if (!img) { const px = parsePixelText(await fs.readFile(path.resolve(ROOT, target), 'utf8')); w = px.width; h = px.height; }
    const s = newScene(path.basename(target).replace(/\.[^.]+$/, ''), w, h);
    s.layers.push(newLayer('image', { src, name: 'image' }));
    return s;
  }
  return loadScene(target);
}

function parseArgs(argv) {
  const args = [], flags = {};
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a.startsWith('--')) { const k = a.slice(2); const nxt = argv[i + 1]; if (nxt != null && !nxt.startsWith('-')) { flags[k] = nxt; i++; } else flags[k] = true; }
    else if (a.startsWith('-') && a.length === 2) { flags[a.slice(1)] = argv[++i]; }
    else args.push(a);
  }
  return { args, flags };
}
