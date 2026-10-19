#!/usr/bin/env node
// Emits the high-resolution runner as SVG into sprites/runner_<pose>.svg (128 x 128, feet on y = 120, facing
// right; Look.lua mirrors for left). Pass 2 (2026-10-14, design canvas https://claude.ai/artifact/PpUVEG3jerX89cjUbpMxgj,
// brief docs/briefs/runner-v2.md): a smaller head under a pointed hood, a tapered torso, three limb widths, closed
// fists, shoes with a sole line, a flared wild scarf, and a SPRINT cycle (heel strike on a straight leg, heel kick,
// knee drive, flight) after Danzo's live notes. Limbs are thick round strokes drawn twice (outline, then fill) so the
// figure reads as inked line art over the 3D stage, not pixel art.
//
// The run cycle is PROCEDURAL: one function of the cycle phase places hip, feet and hands on arcs and solves knees and
// elbows with two-bone IK, so any frame count comes out consistent (docs/systems/sprites-and-animation.md §3).
// Fixed poses (idle, jump rise/apex, fall, dash) are hand-placed below.
// Run: node tools/runner-rig.js   then   node bin/warehouse.js render preview_runner_strip --scale 2
import fs from 'node:fs';
import path from 'node:path';


const SIZE = 128;
const C = { ink: '#1b1b2f', near: '#5b5f73', far: '#3f4253', face: '#9aa0b8', white: '#f2f2f2', neon: '#7df9ff', alt: '#ff8a5b' };
// proportions (px on the 128 canvas)
const P = { headR: 14, neck: 5, torso: 32, chestW: 28, waistW: 14, thigh: 23, shin: 24, upper: 15, fore: 15, hand: 5, foot: 15,
  limbNear: 11, limbFar: 9, arm: 8, edge: 3.5 };
const GROUND = 113; // foot centre line; the shoe reaches y = 120

const rad = (d) => d * Math.PI / 180;
const add = (a, b) => [a[0] + b[0], a[1] + b[1]];
const rot = ([x, y], deg) => { const c = Math.cos(rad(deg)), s = Math.sin(rad(deg)); return [x * c - y * s, x * s + y * c]; };
const r1 = (v) => Math.round(v * 10) / 10;
const pt = (p) => `${r1(p[0])},${r1(p[1])}`;

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
  // bend: +1 joint on the larger-x side, -1 smaller-x; 'down' the lower joint, 'up' the higher (for raised arms)
  let mid;
  if (bend === 'down') mid = m1[1] > m2[1] ? m1 : m2;
  else if (bend === 'up') mid = m1[1] < m2[1] ? m1 : m2;
  else mid = bend > 0 ? (m1[0] > m2[0] ? m1 : m2) : (m1[0] > m2[0] ? m2 : m1);
  return { mid, end: b };
}

