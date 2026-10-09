// The Warehouse UI. No build step. Shares src/render.js with the CLI so what you see is what Claude renders.
import { renderScene, clearRenderCache } from '/src/render.js';
import { newScene, newLayer, normalizeScene, findLayer, moveLayer, layerScale } from '/src/scene.js';
import { pixelTextFromLayer, normalizeHex, hexToRgb } from '/src/pixels.js';

const $ = s => document.querySelector(s);
const $$ = s => [...document.querySelectorAll(s)];
const api = {
  get: async (p) => { const r = await fetch('/api' + p); const j = await r.json(); if (!r.ok) throw new Error(j.error || r.statusText); return j; },
  send: async (m, p, body) => { const r = await fetch('/api' + p, { method: m, headers: { 'content-type': 'application/json' }, body: JSON.stringify(body || {}) }); const j = await r.json(); if (!r.ok) throw new Error(j.error || r.statusText); return j; },
};

// ---------- browser render env ----------
const fontsLoaded = new Set();
const env = {
  createCanvas(w, h) { const c = document.createElement('canvas'); c.width = Math.max(1, Math.round(w)); c.height = Math.max(1, Math.round(h)); return c; },
  loadImage(src) {
    return new Promise((res, rej) => {
      const img = new Image();
      img.onload = () => res(img);
      img.onerror = () => rej(new Error('cannot load ' + src));
      img.src = /^(https?:|data:)/.test(src) ? src : '/files/' + src;
    });
  },
  async readText(src) { const r = await fetch(/^https?:/.test(src) ? src : '/files/' + src); if (!r.ok) throw new Error('cannot read ' + src); return r.text(); },
  async ensureFont(family) {
    if (fontsLoaded.has(family) || !state.fonts.includes(family)) return;
    try { const f = new FontFace(family, `url(/fonts/${encodeURIComponent(family)}.ttf)`); await f.load(); document.fonts.add(f); } catch (e) { console.warn('font', family, e); }
    fontsLoaded.add(family);
  },
};

// ---------- state ----------
const state = {
  scenes: [], fonts: [], sources: [], palettes: [],
  name: '', scene: newScene('untitled', 16, 16), mtime: 0, dirty: false,
  sel: null, zoom: 8, pan: { x: 40, y: 40 }, last: null, showGrid: true,
  ideasName: 'INBOX', ideasMtime: 0, ideasDirty: false,
  pxColorChar: '#',
};
let renderQueued = false;

function status(msg, cls = '') { const el = $('#status'); el.textContent = msg; el.className = 'status ' + cls; if (cls === 'ok') setTimeout(() => { if (el.textContent === msg) el.textContent = ''; }, 3000); }
function markDirty() { state.dirty = true; $('#btnSave').textContent = 'save *'; }
function clearDirty() { state.dirty = false; $('#btnSave').textContent = 'save'; }

// ---------- boot ----------
async function boot() {
  const st = await api.get('/state');
  Object.assign(state, { scenes: st.scenes, fonts: st.fonts, sources: st.sources, palettes: st.palettes });
  fillSceneSelect();
  $('#srcSelect').innerHTML = st.sources.map(s => `<option value="${s.id}">${s.name}</option>`).join('');
  $('#srcSelect').value = 'kenney'; updateSrcAbout();
  $('#ideasSelect').innerHTML = ['INBOX', ...st.ideas.filter(n => n !== 'INBOX')].map(n => `<option>${n}</option>`).join('');
  await loadIdeas('INBOX');
  const first = localStorage.getItem('wh.scene') || st.scenes[0];
  if (first && st.scenes.includes(first)) await openScene(first); else { state.name = ''; syncSceneInputs(); requestRender(); }
  renderPalettes();
  refreshLibrary();
  setInterval(pollDisk, 2500);
  fitView();
}

function fillSceneSelect() {
  $('#sceneSelect').innerHTML = state.scenes.map(n => `<option>${n}</option>`).join('') + '<option value="">(unsaved)</option>';
  $('#sceneSelect').value = state.name;
}

async function openScene(name) {
  const { scene, mtime } = await api.get('/scenes/' + encodeURIComponent(name));
  state.name = name; state.scene = normalizeScene(scene); state.mtime = mtime; state.sel = null; clearDirty();
  localStorage.setItem('wh.scene', name);
  fillSceneSelect(); syncSceneInputs(); renderLayers(); renderProps(); requestRender(); fitView();
}

async function saveScene() {
  if (!state.name) { const n = prompt('scene name'); if (!n) return; state.name = n.replace(/[^\w.-]+/g, '_'); }
  state.scene.name = state.name;
  try {
    const { mtime } = await api.send('PUT', '/scenes/' + encodeURIComponent(state.name), { scene: state.scene, force: true });
    state.mtime = mtime; clearDirty();
    if (!state.scenes.includes(state.name)) { state.scenes.push(state.name); state.scenes.sort(); }
    fillSceneSelect(); status('saved scenes/' + state.name + '.json', 'ok');
  } catch (e) { status(e.message, 'err'); }
}

