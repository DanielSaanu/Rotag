#!/usr/bin/env node
// Syntax/type check every Lua file with luau-analyze, hiding the noise caused by the standalone analyzer not
// resolving Roblox requires and globals (Studio resolves them). Real syntax errors and local type errors still show.
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const NOISE = [/Unknown require/, /Unknown global '(Color3|Enum|game|Instance|script|task|TweenInfo|UDim2?|Vector[23]|warn|workspace|CFrame|Rect|NumberRange|ColorSequence|NumberSequence|tick|time|wait|delay|spawn|newproxy|typeof|utf8|buffer)'/, // Roblox's own globals only: any OTHER unknown global is a typo or a rename slip (Map.lua called `MapGen.walkable` for a day)
  /Unknown type '/, /depends on generic function parameters/, /unknown and number/, /operand of type unknown/, /Value of type 'unknown'/, /Type 'unknown'/, /got '\{unknown\}'/, /indexer result to be exactly/, /SameLineStatement/];
function findBin() {
  const n = process.platform === 'win32' ? 'luau-analyze.exe' : 'luau-analyze';
  for (const c of [process.env.LUAU_ANALYZE_BIN, path.join(ROOT, 'tools', 'luau', n), 'luau-analyze'].filter(Boolean)) { if (!spawnSync(c, ['--help'], { encoding: 'utf8' }).error) return c; }
  return null;
}
function walk(d) { return fs.readdirSync(d, { withFileTypes: true }).flatMap(e => e.isDirectory() ? walk(path.join(d, e.name)) : /\.luau?$/.test(e.name) ? [path.join(d, e.name)] : []); }
const bin = findBin();
if (!bin) { console.log('luau-analyze not found (LUAU_ANALYZE_BIN, PATH, or tools/luau/). Skipping.'); process.exit(0); }
let bad = 0;
for (const f of walk(path.join(ROOT, 'roblox'))) {
  const r = spawnSync(bin, ['--formatter=plain', f], { encoding: 'utf8' });
  const lines = (r.stdout + r.stderr).split('\n').filter(l => l.trim() && !NOISE.some(re => re.test(l)));
  const rel = path.relative(ROOT, f);
  if (lines.length) { bad++; console.log(`${rel}:\n  ${lines.join('\n  ')}`); } else console.log(`ok   ${rel}`);
}
process.exit(bad ? 1 : 0);
