// `warehouse roblox build`: render every scene listed in roblox/sheet.json, pack, write PNG + JSON + Lua,
// optionally upload to Roblox and remember asset ids in roblox/assets.lock.json (keyed by sheet hash so
// unchanged sheets are never re-uploaded).
import fs from 'node:fs/promises';
import path from 'node:path';
import { DIRS, ROOT, rel } from './paths.js';
import { makeNodeEnv, savePng } from './node-env.js';
import { renderScene } from './render.js';
import { packSprites, toLua, toJson } from './sheet.js';
import { sha1 } from './library.js';
import { uploadImage, resolveImageId } from './roblox.js';
import { listScenes, loadScene } from './store.js';

const MANIFEST = path.join(DIRS.roblox, 'sheet.json');
const LOCK = path.join(DIRS.roblox, 'assets.lock.json');

export async function readManifest() {
  try { return JSON.parse(await fs.readFile(MANIFEST, 'utf8')); }
  catch { return { include: ['*'], exclude: [], padding: 1, maxSize: 1024, luaOut: 'roblox/src/shared/Sprites.lua', pngOut: 'exports/roblox' }; }
}

function globToRe(g) { return new RegExp('^' + g.replace(/[.+^${}()|[\]\\]/g, '\\$&').replace(/\*/g, '.*').replace(/\?/g, '.') + '$'); }

export async function collectSceneNames(manifest) {
  const all = await listScenes();
  const inc = (manifest.include || ['*']).map(globToRe), exc = (manifest.exclude || []).map(globToRe);
  return all.filter(n => inc.some(r => r.test(n)) && !exc.some(r => r.test(n)));
}