async function pollDisk() {
  if (state.name) {
    try {
      const { mtime, scene } = await api.get('/scenes/' + encodeURIComponent(state.name));
      if (mtime > state.mtime) {
        if (!state.dirty) { state.scene = normalizeScene(scene); state.mtime = mtime; clearRenderCache(); syncSceneInputs(); renderLayers(); renderProps(); requestRender(); status('reloaded from disk (someone edited the file)', 'ok'); }
        else status('scene changed on disk while you have unsaved edits. Save = overwrite, reopen = discard yours.', 'err');
      }
    } catch {}
  }
  try {
    const { mtime, text } = await api.get('/ideas/' + encodeURIComponent(state.ideasName));
    if (mtime > state.ideasMtime && !state.ideasDirty && document.activeElement !== $('#ideas')) { $('#ideas').value = text; state.ideasMtime = mtime; }
  } catch {}
  const st = await api.get('/state').catch(() => null);
  if (st && st.scenes.join() !== state.scenes.join()) { state.scenes = st.scenes; fillSceneSelect(); }
}

// ---------- scene inputs ----------
function syncSceneInputs() {
  const s = state.scene;
  $('#sceneW').value = s.width; $('#sceneH').value = s.height; $('#sceneBg').value = s.background || 'transparent';
  $('#scenePix').checked = !!s.pixelated; $('#sceneExport').checked = s.export !== false; $('#sceneNotes').value = s.notes || '';
}
for (const [id, key, conv] of [['#sceneW', 'width', Number], ['#sceneH', 'height', Number], ['#sceneBg', 'background', v => v || 'transparent'], ['#scenePix', 'pixelated', null], ['#sceneNotes', 'notes', String]]) {
  $(id).addEventListener('input', e => { state.scene[key] = conv ? conv(e.target.value) : e.target.checked; markDirty(); requestRender(); });
}
$('#sceneExport').addEventListener('change', e => { if (e.target.checked) delete state.scene.export; else state.scene.export = false; markDirty(); });
$('#sceneSelect').addEventListener('change', async e => { if (state.dirty && !confirm('discard unsaved changes?')) { e.target.value = state.name; return; } if (e.target.value) await openScene(e.target.value); });
$('#btnNew').addEventListener('click', () => {
  const n = prompt('new scene name (e.g. player_walk_0)'); if (!n) return;
  const w = Number(prompt('width', '16')) || 16, h = Number(prompt('height', String(w))) || w;
  state.name = n.replace(/[^\w.-]+/g, '_'); state.scene = newScene(state.name, w, h); state.sel = null; markDirty();
  fillSceneSelect(); $('#sceneSelect').value = ''; syncSceneInputs(); renderLayers(); renderProps(); requestRender(); fitView(); saveScene();
});
$('#btnSave').addEventListener('click', saveScene);
$('#btnDelete').addEventListener('click', async () => {
  if (!state.name || !confirm(`delete scenes/${state.name}.json?`)) return;
  await api.send('DELETE', '/scenes/' + encodeURIComponent(state.name));
  state.scenes = state.scenes.filter(n => n !== state.name); state.name = ''; state.scene = newScene(); state.sel = null; clearDirty();
  fillSceneSelect(); syncSceneInputs(); renderLayers(); renderProps(); requestRender();
});
$('#btnPng').addEventListener('click', async () => {
  const scale = Number(prompt('export scale (1 = native size for Roblox, 8 = big preview)', '1')) || 1;
  const r = await renderScene(state.scene, env, { scale });
  const a = document.createElement('a'); a.download = `${state.name || 'scene'}${scale > 1 ? '@' + scale + 'x' : ''}.png`; a.href = r.canvas.toDataURL('image/png'); a.click();
});
$('#btnBuild').addEventListener('click', () => robloxBuild(false));
$('#btnUpload').addEventListener('click', () => confirm('Build every exportable scene into a sheet and upload to Roblox using the key in .env?') && robloxBuild(true));
async function robloxBuild(upload) {
  if (state.dirty) await saveScene();
  status(upload ? 'building + uploading…' : 'building…');
  try { const r = await api.send('POST', '/roblox/build', { upload }); status(`built ${r.sprites} sprites into ${r.sheets} sheet(s). Sprites.lua updated.`, 'ok'); alert(r.log.join('\n')); }
  catch (e) { status(e.message, 'err'); alert('build failed:\n' + e.message); }
}

