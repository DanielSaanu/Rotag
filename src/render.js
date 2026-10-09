// Canvas-agnostic scene renderer. Runs in the browser (DOM canvas) and in node (@napi-rs/canvas).
//
// env = {
//   createCanvas(w, h)         -> canvas with getContext('2d')
//   loadImage(src)             -> Promise<drawable>  (png/jpg/svg/webp). src is repo-relative or URL.
//   readText(src)              -> Promise<string>    (for sprites/*.txt pixel files and nested scenes)
//   ensureFont(family)         -> Promise<void>      (node registers the ttf; browser waits for document.fonts)
// }
import { layerScale, normalizeScene } from './scene.js';
import { parsePixelText, paintPixels, hexToRgb } from './pixels.js';

const imageCache = new Map();

export function clearRenderCache() { imageCache.clear(); }

/**
 * Render a scene. Returns { canvas, layers: [{ id, bounds:{x,y,w,h}, size:{w,h} }] }
 * opts.scale: integer upscale of the final output (preview). opts.onlyLayer: render one layer id.
 */
export async function renderScene(sceneIn, env, opts = {}) {
  const scene = normalizeScene(sceneIn);
  const out = env.createCanvas(scene.width, scene.height);
  const ctx = out.getContext('2d');
  ctx.imageSmoothingEnabled = !scene.pixelated;
  if (scene.background && scene.background !== 'transparent') {
    ctx.fillStyle = scene.background;
    ctx.fillRect(0, 0, scene.width, scene.height);
  }
  const infos = [];
  for (const layer of scene.layers) {
    const info = { id: layer.id, bounds: null, size: null, error: null };
    infos.push(info);
    if (layer.visible === false) continue;
    if (opts.onlyLayer && opts.onlyLayer !== layer.id) continue;
    try {
      const built = await buildLayer(layer, env, scene);
      if (!built) continue;
      info.size = { w: built.w, h: built.h };
      info.bounds = drawLayer(ctx, layer, built, scene);
    } catch (e) {
      info.error = e.message || String(e);
      if (opts.strict) throw e;
    }
  }
  if (opts.scale && opts.scale !== 1) {
    const s = opts.scale;
    const big = env.createCanvas(Math.round(scene.width * s), Math.round(scene.height * s));
    const bctx = big.getContext('2d');
    bctx.imageSmoothingEnabled = !scene.pixelated;
    bctx.drawImage(out, 0, 0, big.width, big.height);
    return { canvas: big, layers: infos, scale: s };
  }
  return { canvas: out, layers: infos, scale: 1 };
}

/** Build the layer's own bitmap before transform: returns { canvas, w, h, pad } */
export async function buildLayer(layer, env, scene) {
  let base;
  switch (layer.type) {
    case 'image': base = await buildImage(layer, env); break;
    case 'pixels': base = buildPixels(layer, env); break;
    case 'text': base = await buildText(layer, env, scene); break;
    case 'shape': base = buildShape(layer, env); break;
    case 'scene': base = await buildNested(layer, env); break;
    default: return null;
  }
  if (!base) return null;
  let { canvas, w, h } = base;
  if (needsPixelPass(layer)) canvas = pixelPass(canvas, layer, env);
  let pad = 0;
  if (layer.outline && layer.outline.size > 0) {
    const r = applyOutline(canvas, layer.outline, env);
    canvas = r.canvas; pad = r.pad; w = canvas.width; h = canvas.height;
  }
  return { canvas, w, h, pad };
}

async function getImage(src, env) {
  if (imageCache.has(src)) return imageCache.get(src);
  const p = (async () => {
    if (/\.txt$/i.test(src)) {
      const text = await env.readText(src);
      const px = parsePixelText(text);
      const c = env.createCanvas(Math.max(1, px.width), Math.max(1, px.height));
      paintPixels(c.getContext('2d'), px.rows, px.palette);
      return c;
    }
    return env.loadImage(src);
  })();
  imageCache.set(src, p);
  try { return await p; } catch (e) { imageCache.delete(src); throw e; }
}

