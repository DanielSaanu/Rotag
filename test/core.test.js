import { test } from 'node:test';
import assert from 'node:assert/strict';
import { parsePixelText, pixelTextFromLayer, imageDataToPixelText, normalizeHex } from '../src/pixels.js';
import { normalizeScene, validateScene, newScene, newLayer, moveLayer } from '../src/scene.js';
import { renderScene } from '../src/render.js';
import { packSprites, toLua } from '../src/sheet.js';
import { makeNodeEnv } from '../src/node-env.js';
import { parseImageIdFromDecalXml } from '../src/roblox.js';

const env = makeNodeEnv();
const px = (c, x, y) => [...c.getContext('2d').getImageData(x, y, 1, 1).data];

test('pixel text parses and round-trips', () => {
  const p = parsePixelText('# name: dot\n# palette: . = transparent, k = #000, r = #ff0000\n.r.\nrkr\n.r.\n');
  assert.equal(p.name, 'dot'); assert.equal(p.width, 3); assert.equal(p.height, 3);
  assert.equal(p.palette.k, '#000000'); assert.equal(p.palette.r, '#ff0000');
  const text = pixelTextFromLayer({ rows: p.rows, palette: p.palette }, 'dot');
  const again = parsePixelText(text);
  assert.deepEqual(again.rows, p.rows);
});

test('scene normalize fills defaults and validate catches missing src', () => {
  const s = normalizeScene({ width: 8, height: 8, layers: [{ type: 'image' }] });
  assert.equal(s.layers[0].opacity, 1); assert.ok(s.layers[0].id);
  assert.match(validateScene(s).join(), /missing src/);
  assert.deepEqual(validateScene(newScene('x', 4, 4)), []);
});

test('moveLayer reorders', () => {
  const s = newScene('m', 4, 4); s.layers = ['a', 'b', 'c'].map(n => newLayer('shape', { id: n }));
  moveLayer(s, 'a', 2); assert.deepEqual(s.layers.map(l => l.id), ['b', 'c', 'a']);
});

test('render: pixels layer, outline pads by 1, recolor and flip', async () => {
  const s = newScene('t', 6, 6);
  s.layers.push(newLayer('pixels', { id: 'p', x: 2, y: 2, rows: ['rr', 'rr'], palette: { r: '#ff0000' } }));
  let r = await renderScene(s, env, { strict: true });
  assert.deepEqual(px(r.canvas, 2, 2), [255, 0, 0, 255]);
  assert.deepEqual(px(r.canvas, 1, 2), [0, 0, 0, 0]);
  s.layers[0].outline = { color: '#00ff00', size: 1 };
  r = await renderScene(s, env, { strict: true });
  assert.deepEqual(px(r.canvas, 1, 2), [0, 255, 0, 255], 'outline pixel left of sprite');
  assert.deepEqual(px(r.canvas, 2, 2), [255, 0, 0, 255], 'sprite stays put');
  assert.deepEqual(r.layers[0].bounds, { x: 1, y: 1, w: 4, h: 4 });
  s.layers[0].outline = null; s.layers[0].recolor = [{ from: '#ff0000', to: '#0000ff' }];
  r = await renderScene(s, env, { strict: true });
  assert.deepEqual(px(r.canvas, 3, 3), [0, 0, 255, 255]);
});

test('render: odd-sized sprites land on whole pixels in pixelated mode', async () => {
  const s = newScene('odd', 5, 5);
  s.layers.push(newLayer('pixels', { x: 1, y: 1, rows: ['rrr', 'rrr', 'rrr'], palette: { r: '#ff0000' } }));
  const r = await renderScene(s, env, { strict: true });
  assert.deepEqual(px(r.canvas, 1, 1), [255, 0, 0, 255]); assert.deepEqual(px(r.canvas, 3, 3), [255, 0, 0, 255]);
  assert.deepEqual(px(r.canvas, 0, 0), [0, 0, 0, 0]); assert.deepEqual(px(r.canvas, 4, 4), [0, 0, 0, 0]);
});