// ---------- rendering ----------
function requestRender() { if (renderQueued) return; renderQueued = true; requestAnimationFrame(doRender); }
async function doRender() {
  renderQueued = false;
  try { state.last = await renderScene(state.scene, env); } catch (e) { status('render: ' + e.message, 'err'); return; }
  const errs = state.last.layers.filter(l => l.error);
  if (errs.length) status(errs.map(l => `${findLayer(state.scene, l.id)?.name}: ${l.error}`).join(' | '), 'err');
  drawView();
}
function drawView() {
  const vp = $('#viewport'), view = $('#view');
  const W = vp.clientWidth, H = vp.clientHeight;
  if (view.width !== W || view.height !== H) { view.width = W; view.height = H; }
  const ctx = view.getContext('2d');
  ctx.clearRect(0, 0, W, H);
  const z = state.zoom, { x: px, y: py } = state.pan, s = state.scene;
  // checkerboard behind the scene
  ctx.save(); ctx.beginPath(); ctx.rect(px, py, s.width * z, s.height * z); ctx.clip();
  const cs = Math.max(4, z);
  for (let y = 0; y < s.height * z; y += cs) for (let x = 0; x < s.width * z; x += cs) { ctx.fillStyle = ((x / cs + y / cs) % 2) ? '#262636' : '#1e1e2c'; ctx.fillRect(px + x, py + y, cs, cs); }
  ctx.restore();
  if (state.last) { ctx.imageSmoothingEnabled = false; ctx.drawImage(state.last.canvas, px, py, s.width * z, s.height * z); }
  if (state.showGrid && z >= 4) {
    ctx.strokeStyle = 'rgba(255,255,255,0.08)'; ctx.lineWidth = 1; ctx.beginPath();
    for (let x = 0; x <= s.width; x++) { ctx.moveTo(px + x * z + 0.5, py); ctx.lineTo(px + x * z + 0.5, py + s.height * z); }
    for (let y = 0; y <= s.height; y++) { ctx.moveTo(px, py + y * z + 0.5); ctx.lineTo(px + s.width * z, py + y * z + 0.5); }
    ctx.stroke();
    if (s.width % 16 === 0 && s.height % 16 === 0 && s.width > 16) {
      ctx.strokeStyle = 'rgba(123,211,90,0.25)'; ctx.beginPath();
      for (let x = 0; x <= s.width; x += 16) { ctx.moveTo(px + x * z + 0.5, py); ctx.lineTo(px + x * z + 0.5, py + s.height * z); }
      for (let y = 0; y <= s.height; y += 16) { ctx.moveTo(px, py + y * z + 0.5); ctx.lineTo(px + s.width * z, py + y * z + 0.5); }
      ctx.stroke();
    }
  }
  ctx.strokeStyle = '#4a4a68'; ctx.strokeRect(px - 0.5, py - 0.5, s.width * z + 1, s.height * z + 1);
  const b = boundsOf(state.sel);
  if (b) { ctx.strokeStyle = '#7bd35a'; ctx.lineWidth = 1; ctx.setLineDash([4, 3]); ctx.strokeRect(px + b.x * z - 0.5, py + b.y * z - 0.5, b.w * z + 1, b.h * z + 1); ctx.setLineDash([]);
    ctx.fillStyle = '#7bd35a'; ctx.fillRect(px + (b.x + b.w) * z - 4, py + (b.y + b.h) * z - 4, 8, 8); }
  $('#zoomLabel').textContent = z + 'x';
}
function boundsOf(id) { if (!id || !state.last) return null; const info = state.last.layers.find(l => l.id === id); return info && info.bounds; }
function fitView() {
  const vp = $('#viewport'); const s = state.scene;
  const z = Math.max(1, Math.floor(Math.min((vp.clientWidth - 40) / s.width, (vp.clientHeight - 40) / s.height)));
  state.zoom = Math.min(32, z); state.pan = { x: Math.round((vp.clientWidth - s.width * state.zoom) / 2), y: Math.round((vp.clientHeight - s.height * state.zoom) / 2) };
  drawView();
}
window.addEventListener('resize', drawView);
$('#showGrid').addEventListener('change', e => { state.showGrid = e.target.checked; drawView(); });

// ---------- viewport interaction ----------
const vp = $('#viewport');
let drag = null;
function toScene(e) { const r = vp.getBoundingClientRect(); return { x: (e.clientX - r.left - state.pan.x) / state.zoom, y: (e.clientY - r.top - state.pan.y) / state.zoom }; }
function hitTest(pt) {
  if (!state.last) return null;
  for (let i = state.scene.layers.length - 1; i >= 0; i--) {
    const l = state.scene.layers[i]; if (l.visible === false || l.locked) continue;
    const b = state.last.layers.find(x => x.id === l.id)?.bounds; if (!b) continue;
    if (pt.x >= b.x && pt.x <= b.x + b.w && pt.y >= b.y && pt.y <= b.y + b.h) return l;
  }
  return null;
}
vp.addEventListener('mousedown', e => {
  if (e.button === 1 || e.altKey || e.code === 'Space' || spaceDown) { drag = { kind: 'pan', sx: e.clientX, sy: e.clientY, px: state.pan.x, py: state.pan.y }; e.preventDefault(); return; }
  if (e.button !== 0) return;
  const pt = toScene(e);
  const b = boundsOf(state.sel);
  if (b && Math.abs(pt.x - (b.x + b.w)) * state.zoom < 6 && Math.abs(pt.y - (b.y + b.h)) * state.zoom < 6) {
    const l = findLayer(state.scene, state.sel); const { sx, sy } = layerScale(l);
    drag = { kind: 'scale', l, sx, sy, w: b.w / sx, h: b.h / sy, ox: b.x, oy: b.y, pt }; return;
  }
  const l = hitTest(pt);
  select(l ? l.id : null);
  if (l) drag = { kind: 'move', l, ox: l.x, oy: l.y, pt };
});
window.addEventListener('mousemove', e => {
  if (!drag) return;
  if (drag.kind === 'pan') { state.pan = { x: drag.px + e.clientX - drag.sx, y: drag.py + e.clientY - drag.sy }; drawView(); return; }
  const pt = toScene(e); const snap = state.scene.pixelated ? Math.round : v => Math.round(v * 10) / 10;
  if (drag.kind === 'move') { drag.l.x = snap(drag.ox + pt.x - drag.pt.x); drag.l.y = snap(drag.oy + pt.y - drag.pt.y); }
  else if (drag.kind === 'scale') {
    const nw = Math.max(1, pt.x - drag.ox), nh = Math.max(1, pt.y - drag.oy);
    let sx = nw / drag.w, sy = nh / drag.h;
    if (!e.shiftKey) { sx = sy = Math.max(sx, sy); }
    if (state.scene.pixelated) { sx = Math.max(1, Math.round(sx)); sy = Math.max(1, Math.round(sy)); }
    if (sx === sy) { drag.l.scale = sx; delete drag.l.scaleX; delete drag.l.scaleY; } else { drag.l.scaleX = sx; drag.l.scaleY = sy; }
  }
  markDirty(); requestRender(); renderProps(false);
});
window.addEventListener('mouseup', () => { drag = null; });
vp.addEventListener('wheel', e => {
  e.preventDefault();
  const r = vp.getBoundingClientRect(); const mx = e.clientX - r.left, my = e.clientY - r.top;
  const old = state.zoom; const nz = Math.max(1, Math.min(48, e.deltaY < 0 ? old + (old < 8 ? 1 : 2) : old - (old <= 8 ? 1 : 2)));
  if (nz === old) return;
  state.pan.x = mx - (mx - state.pan.x) * nz / old; state.pan.y = my - (my - state.pan.y) * nz / old; state.zoom = nz; drawView();
}, { passive: false });
let spaceDown = false;
window.addEventListener('keydown', e => {
  const t = e.target.tagName; if (t === 'INPUT' || t === 'TEXTAREA' || t === 'SELECT') { if ((e.ctrlKey || e.metaKey) && e.key === 's') { e.preventDefault(); saveScene(); } return; }
  if (e.code === 'Space') { spaceDown = true; e.preventDefault(); return; }
  if ((e.ctrlKey || e.metaKey) && e.key === 's') { e.preventDefault(); saveScene(); return; }
  const l = findLayer(state.scene, state.sel);
  if (!l) return;
  const step = e.shiftKey ? 8 : 1;
  const nudge = { ArrowLeft: [-step, 0], ArrowRight: [step, 0], ArrowUp: [0, -step], ArrowDown: [0, step] }[e.key];
  if (nudge) { l.x += nudge[0]; l.y += nudge[1]; }
  else if (e.key === 'Delete' || e.key === 'Backspace') { state.scene.layers = state.scene.layers.filter(x => x !== l); state.sel = null; }
  else if ((e.ctrlKey || e.metaKey) && e.key === 'd') { const c = structuredClone(l); c.id = newLayer('image').id; c.name += ' copy'; c.x += 1; c.y += 1; state.scene.layers.splice(state.scene.layers.indexOf(l) + 1, 0, c); state.sel = c.id; }
  else if (e.key === ']') moveLayer(state.scene, l.id, 1);
  else if (e.key === '[') moveLayer(state.scene, l.id, -1);
  else if (e.key === 'f' || e.key === 'F') l.flipX = !l.flipX;
  else if (e.key === 'v' || e.key === 'V') l.visible = l.visible === false ? true : false;
  else return;
  e.preventDefault(); markDirty(); requestRender(); renderLayers(); renderProps();
});
window.addEventListener('keyup', e => { if (e.code === 'Space') spaceDown = false; });

