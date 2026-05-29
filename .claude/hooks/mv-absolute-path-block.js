#!/usr/bin/env node
'use strict';

// mv-absolute-path-block.js — PreToolUse(Bash) hook, macOS + Linux.
// Permissive by default; blocks a move only if a source/destination resolves OUTSIDE
// the user's safe zones (cwd, home, temp, mounts) — i.e. into system-owned space.
// Fail-safe by design: unknown locations count as dangerous, so it never under-blocks,
// and it needs no OS-specific system-dir list.

const os = require('os');
const path = require('path');

const cwd = process.cwd();
const home = os.homedir();
const SAFE_ROOTS = [
  cwd, home, os.tmpdir(),
  '/tmp', '/private/tmp', '/var/tmp', '/private/var/tmp', // scratch
  '/Volumes', '/mnt', '/media',                           // mounted/external drives
];

const expand = a => a === '~' ? home : a.startsWith('~/') ? home + a.slice(1) : a;
const isUnder = (p, root) => p === root || p.startsWith(root + path.sep);
const dangerous = arg => {
  const p = path.resolve(cwd, expand(arg));
  return !SAFE_ROOTS.some(root => isUnder(p, root));
};

let raw = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', d => { raw += d; });
process.stdin.on('end', () => {
  let data;
  try { data = JSON.parse(raw); } catch { process.exit(0); }
  if (data.tool_name !== 'Bash') process.exit(0);

  for (const segment of String(data.tool_input?.command ?? '').split(/;|&&|\|\|/)) {
    const tokens = segment.trim().split(/\s+/);
    let i = 0;
    while (i < tokens.length && (tokens[i] === 'sudo' || /^[A-Za-z_]\w*=/.test(tokens[i]))) i++;
    if (tokens[i] !== 'mv') continue;
    const args = tokens.slice(i + 1).filter(t => !t.startsWith('-'));
    if (args.some(dangerous)) {
      console.log(JSON.stringify({ hookSpecificOutput: {
        hookEventName: 'PreToolUse',
        permissionDecision: 'deny',
        permissionDecisionReason: 'Blocked: this mv touches system-owned space (outside home/cwd/temp/mounts).',
      }}));
      process.exit(0);
    }
  }
  process.exit(0);
});
