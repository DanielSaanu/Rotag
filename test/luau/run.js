#!/usr/bin/env node
// Runs test/luau/*.test.luau against the shared Roblox modules using the standalone Luau interpreter.
// Modules are bundled the way Roblox resolves them: `require(script.Parent.X)` becomes a registry lookup.
// Needs the `luau` binary: set LUAU_BIN, put it on PATH, or drop it in tools/luau/ (gitignored).
// Get it from https://github.com/luau-lang/luau/releases (luau-ubuntu.zip / luau-windows.zip / luau-macos.zip).
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const SHARED = path.join(ROOT, 'roblox', 'src', 'shared');
const EXCLUDE = new Set(['Sprites.lua', 'SheetData.lua']); // need Roblox globals at load

function findLuau() {
  const cands = [process.env.LUAU_BIN, path.join(ROOT, 'tools', 'luau', process.platform === 'win32' ? 'luau.exe' : 'luau'), 'luau'].filter(Boolean);
  for (const c of cands) {
    const r = spawnSync(c, ['--help'], { encoding: 'utf8' });
    if (!r.error) return c;
  }
  return null;
}

export function bundle(testSource) {
  const parts = ['-- bundled by test/luau/run.js', 'local __modules = {}', 'local __cache = {}',
    'local function __require(name) if __cache[name] == nil then local m = __modules[name] if not m then error("no module " .. tostring(name)) end __cache[name] = m() end return __cache[name] end',
    'game = { GetService = function() return {} end }', 'warn = print', ''];
  for (const f of fs.readdirSync(SHARED).sort()) {
    if (!f.endsWith('.lua') || EXCLUDE.has(f)) continue;
    const name = f.replace(/\.lua$/, '');
    let src = fs.readFileSync(path.join(SHARED, f), 'utf8');
    src = src.replace(/require\(script\.Parent\.(\w+)\)/g, '__require("$1")').replace(/require\(script\.Parent:WaitForChild\("(\w+)"\)\)/g, '__require("$1")');
    src = src.replace(/^--!\w+\s*$/m, ''); // directives only count at file top
    parts.push(`__modules[${JSON.stringify(name)}] = function()`, src, 'end', '');
  }
  parts.push('-- test body', testSource);
  return parts.join('\n');
}

function main() {
  const luau = findLuau();
  if (!luau) { console.log('luau binary not found (LUAU_BIN, PATH, or tools/luau/). Skipping Luau tests.'); process.exit(0); }
  const dir = path.dirname(fileURLToPath(import.meta.url));
  const tests = fs.readdirSync(dir).filter(f => f.endsWith('.test.luau'));
  const tmp = path.join(ROOT, 'cache', 'luau');
  fs.mkdirSync(tmp, { recursive: true });
  let failed = 0;
  for (const t of tests) {
    const out = path.join(tmp, t.replace(/\.test\.luau$/, '.bundle.luau'));
    fs.writeFileSync(out, bundle(fs.readFileSync(path.join(dir, t), 'utf8')));
    const r = spawnSync(luau, [out], { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
    const stdout = (r.stdout || '').replace(/\r\n/g, '\n'); // luau on Windows prints CRLF
    // MAPFILE <name> ... ENDMAP blocks get written to exports/<name>.txt for tools/preview-world.js
    for (const m of stdout.matchAll(/^MAPFILE (\S+)\n([\s\S]*?)\nENDMAP$/gm)) {
      const file = path.join(ROOT, 'exports', m[1] + '.txt');
      fs.mkdirSync(path.dirname(file), { recursive: true });
      fs.writeFileSync(file, m[2] + '\n');
      console.log(`  wrote exports/${m[1]}.txt`);
    }
    const visible = stdout.replace(/^MAPFILE [\s\S]*?\nENDMAP$/gm, '').trim();
    const ok = r.status === 0;
    console.log(`${ok ? 'ok' : 'FAIL'} - ${t}${visible ? '\n' + visible.split('\n').map(l => '    ' + l).join('\n') : ''}`);
    if (!ok) { failed++; console.log((r.stderr || '').trim().split('\n').map(l => '    ' + l).join('\n')); }
  }
  process.exit(failed ? 1 : 0);
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main();