function select(id) { state.sel = id; renderLayers(); renderProps(); drawView(); if (id && findLayer(state.scene, id)?.type === 'pixels') { showTab('draw'); drawPixelEditor(); } }

// ---------- layers list ----------
function renderLayers() {
  const ul = $('#layers'); ul.innerHTML = '';
  [...state.scene.layers].reverse().forEach(l => {
    const li = document.createElement('li'); li.className = l.id === state.sel ? 'sel' : '';
    li.innerHTML = `<span class="eye ${l.visible === false ? '' : 'on'}" title="toggle visibility">👁</span><span class="nm">${esc(l.name)}</span><span class="ty">${l.type}${l.locked ? ' 🔒' : ''}</span><button class="mini" title="up">▲</button><button class="mini" title="down">▼</button>`;
    li.addEventListener('click', e => { if (e.target.tagName === 'BUTTON' || e.target.classList.contains('eye')) return; select(l.id); });
    li.querySelector('.eye').addEventListener('click', () => { l.visible = l.visible === false; markDirty(); renderLayers(); requestRender(); });
    const [up, down] = li.querySelectorAll('button');
    up.addEventListener('click', () => { moveLayer(state.scene, l.id, 1); markDirty(); renderLayers(); requestRender(); });
    down.addEventListener('click', () => { moveLayer(state.scene, l.id, -1); markDirty(); renderLayers(); requestRender(); });
    ul.appendChild(li);
  });
}
function addLayer(type, extra) {
  const l = newLayer(type, extra); l.name = extra?.name || (extra?.src ? extra.src.split('/').pop().replace(/\.[^.]+$/, '') : type);
  state.scene.layers.push(l); markDirty(); select(l.id); requestRender(); return l;
}
$('#btnAddText').addEventListener('click', () => addLayer('text', { text: 'TEXT', font: state.fonts[0] || 'sans-serif', size: 8, color: '#ffffff' }));
$('#btnAddShape').addEventListener('click', () => addLayer('shape', { w: Math.min(16, state.scene.width), h: Math.min(16, state.scene.height), fill: '#7bd35a' }));
$('#btnAddPixels').addEventListener('click', () => {
  const w = Number($('#pxW').value) || 16, h = Number($('#pxH').value) || 16;
  addLayer('pixels', { name: 'drawing', rows: Array.from({ length: h }, () => '.'.repeat(w)), palette: { '.': null, '#': '#1b1b2f', 'w': '#f4f4f8' } });
});

