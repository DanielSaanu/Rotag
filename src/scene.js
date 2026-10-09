// Scene format. One JSON file = one composed image. Both the UI and Claude edit these.
// Shared between browser and node: no imports of node builtins here.

/**
 * @typedef {Object} Scene
 * @property {string} name
 * @property {number} width
 * @property {number} height
 * @property {string} [background]   hex color or "transparent"
 * @property {boolean} [pixelated]   nearest-neighbour scaling, integer snapping
 * @property {Layer[]} layers        bottom -> top
 * @property {string} [notes]        free text, ideas about this specific scene
 */

/**
 * Common layer fields:
 *  id, name, type, x, y, scale|scaleX|scaleY, rotation (deg), flipX, flipY, opacity,
 *  visible, locked, tint{color,mode:'multiply'|'replace',amount}, hue, saturation, brightness,
 *  recolor[{from,to,tolerance}], outline{color,size,corners}, shadow{color,x,y,blur}
 * Per type:
 *  image : src (png/jpg/svg/webp or sprites/*.txt pixel file), crop{x,y,w,h}
 *  pixels: rows[], palette{char:hex|null}
 *  text  : text, font, size, color, stroke{color,width}, letterSpacing, lineHeight
 *  shape : shape:'rect'|'ellipse', w, h, fill (hex or {angle,stops:[{at,color}]}), stroke{color,width}, radius
 *  scene : src (another scene json), rendered then treated like an image
 */

export const LAYER_TYPES = ['image', 'pixels', 'text', 'shape', 'scene'];

export function newScene(name = 'untitled', width = 64, height = 64) {
  return { name, width, height, background: 'transparent', pixelated: true, layers: [], notes: '' };
}

let counter = 0;
export function newId(prefix = 'l') {
  counter += 1;
  return `${prefix}_${Date.now().toString(36)}${counter.toString(36)}`;
}

export function newLayer(type, extra = {}) {
  const base = {
    id: newId(), name: type, type, x: 0, y: 0, scale: 1, rotation: 0,
    flipX: false, flipY: false, opacity: 1, visible: true, locked: false,
  };
  const perType = {
    image: { src: '', crop: null },
    pixels: { rows: ['..', '..'], palette: { '.': null, '#': '#000000' } },
    text: { text: 'TEXT', font: 'Press Start 2P', size: 8, color: '#ffffff', stroke: null },
    shape: { shape: 'rect', w: 16, h: 16, fill: '#ffffff', stroke: null, radius: 0 },
    scene: { src: '' },
  }[type] || {};
  return { ...base, ...perType, ...extra };
}

/** Fill in defaults so the renderer and UI never see undefined. Returns a new object. */
export function normalizeScene(input) {
  const s = { ...newScene(), ...input };
  s.width = clampInt(s.width, 1, 4096);
  s.height = clampInt(s.height, 1, 4096);
  s.layers = (s.layers || []).map((l, i) => normalizeLayer(l, i));
  return s;
}

export function normalizeLayer(l, i = 0) {
  const type = LAYER_TYPES.includes(l.type) ? l.type : 'image';
  const out = { ...newLayer(type), ...l, type };
  if (!out.id) out.id = newId();
  if (!out.name) out.name = `${type} ${i + 1}`;
  out.x = num(out.x, 0); out.y = num(out.y, 0);
  out.scale = num(out.scale, 1);
  out.rotation = num(out.rotation, 0);
  out.opacity = Math.max(0, Math.min(1, num(out.opacity, 1)));
  return out;
}

export function layerScale(l) {
  return { sx: num(l.scaleX, num(l.scale, 1)), sy: num(l.scaleY, num(l.scale, 1)) };
}

export function findLayer(scene, id) { return scene.layers.find(l => l.id === id); }

export function moveLayer(scene, id, delta) {
  const i = scene.layers.findIndex(l => l.id === id);
  if (i < 0) return;
  const j = Math.max(0, Math.min(scene.layers.length - 1, i + delta));
  const [l] = scene.layers.splice(i, 1);
  scene.layers.splice(j, 0, l);
}

/** Validate and return a list of human readable problems (empty = ok). */
export function validateScene(s) {
  const errs = [];
  if (!s || typeof s !== 'object') return ['scene is not an object'];
  if (!Number.isFinite(s.width) || !Number.isFinite(s.height)) errs.push('width/height must be numbers');
  if (!Array.isArray(s.layers)) errs.push('layers must be an array');
  else s.layers.forEach((l, i) => {
    if (!LAYER_TYPES.includes(l.type)) errs.push(`layer ${i}: unknown type "${l.type}"`);
    if ((l.type === 'image' || l.type === 'scene') && !l.src) errs.push(`layer ${i} (${l.name || l.type}): missing src`);
    if (l.type === 'pixels' && !Array.isArray(l.rows)) errs.push(`layer ${i}: pixels needs rows[]`);
  });
  return errs;
}

function num(v, d) { const n = Number(v); return Number.isFinite(n) ? n : d; }
function clampInt(v, lo, hi) { return Math.max(lo, Math.min(hi, Math.round(num(v, lo)))); }