// A limb: outline stroke then fill stroke, round caps.
function limb(pts, w, fill) {
  const d = pts.map(pt).join(' ');
  return `<polyline points="${d}" fill="none" stroke="${C.ink}" stroke-width="${w + 2 * P.edge}" stroke-linecap="round" stroke-linejoin="round"/>` +
         `<polyline points="${d}" fill="none" stroke="${fill}" stroke-width="${w}" stroke-linecap="round" stroke-linejoin="round"/>`;
}
// A shoe: a rounded wedge, heel at the ankle, toe pointing along `dir` degrees (0 = right), optional toe lift.
function shoe(ankle, dir, fill) {
  const toe = add(ankle, rot([P.foot, 0], dir));
  const heel = add(ankle, rot([-4, 0], dir));
  const soleA = add(heel, rot([1, 3.2], dir)), soleB = add(toe, rot([-1, 3.2], dir));
  return limb([heel, toe], 8, fill) +
         `<polyline points="${pt(soleA)} ${pt(soleB)}" fill="none" stroke="${C.white}" stroke-width="1.6" stroke-linecap="round"/>`;
}
// A hand: a closed fist (a disc with a thumb wedge) reads at 32 px where a mitt does not. `dir` = where the knuckles point.
function hand(wrist, dir, fill) {
  const c = add(wrist, rot([P.hand - 1, 0], dir));
  const thumb = add(c, rot([2, -4.5], dir));
  return `<circle cx="${r1(c[0])}" cy="${r1(c[1])}" r="${P.hand + P.edge}" fill="${C.ink}"/>` +
         `<circle cx="${r1(c[0])}" cy="${r1(c[1])}" r="${P.hand}" fill="${fill}"/>` +
         `<circle cx="${r1(thumb[0])}" cy="${r1(thumb[1])}" r="${2.6 + P.edge}" fill="${C.ink}"/>` +
         `<circle cx="${r1(thumb[0])}" cy="${r1(thumb[1])}" r="2.6" fill="${fill}"/>` +
         `<circle cx="${r1(c[0])}" cy="${r1(c[1])}" r="${P.hand}" fill="${fill}"/>`;
}
function torso(neck, hip, lean) {
  // tapered polygon: wide at the chest, narrow at the hip; drawn as outline polygon + fill polygon
  const up = rot([0, -1], 0);
  const dir = [hip[0] - neck[0], hip[1] - neck[1]];
  const len = Math.hypot(dir[0], dir[1]);
  const n = [-dir[1] / len, dir[0] / len];
  const c = [neck[0] + dir[0] * 0.18, neck[1] + dir[1] * 0.18];
  const w1 = P.chestW / 2, w2 = P.waistW / 2;
  const poly = [add(c, [n[0] * w1, n[1] * w1]), add(hip, [n[0] * w2, n[1] * w2]), add(hip, [-n[0] * w2, -n[1] * w2]), add(c, [-n[0] * w1, -n[1] * w1])];
  const d = poly.map(pt).join(' ');
  return `<polygon points="${d}" fill="${C.near}" stroke="${C.ink}" stroke-width="${2 * P.edge}" stroke-linejoin="round"/>` +
         `<polygon points="${d}" fill="${C.near}" stroke="none"/>` +
         limb([neck, add(neck, [dir[0] / len * 4, dir[1] / len * 4])], 8, C.near);
}
function head(center, tilt, accent) {
  const r = P.headR;
  const visorA = add(center, rot([r * 0.1, -r * 0.2], tilt)), visorB = add(center, rot([r * 1.0, 0], tilt));
  // the hood: a point trailing back-and-down behind the skull gives the silhouette a direction
  const hoodA = add(center, rot([-r * 0.3, -r * 0.9], tilt)), hoodT = add(center, rot([-r * 1.45, r * 0.35], tilt)), hoodB = add(center, rot([-r * 0.2, r * 0.95], tilt));
  return `<polygon points="${pt(hoodA)} ${pt(hoodT)} ${pt(hoodB)}" fill="${C.near}" stroke="${C.ink}" stroke-width="${2 * P.edge}" stroke-linejoin="round"/>` +
         `<circle cx="${r1(center[0])}" cy="${r1(center[1])}" r="${r + P.edge}" fill="${C.ink}"/>` +
         `<polygon points="${pt(hoodA)} ${pt(hoodT)} ${pt(hoodB)}" fill="${C.near}"/>` +
         `<circle cx="${r1(center[0])}" cy="${r1(center[1])}" r="${r}" fill="${C.near}"/>` +
         // the lit half of the hood faces forward
         `<path d="M ${pt(add(center, rot([0, -r], tilt)))} A ${r} ${r} 0 0 1 ${pt(add(center, rot([0, r], tilt)))} Z" fill="${C.face}"/>` +
         `<polyline points="${pt(visorA)} ${pt(visorB)}" fill="none" stroke="${C.ink}" stroke-width="7" stroke-linecap="round"/>` +
         `<polyline points="${pt(visorA)} ${pt(visorB)}" fill="none" stroke="${accent}" stroke-width="3.5" stroke-linecap="round"/>`;
}
// The scarf: a smooth ribbon (Catmull-Rom through the points, drawn as cubic Beziers), wide at the neck and tapering
// to the tail, with a thin white edge. Drawn AFTER the torso so the body never hides it.
function smoothPath(ptsIn) {
  const p = ptsIn;
  let d = `M ${pt(p[0])}`;
  for (let i = 0; i < p.length - 1; i++) {
    const p0 = p[Math.max(0, i - 1)], p1 = p[i], p2 = p[i + 1], p3 = p[Math.min(p.length - 1, i + 2)];
    const c1 = [p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6];
    const c2 = [p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6];
    d += ` C ${pt(c1)} ${pt(c2)} ${pt(p2)}`;
  }
  return d;
}
// One Catmull-Rom segment i → i+1 as a cubic, with its neighbours for continuity.
function segPath(all, i) {
  const n = all.length;
  const p0 = all[Math.max(0, i - 1)], p1 = all[i], p2 = all[i + 1], p3 = all[Math.min(n - 1, i + 2)];
  const c1 = [p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6];
  const c2 = [p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6];
  return `M ${pt(p1)} C ${pt(c1)} ${pt(c2)} ${pt(p2)}`;
}
// The scarf: a ribbon narrow at the neck FLARING to the tail (5 -> 11 px), drawn segment by segment so the flare is
// real, with a TATTERED tip: the last point splits into two forks of different lengths. Outline pass, fill pass, a
// thin white edge on top. The SHAPE of the ribbon comes from `ribbon` below (follow-through, a travelling wave).
const SCARF_W0 = 5, SCARF_W1 = 11;
function scarf(neck, pts, accent) {
  const all = [neck, ...pts];
  const n = all.length;
  const widthAt = (i) => SCARF_W0 + (SCARF_W1 - SCARF_W0) * (i / Math.max(1, n - 2));
  // the tattered tip: two forks continuing the last segment's direction, splayed apart
  const last = all[n - 1], prev = all[n - 2];
  const dl = [last[0] - prev[0], last[1] - prev[1]];
  const len = Math.hypot(dl[0], dl[1]) || 1;
  const u = [dl[0] / len, dl[1] / len];
  const forkA = add(last, rot([u[0] * 9, u[1] * 9], 30)), forkB = add(last, rot([u[0] * 7, u[1] * 7], -26));
  const forks = [[last, forkA, 6], [last, forkB, 4.5]];
  let s = '';
  for (let i = 0; i < n - 1; i++) {
    s += `<path d="${segPath(all, i)}" fill="none" stroke="${C.ink}" stroke-width="${widthAt(i) + 2 * P.edge}" stroke-linecap="round"/>`;
  }
  for (const [a, b, w] of forks) s += `<polyline points="${pt(a)} ${pt(b)}" fill="none" stroke="${C.ink}" stroke-width="${w + 2 * P.edge}" stroke-linecap="round"/>`;
  for (let i = 0; i < n - 1; i++) {
    s += `<path d="${segPath(all, i)}" fill="none" stroke="${accent}" stroke-width="${widthAt(i)}" stroke-linecap="round"/>`;
  }
  for (const [a, b, w] of forks) s += `<polyline points="${pt(a)} ${pt(b)}" fill="none" stroke="${accent}" stroke-width="${w}" stroke-linecap="round"/>`;
  s += `<path d="${smoothPath(all)}" fill="none" stroke="${C.white}" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round" opacity="0.7"/>`;
  return s;
}