// ---------- properties ----------
function renderProps(rebuild = true) {
  const box = $('#props'); const l = findLayer(state.scene, state.sel);
  if (!l) { box.innerHTML = '<div class="muted small">nothing selected. click a layer on the canvas or in the list.</div>'; return; }
  if (!rebuild && box.dataset.id === l.id) { for (const inp of box.querySelectorAll('[data-k]')) syncInput(inp, l); return; }
  box.dataset.id = l.id;
  const f = [];
  const field = (label, k, type = 'number', opts = '') => f.push(`<label>${label}</label>${type === 'select' ? `<select data-k="${k}">${opts}</select>` : type === 'checkbox' ? `<input type="checkbox" data-k="${k}">` : type === 'textarea' ? `<textarea data-k="${k}" rows="2"></textarea>` : `<input type="${type}" data-k="${k}" ${opts}>`}`);
  const pair = (label, k1, k2) => f.push(`<label>${label}</label><div class="pair"><input type="number" data-k="${k1}"><input type="number" data-k="${k2}"></div>`);
  field('name', 'name', 'text');
  pair('x / y', 'x', 'y');
  field('scale', 'scale', 'number', 'step="0.5" min="0.05"');
  field('rotation', 'rotation', 'number', 'step="15"');
  field('opacity', 'opacity', 'number', 'step="0.1" min="0" max="1"');
  f.push(`<label>flip</label><div class="pair"><label class="inline"><input type="checkbox" data-k="flipX"> X</label><label class="inline"><input type="checkbox" data-k="flipY"> Y</label><label class="inline"><input type="checkbox" data-k="locked"> lock</label></div>`);
  if (l.type === 'image' || l.type === 'scene') {
    field('src', 'src', 'text');
    if (l.type === 'image') { f.push(`<label>crop</label><div class="pair"><input type="number" data-k="crop.x" placeholder="x"><input type="number" data-k="crop.y" placeholder="y"><input type="number" data-k="crop.w" placeholder="w"><input type="number" data-k="crop.h" placeholder="h"></div>`); f.push(`<div class="full small muted">crop slices a sprite sheet: x, y, w, h in source pixels. leave 0 for whole image.</div>`); }
  }
  if (l.type === 'text') {
    field('text', 'text', 'textarea');
    field('font', 'font', 'select', [...state.fonts, 'sans-serif', 'monospace'].map(n => `<option>${n}</option>`).join(''));
    field('size', 'size', 'number', 'min="1"'); field('color', 'color', 'color');
    field('letter spacing', 'letterSpacing', 'number'); field('align', 'align', 'select', '<option>left</option><option>center</option><option>right</option>');
    f.push(`<label>stroke</label><div class="pair"><input type="color" data-k="stroke.color"><input type="number" data-k="stroke.width" placeholder="width" min="0"></div>`);
  }
  if (l.type === 'shape') {
    field('shape', 'shape', 'select', '<option>rect</option><option>ellipse</option>'); pair('w / h', 'w', 'h');
    field('fill', 'fill', 'color'); field('radius', 'radius', 'number', 'min="0"');
    f.push(`<label>stroke</label><div class="pair"><input type="color" data-k="stroke.color"><input type="number" data-k="stroke.width" placeholder="width" min="0"></div>`);
  }
  if (l.type === 'pixels') f.push(`<div class="full small muted">edit pixels in the <b>draw</b> tab on the left.</div>`);
  f.push('<h4>effects</h4>');
  f.push(`<label>outline</label><div class="pair"><input type="color" data-k="outline.color"><input type="number" data-k="outline.size" placeholder="size" min="0"></div>`);
  f.push(`<label>shadow</label><div class="pair"><input type="color" data-k="shadow.color"><input type="number" data-k="shadow.x" placeholder="x"><input type="number" data-k="shadow.y" placeholder="y"></div>`);
  f.push(`<label>tint</label><div class="pair"><input type="color" data-k="tint.color"><select data-k="tint.mode"><option>multiply</option><option>replace</option></select><input type="number" data-k="tint.amount" step="0.1" min="0" max="1" placeholder="amt"></div>`);
  field('hue shift', 'hue', 'number', 'step="15" min="-180" max="180"');
  field('saturation', 'saturation', 'number', 'step="0.1" min="0" max="3"');
  field('brightness', 'brightness', 'number', 'step="0.1" min="0" max="3"');
  field('blend', 'blend', 'select', ['source-over', 'multiply', 'screen', 'overlay', 'lighter', 'difference'].map(n => `<option>${n}</option>`).join(''));
  f.push(`<label>recolor</label><div id="recolor"></div>`);
  f.push(`<div class="full"><button id="btnRecolorAdd" class="mini">+ pair</button> <button id="btnPickPalette" class="mini" title="snap every color of this layer to the nearest color of a LoSpec palette">snap to palette…</button> <button id="btnClearFx" class="mini">clear effects</button> <button id="btnDelLayer" class="mini danger">delete layer</button></div>`);
  box.innerHTML = f.join('');
  for (const inp of box.querySelectorAll('[data-k]')) {
    syncInput(inp, l);
    inp.addEventListener(inp.type === 'checkbox' || inp.tagName === 'SELECT' ? 'change' : 'input', () => { setPath(l, inp.dataset.k, inp.type === 'checkbox' ? inp.checked : inp.type === 'number' ? (inp.value === '' ? null : Number(inp.value)) : inp.value); if (inp.dataset.k === 'scale') { delete l.scaleX; delete l.scaleY; } markDirty(); requestRender(); if (inp.dataset.k === 'name') renderLayers(); });
  }
  renderRecolor(l);
  $('#btnRecolorAdd').addEventListener('click', () => { (l.recolor ||= []).push({ from: '#000000', to: '#ffffff' }); renderRecolor(l); markDirty(); });
  $('#btnClearFx').addEventListener('click', () => { for (const k of ['outline', 'shadow', 'tint', 'hue', 'saturation', 'brightness', 'recolor', 'blend']) delete l[k]; markDirty(); requestRender(); renderProps(); });
  $('#btnDelLayer').addEventListener('click', () => { state.scene.layers = state.scene.layers.filter(x => x !== l); state.sel = null; markDirty(); renderLayers(); renderProps(); requestRender(); });
  $('#btnPickPalette').addEventListener('click', () => snapToPalette(l));
}
function syncInput(inp, l) {
  const v = getPath(l, inp.dataset.k);
  if (inp.type === 'checkbox') inp.checked = !!v;
  else if (inp.type === 'color') inp.value = normalizeHex(v) || '#000000';
  else inp.value = v == null ? (inp.dataset.k === 'scale' ? layerScale(l).sx : '') : v;
}
function getPath(o, k) { return k.split('.').reduce((a, p) => a == null ? undefined : a[p], o); }
function setPath(o, k, v) { const ps = k.split('.'); let a = o; for (const p of ps.slice(0, -1)) a = a[p] ||= {}; const last = ps.at(-1); if (v === null || v === '') delete a[last]; else a[last] = v; }
function renderRecolor(l) {
  const box = $('#recolor'); if (!box) return; box.innerHTML = '';
  (l.recolor || []).forEach((r, i) => {
    const d = document.createElement('div'); d.className = 'pair';
    d.innerHTML = `<input type="color" value="${normalizeHex(r.from)}"><span>→</span><input type="color" value="${normalizeHex(r.to)}"><button class="mini">×</button>`;
    const [a, b] = d.querySelectorAll('input');
    a.addEventListener('input', () => { r.from = a.value; markDirty(); requestRender(); }); b.addEventListener('input', () => { r.to = b.value; markDirty(); requestRender(); });
    d.querySelector('button').addEventListener('click', () => { l.recolor.splice(i, 1); renderRecolor(l); markDirty(); requestRender(); });
    box.appendChild(d);
  });
}
async function snapToPalette(l) {
  if (!state.palettes.length) return alert('no palettes yet. search LoSpec in the search tab and click one to fetch it.');
  const name = prompt('palette name:\n' + state.palettes.map(p => p.name).join('\n'), state.palettes[0].name); if (!name) return;
  const pal = state.palettes.find(p => p.name.toLowerCase() === name.toLowerCase()); if (!pal) return alert('no such palette');
  const r = await renderScene({ ...state.scene, layers: [{ ...l, recolor: [], x: 0, y: 0, rotation: 0 }] }, env);
  const d = r.canvas.getContext('2d').getImageData(0, 0, r.canvas.width, r.canvas.height).data;
  const seen = new Set(); const rgbs = pal.colors.map(hexToRgb);
  l.recolor = [];
  for (let i = 0; i < d.length; i += 4) {
    if (d[i + 3] < 128) continue;
    const hex = '#' + [d[i], d[i + 1], d[i + 2]].map(v => v.toString(16).padStart(2, '0')).join('');
    if (seen.has(hex)) continue; seen.add(hex);
    let best = 0, bd = Infinity; rgbs.forEach((c, j) => { const dd = (c[0] - d[i]) ** 2 + (c[1] - d[i + 1]) ** 2 + (c[2] - d[i + 2]) ** 2; if (dd < bd) { bd = dd; best = j; } });
    if (pal.colors[best] !== hex) l.recolor.push({ from: hex, to: pal.colors[best] });
  }
  markDirty(); requestRender(); renderProps();
}

