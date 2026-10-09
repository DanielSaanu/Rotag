// Guard rails on the SHAPE of the Roblox code, so a model reading or writing it can rely on them. They run in
// `npm test` with no Luau binary, so they cannot be skipped. Inherited from The Warehouse (learnings T1, T4).
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const SRC = path.join(ROOT, 'roblox', 'src');
const walk = d => fs.readdirSync(d, { withFileTypes: true }).flatMap(e =>
  e.isDirectory() ? walk(path.join(d, e.name)) : /\.luau?$/.test(e.name) ? [path.join(d, e.name)] : []);
const rel = f => path.relative(SRC, f).split(path.sep).join('/');

// No Lua file over 400 lines. If one must go over, add it here with the step that deletes the entry; the
// number is a ceiling that may only ever SHRINK (comments count too). Check headroom BEFORE planning where code goes.
const CEILING = 400;
const GENERATED = new Set(['shared/Sprites.lua']);
const ALLOWED = {};

test('no Lua file over 400 lines (allow-list may only shrink)', () => {
  const seen = new Set();
  for (const f of walk(SRC)) {
    const name = rel(f);
    if (GENERATED.has(name)) continue;
    const lines = fs.readFileSync(f, 'utf8').split('\n').length;
    const limit = ALLOWED[name] ?? CEILING;
    if (ALLOWED[name]) seen.add(name);
    assert.ok(lines <= limit, `${name} is ${lines} lines (limit ${limit}). Split it into a new module.`);
    if (ALLOWED[name]) assert.ok(lines > CEILING, `${name} is under ${CEILING} now: delete its allow-list entry.`);
  }
  for (const name of Object.keys(ALLOWED)) assert.ok(seen.has(name), `${name} is allow-listed but does not exist.`);
});

// shared/ is pure Luau: no Instances, no services, no Roblox globals, so `npm run test:luau` can run it outside
// Studio. The generated Sprites.lua is the one exception.
test('shared/ stays pure Luau (no game:GetService, Instance.new, script.Parent beyond require)', () => {
  for (const f of walk(path.join(SRC, 'shared'))) {
    const name = rel(f);
    if (GENERATED.has(name)) continue;
    const code = fs.readFileSync(f, 'utf8').split('\n').filter(l => !l.trim().startsWith('--')).join('\n');
    for (const bad of [/game\s*:\s*GetService/, /Instance\.new/, /workspace\./, /\bTweenService\b/]) {
      assert.ok(!bad.test(code), `${name} uses ${bad} - shared/ must stay pure (CLAUDE.md, Testing the Roblox side).`);
    }
  }
});
