#!/usr/bin/env node
import { run } from '../src/cli.js';
run(process.argv.slice(2)).catch(e => { console.error('error:', e.message); process.exit(1); });