// Follow-through for cloth (the drag hierarchy: each segment lags the one before it; the Spine "wave principle": an
// S curve that TRAVELS from root to tip, never a standing wave; light fabric with large drag at the distal end).
// `ribbon(angle, phase, opts)` returns scarf points relative to the neck: N segments of L px streaming along `angle`
// (180 = straight back, 90 = down, 270 = up), with (1) a travelling wave whose amplitude grows as t^2 toward the
// tail and whose crest moves one quarter wavelength per run frame, (2) the root's own bounce arriving at each segment
// LATER down the ribbon (lagBounce), (3) gravity sag, (4) a slower second wave so the tail never repeats exactly.
function ribbon(angle, phase, o = {}) {
  const N = o.N ?? 7, L = o.L ?? 9, amp = o.amp ?? 12, sag = o.sag ?? 4, lag = o.lag ?? 0.07, bounce = o.bounce ?? 0;
  const d = rot([1, 0], angle), nrm = rot([1, 0], angle + 90);
  const pts = [];
  for (let i = 1; i <= N; i++) {
    const t = i / N;
    const along = i * L * (0.985 - 0.06 * t * t); // the far end hangs a little short of taut as it waves
    const wave = amp * t * t * Math.sin(2 * Math.PI * 2 * phase - 0.95 * i) + 0.35 * amp * t * Math.sin(2 * Math.PI * phase - 0.6 * i + 1.1);
    const lagBounce = bounce * (Math.cos(4 * Math.PI * (phase - i * lag)) - Math.cos(4 * Math.PI * phase));
    const across = wave + lagBounce;
    pts.push([-3 + d[0] * along + nrm[0] * across, 0 + d[1] * along + nrm[1] * across + sag * t * t]);
  }
  return pts;
}