// ---------- search ----------
function showTab(n) { $$('.tabs button').forEach(b => b.classList.toggle('active', b.dataset.tab === n)); $$('.tab').forEach(t => t.classList.toggle('active', t.id === 'tab-' + n)); }
$$('.tabs button').forEach(b => b.addEventListener('click', () => { showTab(b.dataset.tab); if (b.dataset.tab === 'draw') drawPixelEditor(); }));
function updateSrcAbout() { const s = state.sources.find(x => x.id === $('#srcSelect').value); $('#srcAbout').textContent = s ? `${s.about} License: ${s.license}` : ''; }
$('#srcSelect').addEventListener('change', updateSrcAbout);
$('#btnSearch').addEventListener('click', doSearch); $('#q').addEventListener('keydown', e => { if (e.key === 'Enter') doSearch(); });
async function doSearch() {
  const source = $('#srcSelect').value, q = $('#q').value.trim();
  status('searching ' + source + '…');
  const box = $('#results'); box.innerHTML = '';
  try {
    const { results, error } = await api.get(`/search?source=${encodeURIComponent(source)}&q=${encodeURIComponent(q)}`);
    if (error) status(error, 'err'); else status(`${results.length} results`, 'ok');
    for (const r of results) box.appendChild(resultCard(r));
  } catch (e) { status(e.message, 'err'); }
}
function licClass(lic = '') { lic = lic.toLowerCase(); return lic.includes('cc0') || lic.includes('public') || lic === 'ours' || lic === 'yours' ? 'cc0' : lic.includes('by') || lic.includes('ofl') || lic.includes('apache') ? 'by' : 'other'; }
function resultCard(r) {
  const d = document.createElement('div'); d.className = 'card'; d.title = `${r.title}\n${r.license || ''}\n${r.author || ''}\n${r.url || ''}`;
  const thumb = r.colors ? `<div class="swatches">${r.colors.map(c => `<i style="background:${c}"></i>`).join('')}</div>` : r.kind === 'font' ? `<span style="font-size:20px">Aa</span>` : r.thumb ? `<img src="${r.thumb}" loading="lazy" onerror="this.remove()">` : '';
  d.innerHTML = `<div class="thumb">${thumb}</div><div class="title">${esc(r.title)}</div><div class="lic ${licClass(r.license)}">${esc(r.license || '')}</div><span class="kind">${r.kind}</span>`;
  d.addEventListener('click', () => useResult(r));
  return d;
}
async function useResult(r) {
  if (r.kind === 'error') return;
  if (r.kind === 'pack') {
    if (!confirm(`Download the whole "${r.title}" pack into library/${r.source}/${r.id}/ ?\nLicense: ${r.license}`)) return;
    status('fetching pack… (can take a minute)');
    try { const res = await api.send('POST', '/fetch', { source: r.source, id: r.id }); status(`fetched ${res.count} files`, 'ok'); showTab('library'); $('#libQ').value = r.id; refreshLibrary(); }
    catch (e) { status(e.message, 'err'); alert(e.message); }
    return;
  }
  if (r.kind === 'palette') {
    try { const res = await api.send('POST', '/fetch', { source: r.source, id: r.id }); state.palettes.push(res.palette); renderPalettes(); status(`palette "${res.palette.name}" saved`, 'ok'); showTab('draw'); }
    catch (e) { status(e.message, 'err'); }
    return;
  }
  if (r.kind === 'font') {
    const l = findLayer(state.scene, state.sel);
    if (l && l.type === 'text') { l.font = r.id; markDirty(); requestRender(); renderProps(); } else addLayer('text', { text: 'TEXT', font: r.id, size: 8, color: '#ffffff' });
    return;
  }
  // image
  let p = r.path;
  if (!p) { status('fetching…'); try { const res = await api.send('POST', '/fetch', { source: r.source, id: r.id }); p = res.paths[0]; } catch (e) { status(e.message, 'err'); return; } }
  const l = addLayer('image', { src: p, name: r.title });
  if (/\.svg$/i.test(p)) { const s = Math.max(8, Math.min(state.scene.width, state.scene.height)); l.crop = null; l.scale = +(s / 512).toFixed(3); l.name = r.title; }
  status(`added ${p}`, 'ok');
}

