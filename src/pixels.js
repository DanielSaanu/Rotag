// Pixel-text sprite format: hand-drawable by a human or by Claude in any text editor.
//
//   # name: slime_idle
//   # palette: . = transparent, k = #1a1a1a, g = #5ac54f, G = #33984b, w = #ffffff
//   ........
//   ..gggg..
//   .gGGGGg.
//   .gwGGwg.
//   .gGGGGg.
//   ..kkkk..
//
// Each character is one pixel. Lines starting with '#' are directives or comments.
// Also accepts JSON: { "palette": {...}, "rows": [...] }.
// Shared between browser and node.

export function parsePixelText(text) {
  const palette = { '.': null, ' ': null };
  let name = '';
  const rows = [];
  for (const raw of text.split(/\r?\n/)) {
    const line = raw.replace(/\s+$/, '');
    if (!line) continue;
    if (line.startsWith('#')) {
      const m = line.match(/^#\s*(\w+)\s*:\s*(.*)$/);
      if (!m) continue;
      const [, key, val] = m;
      if (key === 'name') name = val.trim();
      else if (key === 'palette') {
        for (const part of val.split(',')) {
          const pm = part.trim().match(/^(\S)\s*=\s*(\S+)$/);
          if (!pm) continue;
          palette[pm[1]] = /^(transparent|none|-)$/i.test(pm[2]) ? null : normalizeHex(pm[2]);
        }
      }
      continue;
    }
    rows.push(line);
  }
  const width = Math.max(0, ...rows.map(r => r.length));
  return { name, palette, rows: rows.map(r => r.padEnd(width, '.')), width, height: rows.length };
}

export function pixelTextFromLayer(l, name = '') {
  const lines = [];
  if (name) lines.push(`# name: ${name}`);
  const pal = Object.entries(l.palette || {}).map(([k, v]) => `${k} = ${v == null ? 'transparent' : v}`);
  lines.push(`# palette: ${pal.join(', ')}`);
  lines.push(...(l.rows || []));
  return lines.join('\n') + '\n';
}

/** Paint rows+palette into a canvas-like context. Returns {width,height}. */
export function paintPixels(ctx, rows, palette) {
  const width = Math.max(0, ...rows.map(r => r.length));
  for (let y = 0; y < rows.length; y++) {
    const row = rows[y];
    for (let x = 0; x < row.length; x++) {
      const c = palette[row[x]];
      if (!c) continue;
      ctx.fillStyle = c;
      ctx.fillRect(x, y, 1, 1);
    }
  }
  return { width, height: rows.length };
}

export function normalizeHex(h) {
  if (!h) return null;
  h = String(h).trim();
  if (h[0] !== '#') h = '#' + h;
  if (h.length === 4) h = '#' + h[1] + h[1] + h[2] + h[2] + h[3] + h[3];
  return h.toLowerCase();
}

export function hexToRgb(h) {
  h = normalizeHex(h);
  if (!h) return null;
  return [parseInt(h.slice(1, 3), 16), parseInt(h.slice(3, 5), 16), parseInt(h.slice(5, 7), 16)];
}

export function rgbToHex(r, g, b) {
  return '#' + [r, g, b].map(v => Math.max(0, Math.min(255, Math.round(v))).toString(16).padStart(2, '0')).join('');
}

/** Convert a canvas (via getImageData) into pixel-text rows + palette. Handy for Claude to read a sprite. */
export function imageDataToPixelText(imageData, opts = {}) {
  const { width, height, data } = imageData;
  const chars = opts.chars || 'kwrgbycmoKWRGBYCMO0123456789abdefhijlnpqstuvxzABDEFHIJLNPQSTUVXZ!@$%^&*+=<>?~';
  const palette = { '.': null };
  const colorToChar = new Map();
  let ci = 0;
  const rows = [];
  for (let y = 0; y < height; y++) {
    let row = '';
    for (let x = 0; x < width; x++) {
      const i = (y * width + x) * 4;
      if (data[i + 3] < 128) { row += '.'; continue; }
      const hex = rgbToHex(data[i], data[i + 1], data[i + 2]);
      let ch = colorToChar.get(hex);
      if (!ch) {
        ch = chars[ci++] || '?';
        colorToChar.set(hex, ch);
        palette[ch] = hex;
      }
      row += ch;
    }
    rows.push(row);
  }
  return { palette, rows, width, height };
}
