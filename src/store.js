// Scenes and ideas on disk. Scenes: scenes/<name>.json. Ideas: ideas/<name>.md (INBOX.md is the general pad).
import fs from 'node:fs/promises';
import path from 'node:path';
import { DIRS, safeJoin } from './paths.js';
import { normalizeScene } from './scene.js';

export function sceneName(s) { return String(s).replace(/\.json$/i, '').replace(/[^\w.-]+/g, '_'); }

export async function listScenes() {
  try { return (await fs.readdir(DIRS.scenes)).filter(f => f.endsWith('.json')).map(f => f.slice(0, -5)).sort(); } catch { return []; }
}

export async function loadScene(nameOrPath) {
  const p = /[\/\\]/.test(nameOrPath) || nameOrPath.endsWith('.json') ? safeJoin(DIRS.scenes, path.basename(nameOrPath)) : safeJoin(DIRS.scenes, sceneName(nameOrPath) + '.json');
  const scene = normalizeScene(JSON.parse(await fs.readFile(p, 'utf8')));
  scene.name = scene.name || path.basename(p, '.json');
  return scene;
}

export async function sceneMtime(name) {
  try { return (await fs.stat(safeJoin(DIRS.scenes, sceneName(name) + '.json'))).mtimeMs; } catch { return 0; }
}

export async function saveScene(name, scene) {
  await fs.mkdir(DIRS.scenes, { recursive: true });
  const p = safeJoin(DIRS.scenes, sceneName(name) + '.json');
  const s = normalizeScene({ ...scene, name: sceneName(name) });
  await fs.writeFile(p, JSON.stringify(s, null, 2) + '\n');
  return (await fs.stat(p)).mtimeMs;
}

export async function deleteScene(name) { await fs.rm(safeJoin(DIRS.scenes, sceneName(name) + '.json'), { force: true }); }

export async function listIdeas() {
  try { return (await fs.readdir(DIRS.ideas)).filter(f => f.endsWith('.md')).map(f => f.slice(0, -3)).sort(); } catch { return []; }
}
export async function loadIdeas(name = 'INBOX') {
  try { return await fs.readFile(safeJoin(DIRS.ideas, sceneName(name) + '.md'), 'utf8'); } catch { return ''; }
}
export async function saveIdeas(name, text) {
  await fs.mkdir(DIRS.ideas, { recursive: true });
  await fs.writeFile(safeJoin(DIRS.ideas, sceneName(name) + '.md'), text);
}
export async function ideasMtime(name = 'INBOX') {
  try { return (await fs.stat(safeJoin(DIRS.ideas, sceneName(name) + '.md'))).mtimeMs; } catch { return 0; }
}