test('render: flipX mirrors, crop slices, nested scene and text produce pixels', async () => {
  const s = newScene('f', 4, 2);
  s.layers.push(newLayer('pixels', { rows: ['rb'], palette: { r: '#ff0000', b: '#0000ff' }, flipX: true }));
  let r = await renderScene(s, env, { strict: true });
  assert.deepEqual(px(r.canvas, 0, 0), [0, 0, 255, 255]); assert.deepEqual(px(r.canvas, 1, 0), [255, 0, 0, 255]);
  const t = newScene('txt', 64, 16); t.background = '#000000';
  t.layers.push(newLayer('text', { text: 'HI', font: 'monospace', size: 12, color: '#ffffff', x: 0, y: 0 }));
  r = await renderScene(t, env, { strict: true });
  const d = r.canvas.getContext('2d').getImageData(0, 0, 64, 16).data;
  let white = 0; for (let i = 0; i < d.length; i += 4) if (d[i] > 200) white++;
  assert.ok(white > 10, 'text rendered some white pixels');
  const shp = newScene('sh', 4, 4); shp.layers.push(newLayer('shape', { w: 4, h: 4, fill: '#00ff00' }));
  r = await renderScene(shp, env, { strict: true }); assert.deepEqual(px(r.canvas, 2, 2), [0, 255, 0, 255]);
});

test('imageDataToPixelText reads a canvas back', async () => {
  const s = newScene('a', 2, 1); s.layers.push(newLayer('pixels', { rows: ['r.'], palette: { r: '#ff0000' } }));
  const r = await renderScene(s, env, { strict: true });
  const p = imageDataToPixelText(r.canvas.getContext('2d').getImageData(0, 0, 2, 1));
  assert.equal(p.rows[0].length, 2); assert.equal(p.rows[0][1], '.'); assert.equal(p.palette[p.rows[0][0]], '#ff0000');
});

test('packSprites packs into POT sheets with padding and toLua lists them', () => {
  const items = [];
  for (let i = 0; i < 10; i++) { const c = env.createCanvas(16, 16); items.push({ name: 'spr' + i, canvas: c }); }
  const sheets = packSprites(items, env, { padding: 1, maxSize: 1024 });
  assert.equal(sheets.length, 1); assert.equal(sheets[0].width * sheets[0].height, 64 * 128, 'ten 16px sprites with 1px padding need a 64x128 or 128x64 sheet');
  assert.equal(Object.keys(sheets[0].sprites).length, 10);
  assert.deepEqual(sheets[0].sprites.spr0, { x: 1, y: 1, w: 16, h: 16 });
  const lua = toLua(sheets, { assetIds: { 0: '123' } });
  assert.match(lua, /rbxassetid:\/\/123/); assert.match(lua, /\["spr9"\] = \{ Sheet = 1/); assert.match(lua, /ResamplerMode.Pixelated/);
  // A decal id has to be looked up on the server at run time; an image id is marked Resolved so it never is.
  assert.doesNotMatch(lua, /Height = \d+, Resolved = true/);
  assert.match(toLua(sheets, { assetIds: { 0: '123' }, resolvedIds: { 0: true } }), /Id = "rbxassetid:\/\/123", Width = \d+, Height = \d+, Resolved = true/);
});

test('packSprites overflows into a second sheet', () => {
  const items = []; for (let i = 0; i < 5; i++) items.push({ name: 'big' + i, canvas: env.createCanvas(512, 512) });
  const sheets = packSprites(items, env, { padding: 0, maxSize: 1024 });
  assert.equal(sheets.length, 2);
  assert.throws(() => packSprites([{ name: 'huge', canvas: env.createCanvas(2000, 10) }], env), /exceeds/);
});

test('normalizeHex expands short hex', () => { assert.equal(normalizeHex('#abc'), '#aabbcc'); assert.equal(normalizeHex('FFF'), '#ffffff'); });

test('parseImageIdFromDecalXml finds the texture id inside a decal', () => {
  const xml = '<roblox version="4"><Item class="Decal"><Properties><string name="Name">warehouse sheet_0</string><Content name="Texture"><url>http://www.roblox.com/asset/?id=76691026583621</url></Content></Properties></Item></roblox>';
  assert.equal(parseImageIdFromDecalXml(xml), '76691026583621');
  assert.equal(parseImageIdFromDecalXml('<url>rbxassetid://42</url>'), '42');
  assert.equal(parseImageIdFromDecalXml('nothing here'), null);
});
