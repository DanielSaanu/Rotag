// Tiny .env loader (no dependency). Values already in process.env win.
import fs from 'node:fs';
import path from 'node:path';
import { ROOT } from './paths.js';

export function loadEnv() {
  const file = path.join(ROOT, '.env');
  if (!fs.existsSync(file)) return;
  for (const line of fs.readFileSync(file, 'utf8').split(/\r?\n/)) {
    const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*?)\s*$/i);
    if (!m || line.trim().startsWith('#')) continue;
    if (process.env[m[1]] == null) process.env[m[1]] = m[2].replace(/^["']|["']$/g, '');
  }
}