// ---------- the figure from a pose description ----------
// pose: { hip:[x,y], lean (deg, +forward), headTilt, feet:{near,far}, footDir:{near,far}, hands:{near,far}, handDir, scarf:[...], bendNear, bendFar }
function figure(pose, accent = C.neon, joints = null) {
  const { hip, lean } = pose;
  const neck = add(hip, rot([0, -P.torso], lean));
  const shoulder = add(neck, rot([0, 4], lean));
  const headC = add(neck, rot([0, -(P.neck + P.headR - 2)], lean + (pose.headTilt ?? 0)));
  const hipFar = add(hip, [-2, 0]), hipNear = add(hip, [1, 0]);
  const shFar = add(shoulder, [-3, 0]), shNear = add(shoulder, [2, 0]);
  const legF = ik(hipFar, pose.feet.far, P.thigh, P.shin, pose.bendFar ?? 1);
  const legN = ik(hipNear, pose.feet.near, P.thigh, P.shin, pose.bendNear ?? 1);
  const armF = ik(shFar, pose.hands.far, P.upper, P.fore, pose.armBendFar ?? -1);
  const armN = ik(shNear, pose.hands.near, P.upper, P.fore, pose.armBendNear ?? -1);
  if (joints) Object.assign(joints, {
    hip: hip.map(r1), neck: neck.map(r1), head: headC.map(r1),
    kneeFar: legF.mid.map(r1), ankleFar: legF.end.map(r1), kneeNear: legN.mid.map(r1), ankleNear: legN.end.map(r1),
    shoulderFar: shFar.map(r1), elbowFar: armF.mid.map(r1), wristFar: armF.end.map(r1),
    shoulderNear: shNear.map(r1), elbowNear: armN.mid.map(r1), wristNear: armN.end.map(r1) });
  let s = '';
  // back to front: far arm, far leg, scarf, torso, near leg, head, near arm
  s += limb([shFar, armF.mid, armF.end], P.arm - 1, C.far) + hand(armF.end, pose.handDir.far, C.far);
  s += limb([hipFar, legF.mid, legF.end], P.limbFar, C.far) + shoe(legF.end, pose.footDir.far, C.far);
  s += torso(neck, hip, lean);
  if (pose.scarf) s += scarf(add(neck, [-4, 1]), pose.scarf.map((p) => add(neck, p)), accent);
  s += limb([hipNear, legN.mid, legN.end], P.limbNear, C.near) + shoe(legN.end, pose.footDir.near, C.near);
  s += head(headC, lean * 0.8 + (pose.headTilt ?? 0), accent);
  s += limb([shNear, armN.mid, armN.end], P.arm, C.near) + hand(armN.end, pose.handDir.near, C.near);
  return s;
}

