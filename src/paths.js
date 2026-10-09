import path from 'node:path';
import { fileURLToPath } from 'node:url';

export const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
export const DIRS = {
  scenes: path.join(ROOT, 'scenes'),
  sprites: path.join(ROOT, 'sprites'),
  ideas: path.join(ROOT, 'ideas'),
  library: path.join(ROOT, 'library'),
  cache: path.join(ROOT, 'cache'),
  exports: path.join(ROOT, 'exports'),
  roblox: path.join(ROOT, 'roblox'),
  ui: path.join(ROOT, 'ui'),
  src: path.join(ROOT, 'src'),
};

/** Join and refuse to escape the base directory. */
export function safeJoin(base, rel) {
  const p = path.resolve(base, rel);
  if (p !== base && !p.startsWith(base + path.sep)) throw new Error(`path escapes root: ${rel}`);
  return p;
}

export function rel(p) { return path.relative(ROOT, p).split(path.sep).join('/'); }
