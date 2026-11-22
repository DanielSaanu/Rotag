#!/usr/bin/env node
// Runs one measurement harness (not a test) against the shared modules, bundled like the tests:
//   node test/luau/sim.js chase_sim.luau [NAME=value ...]
// Each NAME=value becomes a global SIM_NAME before the harness runs (numbers stay numbers).
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { bundle } from './run.js';

const here = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(here, '..', '..');
const [file, ...kv] = process.argv.slice(2);
if (!file) { console.log('usage: node test/luau/sim.js <harness.luau> [NAME=value ...]'); process.exit(2); }
const globals = kv.map(s => {
  const [k, v] = s.split('=');
  return `SIM_${k} = ${/^-?[\d.]+$/.test(v) ? v : JSON.stringify(v)}`;
}).join('\n');
const luau = [process.env.LUAU_BIN, path.join(ROOT, 'tools', 'luau', process.platform === 'win32' ? 'luau.exe' : 'luau'), 'luau']
  .filter(Boolean).find(c => !spawnSync(c, ['--help']).error);
if (!luau) { console.log('luau binary not found (tools/luau/)'); process.exit(2); }
const out = path.join(ROOT, 'cache', 'luau', path.basename(file).replace(/\.luau$/, '.sim.luau'));
fs.mkdirSync(path.dirname(out), { recursive: true });
fs.writeFileSync(out, bundle(globals + '\n' + fs.readFileSync(path.join(here, file), 'utf8')));
const r = spawnSync(luau, [out], { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
process.stdout.write((r.stdout || '').replace(/\r\n/g, '\n'));
process.stderr.write(r.stderr || '');
process.exit(r.status ?? 1);