export async function buildRoblox({ upload = false, log = console.log } = {}) {
  const manifest = await readManifest();
  const env = makeNodeEnv();
  const names = await collectSceneNames(manifest);
  if (!names.length) throw new Error('no scenes matched roblox/sheet.json include patterns');
  const items = [];
  for (const n of names) {
    const scene = await loadScene(n);
    if (scene.export === false) continue;
    const r = await renderScene(scene, env, { strict: true });
    // A scene can also declare frames: { "frames": {"walk_0": {"x":0,"y":0,"w":16,"h":16}, ...} } to slice itself.
    if (scene.frames && Object.keys(scene.frames).length) {
      for (const [fname, f] of Object.entries(scene.frames)) {
        const c = env.createCanvas(f.w, f.h); const ctx = c.getContext('2d'); ctx.imageSmoothingEnabled = false;
        ctx.drawImage(r.canvas, f.x, f.y, f.w, f.h, 0, 0, f.w, f.h);
        items.push({ name: fname, canvas: c });
      }
    } else items.push({ name: n, canvas: r.canvas });
  }
  const sheets = packSprites(items, env, { padding: manifest.padding ?? 1, maxSize: manifest.maxSize ?? 1024 });
  const outDir = path.join(ROOT, manifest.pngOut || 'exports/roblox');
  await fs.mkdir(outDir, { recursive: true });
  let lock = {};
  try { lock = JSON.parse(await fs.readFile(LOCK, 'utf8')); } catch {}
  const assetIds = {};
  // Sheets whose id is already the IMAGE id (uploaded and looked up, or set by hand with `roblox setid`).
  // The generated Lua marks those Resolved, so the game server never does the runtime decal lookup for them.
  const resolvedIds = {};
  for (let i = 0; i < sheets.length; i++) {
    const png = sheets[i].canvas.toBuffer('image/png');
    const file = path.join(outDir, `sheet_${i}.png`);
    await fs.writeFile(file, png);
    const hash = sha1(png);
    log(`sheet_${i}.png  ${sheets[i].width}x${sheets[i].height}  ${Object.keys(sheets[i].sprites).length} sprites  -> ${rel(file)}`);
    const prev = lock[`sheet_${i}`];
    if (prev && prev.hash === hash && prev.assetId) {
      if (prev.unresolved && prev.decalId) {
        // Uploaded earlier but the image id could not be looked up then; try again.
        const { imageId, resolved } = await resolveImageId(prev.decalId);
        if (resolved) { prev.assetId = imageId; delete prev.unresolved; log(`  resolved image id ${imageId} for decal ${prev.decalId}`); }
        else log(`  decal ${prev.decalId} (the server resolves the image id at runtime; see docs/ROBLOX_SETUP.md if tiles stay blank)`);
      }
      assetIds[i] = prev.assetId; resolvedIds[i] = !prev.unresolved; log(`  unchanged, asset ${prev.assetId}${prev.unresolved ? ' (decal; resolved at runtime)' : ' (image id, hard-coded)'}`); continue;
    }
    if (upload) {
      log(`  uploading to Roblox...`);
      const { assetId: decalId } = await uploadImage(png, { name: `warehouse sheet_${i}`, description: `Sprite sheet ${i} built ${new Date().toISOString()}` });
      const { imageId, resolved } = await resolveImageId(decalId);
      assetIds[i] = imageId;
      resolvedIds[i] = resolved;
      lock[`sheet_${i}`] = { hash, decalId, assetId: imageId, uploadedAt: new Date().toISOString(), ...(resolved ? {} : { unresolved: true }) };
      if (resolved) log(`  uploaded decal ${decalId}, using image id ${imageId}`);
      else log(`  uploaded decal ${decalId}. Roblox will not reveal its image id from outside (auth required); the game server resolves it at runtime. If tiles stay blank in Studio, command bar: local d = game:GetObjects("rbxassetid://${decalId}")[1] print(d.Texture)  then: warehouse roblox setid ${i} <that number>`);
    } else if (prev?.assetId) {
      assetIds[i] = prev.assetId;
      resolvedIds[i] = !prev.unresolved;
      log(`  CHANGED since last upload (still using old asset ${prev.assetId}); run with --upload`);
    } else {
      log(`  not uploaded yet (id 0). Run with --upload or paste an id into roblox/assets.lock.json`);
    }
  }
  await fs.writeFile(LOCK, JSON.stringify(lock, null, 2) + '\n');
  const luaPath = path.join(ROOT, manifest.luaOut || 'roblox/src/shared/Sprites.lua');
  await fs.mkdir(path.dirname(luaPath), { recursive: true });
  await fs.writeFile(luaPath, toLua(sheets, { assetIds, resolvedIds }));
  await fs.writeFile(path.join(outDir, 'sheets.json'), JSON.stringify(toJson(sheets, assetIds), null, 2) + '\n');
  log(`wrote ${rel(luaPath)} (${items.length} sprites, ${sheets.length} sheet${sheets.length === 1 ? '' : 's'})`);
  return { sheets, assetIds, luaPath, items: items.length };
}

/** Record an asset id for a sheet that was uploaded by hand (Creator Hub). The hash is taken from the current PNG. */
export async function setSheetId(index, assetId) {
  const manifest = await readManifest();
  const file = path.join(ROOT, manifest.pngOut || 'exports/roblox', `sheet_${index}.png`);
  let hash = null;
  try { hash = sha1(await fs.readFile(file)); } catch { throw new Error(`${rel(file)} not found; run "warehouse roblox build" first`); }
  let lock = {};
  try { lock = JSON.parse(await fs.readFile(LOCK, 'utf8')); } catch {}
  // Keep the decal this image came out of when it is the same sheet, so the upload stays traceable.
  const prev = lock[`sheet_${index}`];
  const decalId = prev && prev.hash === hash ? prev.decalId : undefined;
  lock[`sheet_${index}`] = { hash, ...(decalId ? { decalId } : {}), assetId: String(assetId), uploadedAt: new Date().toISOString(), manual: true };
  await fs.writeFile(LOCK, JSON.stringify(lock, null, 2) + '\n');
}
