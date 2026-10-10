#!/usr/bin/env node
// Emits the high-resolution runner as SVG into sprites/runner_<pose>.svg (128 x 128, feet on y = 120, facing
// right; Look.lua mirrors for left). Limbs are thick round strokes drawn twice (outline, then fill) so the figure
// reads as inked line art over the 3D stage, not pixel art.
//
// The run cycle is PROCEDURAL (Danzo, 2026-10-10: "emulate SpeedRunners, the runner doesn't give speed"): one
// function of the cycle phase places hip, feet and hands on arcs and solves knees and elbows with two-bone IK, so
// any frame count comes out consistent. The classic run poses fall out of it: contact, down, passing, up
// (push-off), with both feet off the ground around the push-off. The whole body leans forward and the head dips,
// which is what sells speed in SpeedRunners and in every fast run cycle (docs/systems/sprites-and-animation.md §3).
// Fixed poses (idle, jump rise/apex, fall, dash) are hand-placed below.
// Run: node tools/runner-rig.js   then   node bin/warehouse.js render preview_runner_strip --scale 2
import fs from 'node:fs';
import path from 'node:path';

const SIZE = 128;
const C = { ink: '#1b1b2f', body: '#5b5f73', far: '#474a5b', face: '#9aa0b8', white: '#f2f2f2', neon: '#7df9ff' };
const LIMB = 12, TORSO = 26, EDGE = 10; // fill widths and the outline added around them
const RUN_FRAMES = 8;                    // must match Config.RUN_FRAMES (test/luau/movement.test.luau pins it)

// --- body measurements (px in the 128 canvas) ---
const THIGH = 21, SHIN = 22, UPPER = 17, FORE = 17, TORSO_LEN = 30, HEAD_R = 18;
const GROUND = 113; // foot centre line; the shoe stroke reaches y = 120

const rad = (deg) => deg * Math.PI / 180;
const add = (a, b) => [a[0] + b[0], a[1] + b[1]];
const rot = ([x, y], deg) => { const c = Math.cos(rad(deg)), s = Math.sin(rad(deg)); return [x * c - y * s, x * s + y * c]; };
const round = (p) => p.map((v) => Math.round(v * 10) / 10);

// Two-bone IK: the middle joint between a (root) and b (end) with bone lengths l1, l2. bend = +1 puts the joint on
// the larger-x side (a knee pointing forward), -1 on the smaller-x side (an elbow pointing back).
function ik(a, b, l1, l2, bend) {
  let dx = b[0] - a[0], dy = b[1] - a[1];
  let d = Math.hypot(dx, dy);
  const max = l1 + l2 - 0.5;
  if (d > max) { dx *= max / d; dy *= max / d; d = max; b = [a[0] + dx, a[1] + dy]; }
  const cosA = Math.min(1, Math.max(-1, (l1 * l1 + d * d - l2 * l2) / (2 * l1 * d)));
  const ang = Math.acos(cosA);
  const base = Math.atan2(dy, dx);
  const m1 = [a[0] + l1 * Math.cos(base + ang), a[1] + l1 * Math.sin(base + ang)];
  const m2 = [a[0] + l1 * Math.cos(base - ang), a[1] + l1 * Math.sin(base - ang)];
  const pick = (m1[0] >= m2[0]) === (bend > 0) ? m1 : m2;
  return [round(pick), round(b)];
}

// One leg at phase p (0 = heel strike in front, STANCE = toe-off behind). Returns [hipAttach, knee, foot].
function leg(hip, p, side) {
  p = ((p % 1) + 1) % 1;
  const STANCE = 0.42; // share of the cycle the foot is planted; the rest it swings forward through the air
  let fx, fy;
  if (p < STANCE) {
    const u = p / STANCE;                         // 0 strike -> 1 toe-off
    fx = 28 - u * 54;                              // the planted foot slides back under the body
    fy = 0;
  } else {
    const u = (p - STANCE) / (1 - STANCE);         // 0 toe-off -> 1 strike
    const e = u * u * (3 - 2 * u);                 // ease: snaps forward, settles into the strike
    fx = -26 + e * 54;
    fy = -Math.sin(u * Math.PI) * 26 - (1 - e) * 6; // the tuck lifts the foot high behind, lower in front
  }
  const foot = [hip[0] + fx, GROUND + fy];
  const attach = [hip[0] + side * 2.5, hip[1]];
  const [knee, f] = ik(attach, foot, THIGH, SHIN, +1);
  return [attach, knee, f];
}