// ---------- library ----------
async function refreshLibrary() {
  const q = $('#libQ').value.trim();
  const { items } = await api.get('/library?q=' + encodeURIComponent(q));
  const box = $('#library'); box.innerHTML = '';
  for (const i of items.slice(0, 600)) box.appendChild(resultCard({ id: i.path, source: 'local', title: i.name, kind: 'image', license: i.license, author: i.author, url: i.url, thumb: '/files/' + i.path, path: i.path }));
  if (items.length > 600) box.insertAdjacentHTML('beforeend', `<div class="muted small">${items.length - 600} more, narrow the filter</div>`);
}
$('#btnLibRefresh').addEventListener('click', refreshLibrary); $('#libQ').addEventListener('input', debounce(refreshLibrary, 300));
window.addEventListener('dragover', e => { e.preventDefault(); $('#drop').classList.remove('hidden'); });
window.addEventListener('dragleave', e => { if (!e.relatedTarget) $('#drop').classList.add('hidden'); });
window.addEventListener('drop', async e => {
  e.preventDefault(); $('#drop').classList.add('hidden');
  for (const f of e.dataTransfer.files) {
    if (!f.type.startsWith('image/')) continue;
    const dataUrl = await new Promise(r => { const fr = new FileReader(); fr.onload = () => r(fr.result); fr.readAsDataURL(f); });
    try { const { path } = await api.send('POST', '/upload', { name: f.name, dataUrl }); status('added ' + path, 'ok'); addLayer('image', { src: path, name: f.name.replace(/\.[^.]+$/, '') }); } catch (err) { status(err.message, 'err'); }
  }
  showTab('library'); refreshLibrary();
});