// ---------- the run cycle: one function of phase ----------
// A SPRINT, not a jog (Danzo: "really punchy and fast"). From the references (AnimSchool's key poses, Schlitter's
// side-view run, the Survival Kit's exaggerated run): heel strike far ahead on a STRAIGHT leg at contact; squash on
// down; the swing leg kicks its heel up high behind, then drives the knee forward and high at the pass; push off a
// straight back leg into real flight; big forward lean, head down a touch, 4 px of bounce; arms at 90 degrees pumping
// chin-high in front and elbow-high behind.
const STRIDE_F = 36, STRIDE_B = 30, STANCE = 0.38, LEAN = 29, HIP_Y = GROUND - (P.thigh + P.shin) + 7; // 73
const KICK = 36;   // how high the heel comes up behind (px): close to the backside
function runPose(phase) { // phase 0..1 over one step (near foot's cycle); the far foot is half a cycle away
  const bounce = 4 * Math.cos(phase * 4 * Math.PI); // one bounce per STEP (two per cycle): lowest at each contact
  const hip = [64 - 2, HIP_Y + bounce];
  // Foot path (the ankle): on the ground from contact (ph 0) to push-off (STANCE), the heel lifting over the last
  // third of stance so the toe stays down; then a low, long swing. The foot ANGLE follows the shin: toe up at heel
  // strike, flat in stance, heel up at push-off, then plantar-flexed (toe down and back) through the early swing,
  // easing back to toe-up for the next strike. That is what a trailing foot looks like; a toe-up trailing foot is wrong.
  const foot = (ph) => {
    if (ph < STANCE) {
      const t = ph / STANCE;
      const heel = Math.max(0, (t - 0.66) / 0.34); // 0 → 1 over the last third of stance
      return [hip[0] + STRIDE_F - (STRIDE_F + STRIDE_B) * t, GROUND - 7 * heel];
    }
    const t = (ph - STANCE) / (1 - STANCE);
    // the foot hangs back while the heel kicks up (x eases in late), then whips forward and reaches down for the strike
    const x = hip[0] - STRIDE_B + (STRIDE_F + STRIDE_B) * (0.5 - 0.5 * Math.cos(Math.PI * Math.pow(t, 1.35)));
    const lift = 7 + (KICK - 7) * Math.sin(Math.PI * Math.pow(t, 0.75)); // peaks early (t ~0.4): the heel kick
    return [x, GROUND - lift];
  };
  const footDir = (ph, hipAt, ankle) => {
    if (ph < 0.08) return -12;                       // heel strike: toe up
    if (ph < STANCE * 0.66) return 0;                // flat
    if (ph < STANCE) return 32 * (ph - STANCE * 0.66) / (STANCE * 0.34); // heel rises, toe planted
    const t = (ph - STANCE) / (1 - STANCE);
    const knee = ik(hipAt, ankle, P.thigh, P.shin, 1).mid;
    const shin = Math.atan2(ankle[1] - knee[1], ankle[0] - knee[0]) * 180 / Math.PI; // 90 = straight down
    const plantar = 40 * (1 - t);                    // toes pointed early in the swing, relaxed by the end
    return (shin - 90) + plantar - 12 * t;           // perpendicular to the shin, then toe-up for the strike
  };
  const near = foot(phase), far = foot((phase + 0.5) % 1);
  const hipNearW = add(hip, [1, 0]), hipFarW = add(hip, [-2, 0]);
  // Arms opposite to legs: at contact (phase 0) the near foot is forward, so the near arm is BACK (s = +1).
  // Hand targets in shoulder space: forward fist in front of the chest (22, 10), back fist behind the hip line
  // (-16, 10), and at mid-swing the hand hangs by the belly (3, 20): never closer than ~20 px to the shoulder, so the
  // elbow (always pointing back) never folds up over the shoulder.
  const s = Math.cos(phase * 2 * Math.PI);
  const neckW = add(hip, rot([0, -P.torso], LEAN));
  const shoulderW = add(neckW, rot([0, 4], LEAN));
  // forward fist chin-high in front (24, 0), back fist behind and low (-18, 10), hanging by the belly between (4, 18)
  const handAt = (sw) => add(shoulderW, [4 - 21 * sw, 18 - (sw < 0 ? 18 : 8) * Math.abs(sw)]);
  const handNear = handAt(s), handFar = handAt(-s);
  // The scarf streams straight back with follow-through: the run's bounce arrives late down the ribbon and a
  // travelling S-wave grows toward the flared, tattered tail (Danzo: "flowy", "almost wild").
  const sc = ribbon(180, phase, { amp: 16, sag: 3, bounce: 4, lag: 0.07 });
  return { hip, lean: LEAN, headTilt: 4, feet: { near, far }, footDir: { near: footDir(phase, hipNearW, near), far: footDir((phase + 0.5) % 1, hipFarW, far) },
    hands: { near: handNear, far: handFar }, handDir: { near: s > 0 ? 200 : 20, far: s > 0 ? 20 : 200 }, scarf: sc };
}