async function buildImage(layer, env) {
  if (!layer.src) return null;
  const img = await getImage(layer.src, env);
  const crop = layer.crop && layer.crop.w > 0 && layer.crop.h > 0
    ? layer.crop : { x: 0, y: 0, w: img.width, h: img.height };
  const c = env.createCanvas(Math.max(1, Math.round(crop.w)), Math.max(1, Math.round(crop.h)));
  const ctx = c.getContext('2d');
  ctx.imageSmoothingEnabled = false;
  ctx.drawImage(img, crop.x, crop.y, crop.w, crop.h, 0, 0, c.width, c.height);
  return { canvas: c, w: c.width, h: c.height };
}

function buildPixels(layer, env) {
  const rows = layer.rows || [];
  const w = Math.max(1, ...rows.map(r => r.length));
  const h = Math.max(1, rows.length);
  const c = env.createCanvas(w, h);
  paintPixels(c.getContext('2d'), rows, layer.palette || {});
  return { canvas: c, w, h };
}

async function buildText(layer, env, scene) {
  const family = layer.font || 'sans-serif';
  if (env.ensureFont) await env.ensureFont(family);
  const size = Math.max(1, Number(layer.size) || 8);
  const lines = String(layer.text ?? '').split('\n');
  const lineHeight = Number(layer.lineHeight) || Math.round(size * 1.25);
  const spacing = Number(layer.letterSpacing) || 0;
  const strokeW = layer.stroke && layer.stroke.width ? Number(layer.stroke.width) : 0;
  const measure = env.createCanvas(1, 1).getContext('2d');
  measure.font = `${layer.weight || ''} ${size}px "${family}"`.trim();
  const widths = lines.map(t => measureLine(measure, t, spacing));
  const w = Math.max(1, Math.ceil(Math.max(...widths) + strokeW * 2 + 2));
  const h = Math.max(1, Math.ceil(lineHeight * lines.length + strokeW * 2 + 2));
  const c = env.createCanvas(w, h);
  const ctx = c.getContext('2d');
  ctx.imageSmoothingEnabled = !(scene && scene.pixelated);
  ctx.font = measure.font;
  ctx.textBaseline = 'top';
  const align = layer.align || 'left';
  lines.forEach((t, i) => {
    let x = strokeW + 1;
    if (align === 'center') x = (w - widths[i]) / 2;
    else if (align === 'right') x = w - widths[i] - strokeW - 1;
    const y = strokeW + 1 + i * lineHeight;
    if (strokeW > 0) {
      ctx.lineJoin = 'round';
      ctx.lineWidth = strokeW * 2;
      ctx.strokeStyle = layer.stroke.color || '#000000';
      drawLine(ctx, t, x, y, spacing, 'stroke');
    }
    ctx.fillStyle = layer.color || '#ffffff';
    drawLine(ctx, t, x, y, spacing, 'fill');
  });
  return { canvas: c, w, h };
}

function measureLine(ctx, text, spacing) {
  if (!spacing) return ctx.measureText(text).width;
  let w = 0;
  for (const ch of text) w += ctx.measureText(ch).width + spacing;
  return Math.max(0, w - spacing);
}

function drawLine(ctx, text, x, y, spacing, mode) {
  if (!spacing) { mode === 'fill' ? ctx.fillText(text, x, y) : ctx.strokeText(text, x, y); return; }
  for (const ch of text) {
    mode === 'fill' ? ctx.fillText(ch, x, y) : ctx.strokeText(ch, x, y);
    x += ctx.measureText(ch).width + spacing;
  }
}

function buildShape(layer, env) {
  const w = Math.max(1, Math.round(Number(layer.w) || 16));
  const h = Math.max(1, Math.round(Number(layer.h) || 16));
  const c = env.createCanvas(w, h);
  const ctx = c.getContext('2d');
  const strokeW = layer.stroke && layer.stroke.width ? Number(layer.stroke.width) : 0;
  ctx.fillStyle = makeFill(ctx, layer.fill, w, h);
  ctx.beginPath();
  if (layer.shape === 'ellipse') {
    ctx.ellipse(w / 2, h / 2, Math.max(0.5, w / 2 - strokeW / 2), Math.max(0.5, h / 2 - strokeW / 2), 0, 0, Math.PI * 2);
  } else {
    roundRect(ctx, strokeW / 2, strokeW / 2, w - strokeW, h - strokeW, Number(layer.radius) || 0);
  }
  if (layer.fill !== 'none' && layer.fill != null) ctx.fill();
  if (strokeW > 0) {
    ctx.lineWidth = strokeW;
    ctx.strokeStyle = layer.stroke.color || '#000000';
    ctx.stroke();
  }
  return { canvas: c, w, h };
}