// ---------- pixel editor ----------
const px = $('#pxCanvas');
function pixelsLayer() { const l = findLayer(state.scene, state.sel); return l && l.type === 'pixels' ? l : null; }
function drawPixelEditor() {
  const l = pixelsLayer(); const ctx = px.getContext('2d');
  ctx.clearRect(0, 0, px.width, px.height);
  renderPaletteBar(l);
  if (!l) return;
  const w = Math.max(...l.rows.map(r => r.length)), h = l.rows.length; const cell = Math.floor(256 / Math.max(w, h));
  px.width = w * cell; px.height = h * cell;
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) { const c = l.palette[l.rows[y][x]]; if (c) { ctx.fillStyle = c; ctx.fillRect(x * cell, y * cell, cell, cell); } }
  ctx.strokeStyle = 'rgba(255,255,255,0.1)'; ctx.beginPath();
  for (let x = 0; x <= w; x++) { ctx.moveTo(x * cell + 0.5, 0); ctx.lineTo(x * cell + 0.5, h * cell); }
  for (let y = 0; y <= h; y++) { ctx.moveTo(0, y * cell + 0.5); ctx.lineTo(w * cell, y * cell + 0.5); }
  ctx.stroke();
}
function renderPaletteBar(l) {
  const bar = $('#paletteBar'); bar.innerHTML = '';
  if (!l) { bar.innerHTML = '<span class="muted small">select or add a pixels layer</span>'; return; }
  for (const [ch, col] of Object.entries(l.palette)) {
    const d = document.createElement('div'); d.className = 'sw' + (ch === state.pxColorChar ? ' sel' : ''); d.title = ch + ' ' + (col || 'erase');
    d.innerHTML = `<i style="background:${col || 'transparent'}"></i><span>${ch}</span>`;
    d.addEventListener('click', () => { state.pxColorChar = ch; if (col) $('#pxColor').value = col; renderPaletteBar(l); });
    d.addEventListener('contextmenu', e => { e.preventDefault(); if (ch === '.' ) return; if (confirm(`remove color ${ch}?`)) { delete l.palette[ch]; l.rows = l.rows.map(r => r.replaceAll(ch, '.')); markDirty(); drawPixelEditor(); requestRender(); } });
    bar.appendChild(d);
  }
}
$('#btnAddColor').addEventListener('click', () => {
  const l = pixelsLayer(); if (!l) return;
  const used = new Set(Object.keys(l.palette)); const ch = [...'kwrgbycmoKWRGBYCMO0123456789abdefhijlnpqstuvxzABDEFHIJLNPQSTUVXZ'].find(c => !used.has(c));
  if (!ch) return alert('palette full'); l.palette[ch] = $('#pxColor').value; state.pxColorChar = ch; markDirty(); renderPaletteBar(l);
});
$('#pxColor').addEventListener('input', () => { const l = pixelsLayer(); if (l && state.pxColorChar !== '.' && l.palette[state.pxColorChar] != null) { l.palette[state.pxColorChar] = $('#pxColor').value; markDirty(); drawPixelEditor(); requestRender(); } });
let painting = false;
function paintAt(e) {
  const l = pixelsLayer(); if (!l) return;
  const r = px.getBoundingClientRect(); const w = Math.max(...l.rows.map(r => r.length)), h = l.rows.length;
  const x = Math.floor((e.clientX - r.left) / r.width * w), y = Math.floor((e.clientY - r.top) / r.height * h);
  if (x < 0 || y < 0 || x >= w || y >= h) return;
  const ch = e.buttons === 2 ? '.' : state.pxColorChar;
  const row = l.rows[y].padEnd(w, '.'); if (row[x] === ch) return;
  l.rows[y] = row.slice(0, x) + ch + row.slice(x + 1); markDirty(); drawPixelEditor(); requestRender();
}
px.addEventListener('contextmenu', e => e.preventDefault());
px.addEventListener('pointerdown', e => { painting = true; paintAt(e); });
px.addEventListener('pointermove', e => { if (painting) paintAt(e); });
window.addEventListener('pointerup', () => { painting = false; });
$('#btnSaveSprite').addEventListener('click', async () => {
  const l = pixelsLayer(); if (!l) return alert('select a pixels layer first');
  const name = prompt('sprite name (saved to sprites/<name>.txt, reusable in any scene, editable by Claude)', l.name.replace(/\W+/g, '_')); if (!name) return;
  const { path } = await api.send('POST', '/sprite', { name, text: pixelTextFromLayer(l, name) });
  if (confirm(`saved ${path}. Replace this layer with an image layer that references it? (recommended)`)) {
    const i = state.scene.layers.indexOf(l);
    const nl = newLayer('image', { src: path, name, x: l.x, y: l.y, scale: l.scale, flipX: l.flipX, flipY: l.flipY, opacity: l.opacity, outline: l.outline, shadow: l.shadow });
    state.scene.layers[i] = nl; state.sel = nl.id; clearRenderCache(); renderLayers(); renderProps();
  }
  markDirty(); requestRender(); refreshLibrary(); status('saved ' + path, 'ok');
});
function renderPalettes() {
  const box = $('#lospecPalettes'); box.innerHTML = state.palettes.length ? '<div class="muted">palettes (click a swatch to add it to the current pixel layer)</div>' : '<div class="muted">no palettes yet: search LoSpec in the search tab.</div>';
  for (const p of state.palettes) {
    const d = document.createElement('div'); d.className = 'palRow'; d.innerHTML = `<b>${esc(p.name)}</b> ` + p.colors.map(c => `<i style="background:${c}" title="${c}"></i>`).join('');
    d.querySelectorAll('i').forEach((el, i) => el.addEventListener('click', () => { $('#pxColor').value = p.colors[i]; $('#btnAddColor').click(); }));
    box.appendChild(d);
  }
}

// ---------- ideas ----------
async function loadIdeas(name) { state.ideasName = name; const { text, mtime } = await api.get('/ideas/' + encodeURIComponent(name)); $('#ideas').value = text; state.ideasMtime = mtime; state.ideasDirty = false; }
$('#ideasSelect').addEventListener('change', e => loadIdeas(e.target.value));
$('#ideas').addEventListener('input', () => { state.ideasDirty = true; $('#ideasStatus').textContent = 'unsaved…'; saveIdeasSoon(); });
const saveIdeasSoon = debounce(async () => {
  try { const { mtime } = await api.send('PUT', '/ideas/' + encodeURIComponent(state.ideasName), { text: $('#ideas').value }); state.ideasMtime = mtime; state.ideasDirty = false; $('#ideasStatus').textContent = 'saved ideas/' + state.ideasName + '.md'; }
  catch (e) { $('#ideasStatus').textContent = e.message; }
}, 800);

// ---------- utils ----------
function esc(s) { return String(s ?? '').replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c])); }
function debounce(fn, ms) { let t; return (...a) => { clearTimeout(t); t = setTimeout(() => fn(...a), ms); }; }
window.addEventListener('beforeunload', e => { if (state.dirty) { e.preventDefault(); e.returnValue = ''; } });

boot().catch(e => status('boot failed: ' + e.message, 'err'));