const poses = {};
for (let i = 0; i < 8; i++) poses[`run_${i}`] = runPose(i / 8);
// Fixed poses. Arms in the air follow what a jumper does: on the rise the lead fist punches up and forward past the
// head and the back arm sweeps down and back (elbows below the hands, so 'down'); at the apex the arms level out for
// balance; on the fall both fists go up beside the head with the elbows out and below them.
poses.idle = { hip: [62, 73], lean: 2, headTilt: 0, feet: { near: [69, GROUND], far: [56, GROUND] }, footDir: { near: 0, far: 0 },
  hands: { near: [70, 85], far: [54, 85] }, handDir: { near: 80, far: 100 }, scarf: ribbon(96, 0.15, { amp: 6, sag: 0, L: 8.5 }) };
poses.jump_rise = { hip: [62, 62], lean: 14, headTilt: -6, feet: { near: [80, 94], far: [44, 104] }, footDir: { near: -30, far: 50 },
  hands: { near: [92, 24], far: [42, 66] }, handDir: { near: 290, far: 110 }, armBendNear: 'down', armBendFar: 'down',
  scarf: ribbon(118, 0.3, { amp: 10, sag: 2 }) }; // follow-through: the body rose, the scarf is still down and back
poses.jump_apex = { hip: [64, 70], lean: 6, headTilt: 0, feet: { near: [76, 96], far: [56, 100] }, footDir: { near: -20, far: 30 },
  hands: { near: [88, 50], far: [44, 54] }, handDir: { near: 0, far: 180 }, armBendNear: 'down', armBendFar: 'down',
  scarf: ribbon(172, 0.55, { amp: 12, sag: 2 }) }; // floating out level at the top of the arc
poses.fall = { hip: [62, 66], lean: -4, headTilt: -4, feet: { near: [72, 110], far: [52, 108] }, footDir: { near: -10, far: -10 },
  hands: { near: [84, 26], far: [40, 30] }, handDir: { near: 280, far: 260 }, armBendNear: 'down', armBendFar: 'down',
  scarf: ribbon(218, 0.8, { amp: 11, sag: 0 }) }; // falling: the scarf streams up and back, clear of the head
// Dash: a dive. Both arms swept straight back along the body (streamlined, like a sprinter's lean into the tape),
// fists behind the hips, elbows barely bent; the old "fists punched ahead" folded the arms into a knot at this lean.
poses.dash = { hip: [56, 86], lean: 46, headTilt: 4, feet: { near: [22, 108], far: [14, 98] }, footDir: { near: -16, far: -26 },
  hands: { near: [58, 78], far: [50, 90] }, handDir: { near: 200, far: 200 }, bendNear: -1, bendFar: -1,
  armBendNear: 'up', armBendFar: 'down',
  scarf: ribbon(178, 0.4, { amp: 15, sag: 0, L: 9.5 }) }; // the dash: a hard stream back, the tail cracking like a whip
// Holds (H21, design canvas https://claude.ai/artifact/K9dE1GepPSSWB29PKirtyE, docs/briefs/items-art.md). The caught
// foot is always the FAR leg so the near leg can plant and strain without hiding the trap; the head leads the
// struggle (back in 0, forward in 1). Stumble: trip (20 deg), tumble (40 deg, head below the shoulders), recover (crouch).
poses.trapped_0 = { hip: [56, 74], lean: -12, headTilt: -10, feet: { near: [34, GROUND], far: [70, GROUND] }, footDir: { near: 0, far: 0 },
  hands: { near: [30, 24], far: [76, 22] }, handDir: { near: 250, far: 290 }, armBendNear: 'up', armBendFar: 'up',
  scarf: ribbon(44, 0.5, { amp: 10, sag: 5 }) }; // yank back: weight on the free heel, arms thrown up, scarf whips forward