function makeFill(ctx, fill, w, h) {
  if (!fill) return 'transparent';
  if (typeof fill === 'string') return fill;
  if (fill.stops) {
    const a = ((Number(fill.angle) || 0) - 90) * Math.PI / 180;
    const cx = w / 2, cy = h / 2, r = Math.sqrt(w * w + h * h) / 2;
    const g = fill.type === 'radial'
      ? ctx.createRadialGradient(cx, cy, 0, cx, cy, Math.max(w, h) / 2)
      : ctx.createLinearGradient(cx - Math.cos(a) * r, cy - Math.sin(a) * r, cx + Math.cos(a) * r, cy + Math.sin(a) * r);
    for (const s of fill.stops) g.addColorStop(Math.max(0, Math.min(1, Number(s.at) || 0)), s.color);
    return g;
  }
  return 'transparent';
}

function roundRect(ctx, x, y, w, h, r) {
  r = Math.min(r, w / 2, h / 2);
  if (r <= 0) { ctx.rect(x, y, w, h); return; }
  ctx.moveTo(x + r, y);
  ctx.arcTo(x + w, y, x + w, y + h, r);
  ctx.arcTo(x + w, y + h, x, y + h, r);
  ctx.arcTo(x, y + h, x, y, r);
  ctx.arcTo(x, y, x + w, y, r);
  ctx.closePath();
}

async function buildNested(layer, env) {
  if (!layer.src) return null;
  const text = await env.readText(layer.src);
  const sub = JSON.parse(text);
  const r = await renderScene(sub, env);
  return { canvas: r.canvas, w: r.canvas.width, h: r.canvas.height };
}

function needsPixelPass(l) {
  return (l.tint && l.tint.color) || (l.recolor && l.recolor.length) ||
    Number(l.hue) || (l.saturation != null && Number(l.saturation) !== 1) ||
    (l.brightness != null && Number(l.brightness) !== 1);
}

/** Per-pixel effects: recolor map, hue/sat/brightness, tint. */
function pixelPass(canvas, l, env) {
  const c = env.createCanvas(canvas.width, canvas.height);
  const ctx = c.getContext('2d');
  ctx.drawImage(canvas, 0, 0);
  const id = ctx.getImageData(0, 0, c.width, c.height);
  const d = id.data;
  const recolor = (l.recolor || []).map(r => ({ from: hexToRgb(r.from), to: hexToRgb(r.to), tol: Number(r.tolerance) || 0 })).filter(r => r.from && r.to);
  const hue = Number(l.hue) || 0, sat = l.saturation == null ? 1 : Number(l.saturation), bri = l.brightness == null ? 1 : Number(l.brightness);
  const tint = l.tint && l.tint.color ? { rgb: hexToRgb(l.tint.color), mode: l.tint.mode || 'multiply', amount: l.tint.amount == null ? 1 : Number(l.tint.amount) } : null;
  for (let i = 0; i < d.length; i += 4) {
    if (d[i + 3] === 0) continue;
    let r = d[i], g = d[i + 1], b = d[i + 2];
    for (const rc of recolor) {
      if (Math.abs(r - rc.from[0]) <= rc.tol && Math.abs(g - rc.from[1]) <= rc.tol && Math.abs(b - rc.from[2]) <= rc.tol) {
        [r, g, b] = rc.to; break;
      }
    }
    if (hue || sat !== 1 || bri !== 1) {
      let [hh, ss, ll] = rgbToHsl(r, g, b);
      hh = (hh + hue / 360 + 1) % 1; ss = clamp01(ss * sat); ll = clamp01(ll * bri);
      [r, g, b] = hslToRgb(hh, ss, ll);
    }
    if (tint) {
      const [tr, tg, tb] = tint.rgb, a = tint.amount;
      if (tint.mode === 'replace') { r = r + (tr - r) * a; g = g + (tg - g) * a; b = b + (tb - b) * a; }
      else { r = r + (r * tr / 255 - r) * a; g = g + (g * tg / 255 - g) * a; b = b + (b * tb / 255 - b) * a; }
    }
    d[i] = r; d[i + 1] = g; d[i + 2] = b;
  }
  ctx.putImageData(id, 0, 0);
  return c;
}