// One arm at phase p (0 = hand forward-high). Returns [shoulder, elbow, hand].
function arm(shoulder, p, side, lean) {
  p = ((p % 1) + 1) % 1;
  const s = Math.cos(p * Math.PI * 2);        // +1 forward, -1 back
  const hx = 20 * s + 4, hy = 14 - 6 * s;     // forward: chest height in front; back: lower and behind
  const hand = add(shoulder, rot([hx, hy], lean * 0.3));
  const attach = add(shoulder, rot([side * 2, 5], lean));
  const [elbow, h] = ik(attach, hand, UPPER, FORE, -1);
  return [attach, elbow, h];
}

// The run pose at phase t in [0, 1): one full cycle (two steps). lean = torso degrees forward of vertical.
function runPose(t) {
  const lean = 24;
  const bounce = 3 * Math.cos(t * Math.PI * 4);          // low at contact, high in flight
  const hip = [58, 74 + bounce];
  const neck = add(hip, rot([0, -TORSO_LEN], lean));
  const head = add(neck, rot([0, -(HEAD_R - 2)], lean));      // the head continues the torso line
  const nearLeg = leg(hip, t, +1), farLeg = leg(hip, t + 0.5, -1);
  const nearArm = arm(neck, t + 0.5, +1, lean), farArm = arm(neck, t, -1, lean);
  const root = add(neck, rot([-6, -4], lean));
  const wave = Math.sin(t * Math.PI * 4) * 6;
  const sx = root[0], sy = root[1];
  const scarf = `M${sx} ${sy} C ${sx - 14} ${sy - 10 + wave}, ${sx - 22} ${sy + 10 - wave}, ${sx - 36} ${sy - 2 + wave} S ${sx - 52} ${sy - 6 - wave}, ${sx - 56} ${sy + 2}`;
  return { head: round(head), neck: round(neck), hip: round(hip), lean, nearArm, farArm, nearLeg, farLeg, scarf, knot: round(add(neck, rot([6, 2], lean))) };
}

// Fixed poses: joints by hand. Limbs are shoulder -> elbow -> hand and hip -> knee -> foot. "near" is the camera side.
const FIXED = {
  idle: {
    head: [66, 28], neck: [64, 50], hip: [62, 80], lean: 0,
    nearArm: [[67, 53], [73, 70], [76, 88]], farArm: [[60, 53], [53, 70], [50, 88]],
    nearLeg: [[65, 80], [69, 98], [71, 113]], farLeg: [[59, 80], [55, 98], [53, 113]],
    scarf: 'M58 44 C 44 50, 46 66, 36 78', knot: [67, 48],
  },
  // Rising: stretched up and forward, arms thrown back and up, lead knee driven up, trailing leg long behind.
  jump_rise: {
    head: [76, 22], neck: [68, 44], hip: [58, 72], lean: 20,
    nearArm: [[70, 46], [52, 36], [40, 22]], farArm: [[66, 46], [84, 56], [98, 44]],
    nearLeg: [[61, 72], [80, 80], [74, 100]], farLeg: [[56, 72], [38, 86], [24, 104]],
    scarf: 'M60 38 C 46 44, 40 60, 28 70 S 14 84, 10 92', knot: [73, 44],
  },
  // Apex: tucked, arms level, knees up, the scarf catching up.
  jump_apex: {
    head: [72, 26], neck: [66, 48], hip: [60, 74], lean: 12,
    nearArm: [[68, 50], [50, 56], [40, 46]], farArm: [[64, 50], [82, 58], [94, 48]],
    nearLeg: [[63, 74], [82, 84], [70, 102]], farLeg: [[57, 74], [40, 86], [34, 104]],
    scarf: 'M60 42 C 48 36, 40 46, 28 42 S 12 36, 6 44', knot: [71, 48],
  },
  // Falling: upright, arms up and open, legs reaching down and apart for the landing.
  fall: {
    head: [68, 22], neck: [64, 44], hip: [60, 74], lean: 4,
    nearArm: [[66, 46], [80, 36], [88, 18]], farArm: [[62, 46], [48, 36], [40, 18]],
    nearLeg: [[63, 74], [78, 92], [82, 112]], farLeg: [[57, 74], [46, 94], [40, 112]],
    scarf: 'M58 38 C 48 26, 40 22, 30 12 S 16 2, 8 2', knot: [68, 46],
  },
  // Dash: a 42-degree lean, legs trailing straight back, arms back; Look.lua stretches it 1.5 x wide on top.
  dash: {
    head: [88, 36], neck: [74, 56], hip: [52, 74], lean: 42,
    nearArm: [[76, 58], [58, 54], [40, 40]], farArm: [[72, 58], [86, 70], [100, 60]],
    nearLeg: [[55, 74], [38, 90], [18, 100]], farLeg: [[49, 74], [34, 82], [12, 86]],
    scarf: 'M66 50 C 50 44, 44 60, 30 50 S 10 44, 2 52', knot: [80, 60],
  },
};