poses.trapped_1 = { hip: [60, 76], lean: 30, headTilt: 10, feet: { near: [42, GROUND], far: [70, GROUND] }, footDir: { near: 0, far: 0 },
  hands: { near: [96, 100], far: [66, 94] }, handDir: { near: 90, far: 90 }, armBendNear: 'down', armBendFar: 'down',
  scarf: ribbon(150, 0.3, { amp: 10, sag: 2 }) }; // lurch: grabs at the blades
poses.stumble_0 = { hip: [58, 72], lean: 22, headTilt: 6, feet: { near: [104, 110], far: [40, GROUND] }, footDir: { near: -20, far: 0 },
  hands: { near: [110, 52], far: [40, 80] }, handDir: { near: 0, far: 90 }, armBendNear: 'down', armBendFar: 'down',
  scarf: ribbon(170, 0.3, { amp: 10, sag: 1 }) }; // trip: the far toe catches, chest over the knee, arms fly forward
// The roll (Danzo: "look at the SpeedRunners stumble and copy that for simplicity"): ONE tucked pose, knees to chest,
// hands on the shins, head down, turned 20 / 160 / 290 degrees about the body's centre so three frames read as a somersault.
const tuck = { hip: [60, 86], lean: 62, headTilt: 34, feet: { near: [80, 98], far: [72, 100] }, footDir: { near: -40, far: -30 },
  hands: { near: [86, 88], far: [78, 94] }, handDir: { near: 120, far: 120 }, armBendNear: 'down', armBendFar: 'down', bendNear: 1, bendFar: 1,
  scarf: ribbon(200, 0.6, { amp: 10, sag: 0, L: 7 }) };
poses.stumble_1 = { ...tuck, rotate: 20, pivotY: 84 };
poses.stumble_2 = { ...tuck, rotate: 160, pivotY: 84 };
poses.stumble_3 = { ...tuck, rotate: 290, pivotY: 84 };
poses.stumble_4 = { hip: [58, 84], lean: 10, headTilt: 2, feet: { near: [96, GROUND], far: [46, GROUND] }, footDir: { near: 0, far: 0 },
  hands: { near: [102, 84], far: [56, 90] }, handDir: { near: 60, far: 100 }, armBendNear: 'down', armBendFar: 'down',
  scarf: ribbon(150, 0.2, { amp: 8, sag: 2 }) }; // recover: a deep crouch, both feet down, pushing back up into the run

function svg(inner, w = SIZE, h = SIZE, extra = '') {
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${w} ${h}" width="${w}" height="${h}" shape-rendering="geometricPrecision">${extra}${inner}</svg>`;
}

const RUN_FRAMES = 8; // must match Config.RUN_FRAMES (test/luau/movement_sprites.test.luau pins it)
const order = [...Array.from({ length: RUN_FRAMES }, (_, i) => `run_${i}`), 'idle', 'jump_rise', 'jump_apex', 'fall', 'dash',
  'trapped_0', 'trapped_1', 'stumble_0', 'stumble_1', 'stumble_2', 'stumble_3', 'stumble_4'];
const outDir = path.resolve(process.cwd(), 'sprites');
for (const name of order) {
  const file = path.join(outDir, `runner_${name}.svg`);
  const pose = poses[name];
  let body = figure(pose, C.neon);
  if (pose.rotate) body = `<g transform="rotate(${pose.rotate} 64 ${pose.pivotY ?? 84})">${body}</g>`;
  fs.writeFileSync(file, `<!-- generated by tools/runner-rig.js; edit the pose there, not here -->
` +
    `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${SIZE} ${SIZE}" width="${SIZE}" height="${SIZE}" shape-rendering="geometricPrecision">${body}</svg>
`);
  console.log('wrote', path.relative(process.cwd(), file));
}