/** Pixel outline: silhouette stamped at offsets, then the sprite on top. */
function applyOutline(canvas, outline, env) {
  const size = Math.max(1, Math.round(Number(outline.size) || 1));
  const pad = size;
  const sil = env.createCanvas(canvas.width, canvas.height);
  const sctx = sil.getContext('2d');
  sctx.drawImage(canvas, 0, 0);
  sctx.globalCompositeOperation = 'source-in';
  sctx.fillStyle = outline.color || '#000000';
  sctx.fillRect(0, 0, sil.width, sil.height);
  const out = env.createCanvas(canvas.width + pad * 2, canvas.height + pad * 2);
  const octx = out.getContext('2d');
  octx.imageSmoothingEnabled = false;
  for (let dx = -size; dx <= size; dx++) {
    for (let dy = -size; dy <= size; dy++) {
      if (dx === 0 && dy === 0) continue;
      if (!outline.corners && Math.abs(dx) + Math.abs(dy) > size) continue; // diamond = no corner pixels
      octx.drawImage(sil, pad + dx, pad + dy);
    }
  }
  octx.drawImage(canvas, pad, pad);
  return { canvas: out, pad };
}

/** Transform + composite a built layer onto the scene. Returns axis-aligned bounds in scene pixels. */
function drawLayer(ctx, layer, built, scene) {
  const { sx, sy } = layerScale(layer);
  const w = built.w, h = built.h, pad = built.pad || 0;
  // In pixelated scenes snap the top-left corner to the pixel grid (never the center: odd sizes would land on half pixels).
  const x0 = Number(layer.x) - pad, y0 = Number(layer.y) - pad;
  const x = scene.pixelated ? Math.round(x0) : x0, y = scene.pixelated ? Math.round(y0) : y0;
  const cx = x + (w * sx) / 2, cy = y + (h * sy) / 2;
  const rot = (Number(layer.rotation) || 0) * Math.PI / 180;
  ctx.save();
  ctx.globalAlpha = layer.opacity == null ? 1 : Number(layer.opacity);
  ctx.globalCompositeOperation = layer.blend || 'source-over';
  ctx.imageSmoothingEnabled = !scene.pixelated;
  if (layer.shadow && layer.shadow.color) {
    ctx.shadowColor = layer.shadow.color;
    ctx.shadowOffsetX = Number(layer.shadow.x) || 0;
    ctx.shadowOffsetY = Number(layer.shadow.y) || 0;
    ctx.shadowBlur = Number(layer.shadow.blur) || 0;
  }
  ctx.translate(cx, cy);
  if (rot) ctx.rotate(rot);
  ctx.scale(sx * (layer.flipX ? -1 : 1), sy * (layer.flipY ? -1 : 1));
  ctx.drawImage(built.canvas, -w / 2, -h / 2, w, h);
  ctx.restore();
  return rotatedBounds(cx, cy, w * sx, h * sy, rot);
}

function rotatedBounds(cx, cy, w, h, rot) {
  if (!rot) return { x: cx - w / 2, y: cy - h / 2, w, h };
  const c = Math.abs(Math.cos(rot)), s = Math.abs(Math.sin(rot));
  const bw = w * c + h * s, bh = w * s + h * c;
  return { x: cx - bw / 2, y: cy - bh / 2, w: bw, h: bh };
}

function clamp01(v) { return Math.max(0, Math.min(1, v)); }
function rgbToHsl(r, g, b) {
  r /= 255; g /= 255; b /= 255;
  const max = Math.max(r, g, b), min = Math.min(r, g, b);
  let h = 0, s = 0; const l = (max + min) / 2;
  if (max !== min) {
    const d = max - min;
    s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
    if (max === r) h = (g - b) / d + (g < b ? 6 : 0);
    else if (max === g) h = (b - r) / d + 2;
    else h = (r - g) / d + 4;
    h /= 6;
  }
  return [h, s, l];
}
function hslToRgb(h, s, l) {
  if (s === 0) { const v = l * 255; return [v, v, v]; }
  const q = l < 0.5 ? l * (1 + s) : l + s - l * s, p = 2 * l - q;
  const f = t => { t = (t + 1) % 1; if (t < 1 / 6) return p + (q - p) * 6 * t; if (t < 1 / 2) return q; if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6; return p; };
  return [f(h + 1 / 3) * 255, f(h) * 255, f(h - 1 / 3) * 255];
}
