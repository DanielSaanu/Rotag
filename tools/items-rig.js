// Generates the item sprites (SVG) and their scenes from the design canvas "Rotag items and holds"
// (docs/briefs/items-art.md, pass 3). Run: node tools/items-rig.js. Edit the geometry here, never the SVGs.
// Style: graphite bodies (ink, facet) with one neon light each, hard white speculars, 32 px per stud.
import fs from 'fs';
import path from 'path';

const C = { ink: '#1b1b2f', facet: '#2e3050', white: '#ffffff', lime: '#b6ff3b', violet: '#9d7bff', magenta: '#ff3df2',
  pink: '#ffd1f4', orange: '#ff8a5b', red: '#ff3b3b', cyan: '#45e0ff', frost: '#dffbff' };

const out = {}; // name -> { svg, w, h, note }
function put(name, inner, vw, vh, w, h, note) {
  out[name] = { w, h, note, svg: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${vw} ${vh}" width="${w}" height="${h}" shape-rendering="geometricPrecision">${inner}</svg>` };
}
const sq = (name, inner, px, note) => put(name, inner, 128, 128, px, px, note);

// ---------- orbs (64 px = 2 studs): a sphere, the band turns, the light is fixed ----------
function orbBody(neon) {
  return `<circle cx="64" cy="64" r="34" fill="${C.ink}"/><circle cx="64" cy="64" r="29" fill="${C.facet}"/>` +
    `<circle cx="64" cy="64" r="29" fill="none" stroke="${neon}" stroke-width="1.5"/>` +
    `<path d="M 38 54 A 29 29 0 0 1 70 36" fill="none" stroke="${neon}" stroke-width="5" stroke-linecap="round"/>`;
}
const spec = (big) => `<ellipse cx="52" cy="49" rx="${big ? 9 : 7}" ry="${big ? 5 : 4}" fill="${C.white}" transform="rotate(-35 52 49)"/><circle cx="79" cy="81" r="3" fill="${C.white}"/>`;
const glint = `<path d="M 40 36 L 36 32 M 44 30 L 42 26 M 34 44 L 30 42" stroke="${C.white}" stroke-width="2.5" stroke-linecap="round"/>`;
const band = (neon, deg) => deg === 'edge' ? `<path d="M 64 35 L 64 93" stroke="${neon}" stroke-width="3"/>`
  : `<ellipse cx="64" cy="64" rx="29" ry="8" fill="none" stroke="${neon}" stroke-width="2.5" transform="rotate(${deg} 64 64)"/>`;
const SPIN = [0, 45, 'edge', -45];
SPIN.forEach((deg, i) => sq(`orb_spin_${i}`, orbBody(C.lime) + band(C.lime, deg) + spec(deg === 'edge') + (deg === 'edge' ? glint : ''), 64,
  'living orb spin frame (1.0 s loop, the band turns, the light is fixed)'));
// taken: flash; split along the seams; the band rings wide; faint spot
const cap = (neon, dy, op = 1) => `<g transform="translate(0 ${dy})" opacity="${op}"><path d="M 37 52 A 29 29 0 0 1 91 52 Z" fill="${C.facet}" stroke="${C.ink}" stroke-width="3"/>` +
  `<path d="M 37 52 A 29 29 0 0 1 91 52" fill="none" stroke="${neon}" stroke-width="2"/><path d="M 38 54 A 29 29 0 0 1 70 36" fill="none" stroke="${neon}" stroke-width="5" stroke-linecap="round"/>` +
  `<ellipse cx="52" cy="49" rx="7" ry="4" fill="${C.white}" transform="rotate(-35 52 49)"/></g>`;
const shellL = (neon, d, op = 1) => `<g transform="translate(${-d} ${d * 0.8})" opacity="${op}"><path d="M 36 70 A 29 29 0 0 0 60 92 L 56 78 A 15 15 0 0 1 44 70 Z" fill="${C.facet}" stroke="${C.ink}" stroke-width="3"/><path d="M 36 70 A 29 29 0 0 0 60 92" fill="none" stroke="${neon}" stroke-width="1.5" opacity="0.6"/></g>`;
const shellR = (neon, d, op = 1) => `<g transform="translate(${d} ${d * 0.8})" opacity="${op}"><path d="M 92 70 A 29 29 0 0 1 68 92 L 72 78 A 15 15 0 0 0 84 70 Z" fill="${C.facet}" stroke="${C.ink}" stroke-width="3"/><path d="M 92 70 A 29 29 0 0 1 68 92" fill="none" stroke="${neon}" stroke-width="1.5" opacity="0.6"/></g>`;
const ring = (neon, rx, ry, op) => `<ellipse cx="64" cy="64" rx="${rx}" ry="${ry}" fill="none" stroke="${neon}" stroke-width="2.5" opacity="${op}" transform="rotate(12 64 64)"/>`;
sq('orb_take_0', `<circle cx="64" cy="64" r="34" fill="${C.ink}"/><circle cx="64" cy="64" r="29" fill="${C.white}"/><circle cx="64" cy="64" r="40" fill="none" stroke="${C.lime}" stroke-width="2"/>`, 64, 'taken: white flash in a ring');
sq('orb_take_1', cap(C.lime, -10) + ring(C.lime, 32, 9, 1) + shellL(C.lime, 10) + shellR(C.lime, 10) + `<circle cx="64" cy="64" r="7" fill="${C.white}"/>`, 64, 'taken: splits along its seams');
sq('orb_take_2', ring(C.lime, 46, 13, 0.6) + cap(C.lime, -26, 0.7) + shellL(C.lime, 24, 0.5) + shellR(C.lime, 24, 0.5) +
  `<path d="M 64 50 L 64 56 M 78 64 L 72 64 M 64 78 L 64 72 M 50 64 L 56 64" stroke="${C.white}" stroke-width="3" stroke-linecap="round"/>`, 64, 'taken: the band rings wide, the core bursts');
sq('orb_take_3', `<circle cx="64" cy="64" r="29" fill="none" stroke="${C.lime}" stroke-width="1.5" opacity="0.25"/>`, 64, 'taken: the faint spot');

// ghost orb: the same sphere as a wireframe
function wireBody(neon) {
  return `<circle cx="64" cy="64" r="29" fill="none" stroke="${C.ink}" stroke-width="8"/><circle cx="64" cy="64" r="29" fill="none" stroke="${neon}" stroke-width="3"/>` +
    `<path d="M 40 52 A 29 29 0 0 1 60 36" fill="none" stroke="${C.white}" stroke-width="3.5" stroke-linecap="round"/><circle cx="64" cy="64" r="5" fill="${neon}" opacity="0.6"/>`;
}
const wband = (neon, deg) => deg === 'edge' ? `<path d="M 64 35 L 64 93" stroke="${neon}" stroke-width="2.5"/>`
  : `<ellipse cx="64" cy="64" rx="29" ry="8" fill="none" stroke="${neon}" stroke-width="2" transform="rotate(${deg} 64 64)"/>`;
SPIN.forEach((deg, i) => sq(`ghost_orb_spin_${i}`, wireBody(C.violet) + wband(C.violet, deg) + (deg === 'edge' ? glint : ''), 64, 'ghost orb spin frame (wire)'));
const warc = (neon, d, dx, dy, op, extra = '') => `<g transform="translate(${dx} ${dy})" opacity="${op}"><path d="${d}" fill="none" stroke="${C.ink}" stroke-width="7" stroke-linecap="round"/><path d="${d}" fill="none" stroke="${neon}" stroke-width="3" stroke-linecap="round"/>${extra}</g>`;
const TOP = 'M 37 52 A 29 29 0 0 1 91 52', LO = 'M 36 70 A 29 29 0 0 0 60 92', RO = 'M 92 70 A 29 29 0 0 1 68 92';
const wspec = `<path d="M 40 52 A 29 29 0 0 1 60 36" fill="none" stroke="${C.white}" stroke-width="3.5" stroke-linecap="round"/>`;
sq('ghost_orb_take_0', `<circle cx="64" cy="64" r="29" fill="none" stroke="${C.ink}" stroke-width="8"/><circle cx="64" cy="64" r="29" fill="none" stroke="${C.white}" stroke-width="5"/><circle cx="64" cy="64" r="8" fill="${C.white}"/>`, 64, 'ghost taken: the wire flashes white');
sq('ghost_orb_take_1', warc(C.violet, TOP, 0, -10, 1, wspec) + `<ellipse cx="64" cy="64" rx="31" ry="8" fill="none" stroke="${C.violet}" stroke-width="2" transform="translate(10 0) rotate(12 64 64)"/>` +
  warc(C.violet, LO, -10, 8, 1) + warc(C.violet, RO, 10, 8, 1) + `<circle cx="64" cy="64" r="5" fill="${C.white}" opacity="0.8"/>`, 64, 'ghost taken: splits along its seams');
sq('ghost_orb_take_2', `<ellipse cx="64" cy="64" rx="46" ry="13" fill="none" stroke="${C.violet}" stroke-width="2" opacity="0.45" transform="rotate(12 64 64)"/>` +
  `<g opacity="0.5" transform="translate(0 -26)"><path d="${TOP}" fill="none" stroke="${C.violet}" stroke-width="2.5" stroke-linecap="round"/>${wspec}</g>` +
  `<path d="${LO}" fill="none" stroke="${C.violet}" stroke-width="2.5" stroke-linecap="round" opacity="0.4" transform="translate(-24 18)"/><path d="${RO}" fill="none" stroke="${C.violet}" stroke-width="2.5" stroke-linecap="round" opacity="0.4" transform="translate(24 18)"/>` +
  `<circle cx="64" cy="64" r="3" fill="${C.white}" opacity="0.5"/>`, 64, 'ghost taken: the arcs drift and fade');
sq('ghost_orb_take_3', `<circle cx="64" cy="64" r="29" fill="none" stroke="${C.violet}" stroke-width="1.5" opacity="0.25"/>`, 64, 'ghost taken: the faint spot');

// ---------- hex (64 px, over a ghost's head): the pass 1 diamond ----------
const hexBody = (op) => `<polygon points="64,14 110,64 64,114 18,64" fill="${C.ink}"/><polygon points="64,22 102,64 64,106 26,64" fill="${C.magenta}" opacity="${op}"/>` +
  `<polygon points="64,38 88,64 64,90 40,64" fill="${C.ink}"/>`;
const rune = (op) => `<path d="M 54 56 L 74 72 M 74 56 L 54 72" stroke="${C.pink}" stroke-width="5" stroke-linecap="round" opacity="${op}"/><circle cx="64" cy="64" r="4" fill="${C.pink}" opacity="${op}"/>`;
sq('hex_dim', hexBody(0.4) + rune(0.5), 64, 'hex, ward up: dim');
sq('hex_ready', hexBody(1) + rune(1), 64, 'hex ready');
sq('hex_pulse', hexBody(1) + rune(1) + `<polygon points="64,4 124,64 64,124 4,64" fill="none" stroke="${C.magenta}" stroke-width="2.5" opacity="0.5"/>`, 64, 'hex ready, the pulse ring');
sq('hex_spent', `<polygon points="64,14 110,64 64,114 18,64" fill="${C.ink}" opacity="0.6"/><path d="M 64 22 L 58 50 L 70 64 L 62 100" fill="none" stroke="${C.pink}" stroke-width="3"/>` +
  `<polygon points="64,22 102,64 70,64 58,50" fill="${C.magenta}" opacity="0.7" transform="translate(4 -3)"/><polygon points="58,50 70,64 64,106 26,64" fill="${C.magenta}" opacity="0.5" transform="translate(-4 3)"/>`, 64, 'hex spent: cracked in two');

// ---------- crate (96 px = 3 studs): a chamfered graphite cube, orange X brace ----------
const crateBody = (shear) => {
  const s = shear || 0;
  return `<polygon points="${28 + s},30 ${100 + s},30 ${108 + s},38 108,110 100,118 28,118 20,110 ${20 + s},38" fill="${C.ink}"/>` +
    `<polygon points="${32 + s},36 ${96 + s},36 ${102 + s},42 102,106 96,112 32,112 26,106 ${26 + s},42" fill="${C.facet}"/>` +
    `<path d="M ${32 + s} 36 L ${96 + s} 36 L ${102 + s} 42" fill="none" stroke="${C.orange}" stroke-width="3"/>`;
};
const brace = (col, s = 0) => `<path d="M ${34 + s} 44 L 94 104 M ${94 + s} 44 L 34 104" stroke="${C.ink}" stroke-width="9"/><path d="M ${34 + s} 44 L 94 104 M ${94 + s} 44 L 34 104" stroke="${col}" stroke-width="2.5"/>` +
  `<rect x="${34 + s}" y="40" width="5" height="5" fill="${C.orange}"/><rect x="${89 + s}" y="40" width="5" height="5" fill="${C.orange}"/><rect x="34" y="103" width="5" height="5" fill="${C.orange}"/><rect x="89" y="103" width="5" height="5" fill="${C.orange}"/>`;
sq('crate_0', crateBody(0) + brace(C.orange), 96, 'crate, intact');
sq('crate_break_0', crateBody(10) + brace(C.white, 10) + `<path d="M 10 60 L 20 60 M 8 78 L 18 78 M 12 96 L 22 96" stroke="${C.white}" stroke-width="3"/>`, 96, 'crate hit: shears, the brace flashes white');
const quarter = (pts, edge, dx, dy, rot, op = 1) => `<g transform="translate(${dx} ${dy}) rotate(${rot} 64 64)" opacity="${op}"><polygon points="${pts}" fill="${C.facet}" stroke="${C.ink}" stroke-width="3" stroke-linejoin="miter"/><path d="${edge}" stroke="${C.orange}" stroke-width="2.5"/></g>`;
sq('crate_break_1', quarter('28,36 100,36 64,72', 'M 28 36 L 100 36', 2, -12, -10) + quarter('100,36 100,112 64,72', 'M 100 36 L 64 72', 12, -2, 12) +
  quarter('28,112 100,112 64,72', 'M 64 72 L 100 112', 6, 10, 6, 0.9) + quarter('28,36 28,112 64,72', 'M 28 36 L 64 72', -12, 2, -12, 0.9) +
  `<rect x="60" y="60" width="5" height="5" fill="${C.orange}"/>`, 96, 'crate burst: four quarters fly forward');
sq('crate_break_2', `<g opacity="0.6"><polygon points="60,108 96,112 80,98" fill="${C.facet}" stroke="${C.ink}" stroke-width="2"/><path d="M 60 108 L 96 112" stroke="${C.orange}" stroke-width="2"/></g>` +
  `<g opacity="0.5"><polygon points="100,100 118,108 110,90" fill="${C.facet}" stroke="${C.ink}" stroke-width="2"/></g><rect x="44" y="104" width="4" height="4" fill="${C.orange}" opacity="0.5"/><rect x="118" y="80" width="3" height="3" fill="${C.orange}" opacity="0.4"/>`, 96, 'crate settle: slivers fade');

// ---------- bear trap (96 x 32 px = 3 x 1 studs, viewBox 384 x 128): straight blades, red teeth ----------
const plate = `<polygon points="40,100 344,100 352,120 32,120" fill="${C.ink}"/><path d="M 48 110 L 336 110" stroke="${C.red}" stroke-width="4"/>` +
  `<rect x="184" y="90" width="16" height="14" fill="${C.ink}"/><rect x="188" y="94" width="8" height="6" fill="${C.red}"/>`;
// a blade: from the hinge at (192, 100) out at angle `deg` (0 = flat along the plate, 90 = straight up), length 150
function blade(dir, deg, teeth = true) {
  const a = deg * Math.PI / 180, L = 100, W = 16;
  const tip = [192 + dir * Math.cos(a) * L, 100 - Math.sin(a) * L];
  const nx = -Math.sin(a) * dir, ny = -Math.cos(a); // outward normal (teeth side, towards the "inside" of the jaw)
  const p = (t, off) => `${(192 + dir * Math.cos(a) * L * t + nx * off).toFixed(1)},${(100 - Math.sin(a) * L * t + ny * off).toFixed(1)}`;
  let s = `<polygon points="${p(0, 0)} ${p(1, 2)} ${p(1, W)} ${p(0, W)}" fill="${C.ink}"/><polygon points="${p(0.02, 3)} ${p(0.98, 4)} ${p(0.98, W - 3)} ${p(0.02, W - 3)}" fill="${C.facet}"/>`;
  if (teeth) for (let t = 0.3; t < 0.95; t += 0.18) s += `<path d="M ${p(t - 0.05, W)} L ${p(t, W + 18)} L ${p(t + 0.05, W)}" fill="none" stroke="${C.red}" stroke-width="3" stroke-linejoin="miter"/>`;
  return s;
}
const trap = (deg, extra = '') => plate + blade(-1, deg) + blade(1, deg) + extra;
put('trap_armed', trap(10), 384, 128, 96, 32, 'bear trap armed: blades flat out');
put('trap_snap_0', trap(50, `<path d="M 60 70 L 80 56 M 324 70 L 304 56" stroke="${C.white}" stroke-width="3" stroke-linecap="round"/>`), 384, 128, 96, 32, 'snap: blades swinging up');
put('trap_snap_1', trap(76, `<path d="M 150 20 L 170 30 M 234 20 L 214 30" stroke="${C.white}" stroke-width="4" stroke-linecap="round"/>`), 384, 128, 96, 32, 'shut: blades vertical, teeth meshed');
put('trap_pried_1', trap(66), 384, 128, 96, 32, 'pried one notch');
put('trap_pried_2', trap(46), 384, 128, 96, 32, 'pried two notches');

// ---------- ice beam (384 x 64 px stretched to 24 x 2 studs, viewBox 768 x 128) and the charge / icon ----------
const beamLine = (op, wide) => `<g opacity="${op}"><path d="M 24 64 L 744 60" stroke="${C.ink}" stroke-width="${wide ? 22 : 8}" stroke-linecap="round"/>` +
  (wide ? `<path d="M 24 64 L 744 60" stroke="${C.cyan}" stroke-width="12" stroke-linecap="round"/><path d="M 24 64 L 744 60" stroke="${C.white}" stroke-width="3" stroke-linecap="round"/><circle cx="746" cy="60" r="6" fill="${C.white}"/>`
    : `<path d="M 24 64 L 744 60" stroke="${C.cyan}" stroke-width="4" stroke-linecap="round"/>`) + `</g>`;
const bump = (x, up, h, op = 1) => `<path d="M ${x - 12} ${up ? 62 : 66} L ${x} ${up ? 62 - h : 66 + h} L ${x + 12} ${up ? 62 : 66}" fill="${C.cyan}" stroke="${C.ink}" stroke-width="3" stroke-linejoin="round" opacity="${op}"/>`;
let bumps = '';
for (let x = 120; x < 720; x += 120) bumps += bump(x, true, 22) + bump(x + 60, false, 18);
const dots = (op) => [80, 260, 440, 620].map((x, i) => `<circle cx="${x}" cy="${i % 2 ? 90 : 36}" r="3" fill="${C.frost}" opacity="${op}"/>`).join('');
put('ice_beam', beamLine(1, true) + bumps + dots(1), 768, 128, 384, 64, 'the beam, out for 0.5 s');
let fadeBumps = '';
for (let x = 180; x < 720; x += 240) fadeBumps += bump(x, true, 14, 0.7);
put('ice_fade', beamLine(0.4, false) + fadeBumps + dots(0.6), 768, 128, 384, 64, 'the beam fading to a frost line');
sq('ice_charge', `<circle cx="64" cy="64" r="36" fill="none" stroke="${C.cyan}" stroke-width="4"/><path d="M 92 54 L 106 50 M 92 74 L 106 78 M 96 64 L 112 64" stroke="${C.white}" stroke-width="4" stroke-linecap="round"/>` +
  `<path d="M 56 26 L 64 12 L 72 26" fill="${C.cyan}" stroke="${C.ink}" stroke-width="2.5" stroke-linejoin="round"/><path d="M 34 104 L 20 110 L 30 96" fill="${C.cyan}" stroke="${C.ink}" stroke-width="2.5" stroke-linejoin="round"/>`, 64, 'charge: a ring on the hand');
sq('ice_icon', `<path d="M 14 70 L 110 60" stroke="${C.ink}" stroke-width="18" stroke-linecap="round"/><path d="M 14 70 L 110 60" stroke="${C.cyan}" stroke-width="10" stroke-linecap="round"/><path d="M 14 70 L 110 60" stroke="${C.white}" stroke-width="2.5" stroke-linecap="round"/>` +
  `<circle cx="112" cy="60" r="5" fill="${C.white}"/><path d="M 40 64 L 48 48 L 56 63" fill="${C.cyan}" stroke="${C.ink}" stroke-width="3" stroke-linejoin="round"/><path d="M 62 68 L 70 82 L 78 67" fill="${C.cyan}" stroke="${C.ink}" stroke-width="3" stroke-linejoin="round"/>`, 64, 'the held ice beam icon');

// ---------- write sprites and scenes ----------
const spritesDir = path.resolve(process.cwd(), 'sprites'), scenesDir = path.resolve(process.cwd(), 'scenes');
for (const [name, o] of Object.entries(out)) {
  fs.writeFileSync(path.join(spritesDir, `${name}.svg`), `<!-- generated by tools/items-rig.js; edit the geometry there, not here -->\n${o.svg}\n`);
  const scene = { name, width: o.w, height: o.h, background: 'transparent', pixelated: false,
    notes: `${o.note}. Generated by tools/items-rig.js from the canvas (docs/briefs/items-art.md); edit there.`,
    layers: [{ id: 't', name, type: 'image', src: `sprites/${name}.svg` }] };
  fs.writeFileSync(path.join(scenesDir, `${name}.json`), JSON.stringify(scene, null, 2) + '\n');
}
console.log('wrote', Object.keys(out).length, 'item sprites + scenes');