const pts = (p) => p.map(([x, y]) => `${x},${y}`).join(' ');
function limb(points, fill, w = LIMB) {
  return `<polyline points="${pts(points)}" stroke="${C.ink}" stroke-width="${w + EDGE}"/>` +
    `<polyline points="${pts(points)}" stroke="${fill}" stroke-width="${w}"/>`;
}
function foot([x, y], fill) {
  // A shoe: a short stroke pointing forward, ink coloured like the pixel runner's boots.
  return `<line x1="${x - 3}" y1="${y}" x2="${x + 9}" y2="${y}" stroke="${C.ink}" stroke-width="${LIMB + 2}"/>` +
    `<line x1="${x - 1}" y1="${y - 1}" x2="${x + 7}" y2="${y - 1}" stroke="${fill}" stroke-width="4"/>`;
}
function hand([x, y]) {
  return `<circle cx="${x}" cy="${y}" r="7" fill="${C.ink}"/>`;
}

function svg(p) {
  const [hx, hy] = p.head;
  const r = HEAD_R;
  const lean = p.lean || 0;
  const headT = `transform="rotate(${lean} ${hx} ${hy})"`; // the hood and visor tilt with the lean
  const parts = [
    // the scarf streams behind everything, with a soft neon glow under it
    `<path d="${p.scarf}" stroke="${C.neon}" stroke-width="18" opacity="0.28"/>`,
    `<path d="${p.scarf}" stroke="${C.ink}" stroke-width="13"/>`,
    `<path d="${p.scarf}" stroke="${C.neon}" stroke-width="7"/>`,
    // far side limbs, darker
    limb(p.farArm, C.far), hand(p.farArm[2]),
    limb(p.farLeg, C.far), foot(p.farLeg[2], C.far),
    // torso: one capsule from neck to hip, then the scarf knot on the collar under the chin
    limb([p.neck, p.hip], C.body, TORSO),
    `<circle cx="${p.knot[0]}" cy="${p.knot[1]}" r="6" fill="${C.neon}" stroke="${C.ink}" stroke-width="3"/>`,
    // near side limbs
    limb(p.nearLeg, C.body), foot(p.nearLeg[2], C.body),
    limb(p.nearArm, C.body), hand(p.nearArm[2]),
    // head: a light face in a dark hood, inked, tilted with the lean
    `<g ${headT}>`,
    `<circle cx="${hx}" cy="${hy}" r="${r}" fill="${C.face}" stroke="${C.ink}" stroke-width="5"/>`,
    `<path d="M${hx + 2} ${hy - r} A ${r} ${r} 0 0 0 ${hx + 2} ${hy + r} Z" fill="${C.body}"/>`,
    // the visor: a neon band across the eyes, glowing
    `<rect x="${hx - 5}" y="${hy - 9}" width="${r + 8}" height="16" rx="8" fill="${C.neon}" opacity="0.3"/>`,
    `<rect x="${hx - 2}" y="${hy - 6}" width="${r + 2}" height="9" rx="4.5" fill="${C.neon}" stroke="${C.ink}" stroke-width="2.5"/>`,
    `<rect x="${hx + 6}" y="${hy - 4}" width="6" height="3" rx="1.5" fill="${C.white}"/>`,
    `</g>`,
  ];
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${SIZE}" height="${SIZE}" viewBox="0 0 ${SIZE} ${SIZE}">\n` +
    `<!-- generated by tools/runner-rig.js; edit the pose there, not here -->\n` +
    `<g fill="none" stroke-linecap="round" stroke-linejoin="round">\n${parts.join('\n')}\n</g>\n</svg>\n`;
}

const POSES = { ...FIXED };
for (let i = 0; i < RUN_FRAMES; i++) POSES[`run_${i}`] = runPose(i / RUN_FRAMES);

const outDir = path.resolve(process.cwd(), 'sprites');
for (const [pose, p] of Object.entries(POSES)) {
  const file = path.join(outDir, `runner_${pose}.svg`);
  fs.writeFileSync(file, svg(p));
  console.log('wrote', path.relative(process.cwd(), file));
}
